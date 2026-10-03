#!/usr/bin/env python3
"""Opt-in temporary Maro items on the real bar; preserves saved configuration.

Usage: python3 scripts/check-live-bar.py BUILD_DIRECTORY
Uses paused fixture metadata: this is not a live audio acceptance test.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def main():
    build = Path(sys.argv[1]).resolve()
    plugin = Path(__file__).resolve().parents[1] / "integrations/sketchybar/plugins/maro.py"
    bar = os.environ.get("SKETCHYBAR_BIN", "/opt/homebrew/bin/sketchybar")

    def run(args, **kwargs):
        return subprocess.run([str(arg) for arg in args], capture_output=True, text=True,
                              timeout=10, check=True, **kwargs)

    def query(item):
        return json.loads(run([bar, "--query", item]).stdout)

    original = query("bar")["items"]
    assert not any(name.startswith("maro.") for name in original), "Existing Maro items: refusing to replace them"
    with tempfile.TemporaryDirectory(prefix="maro-bar-", dir="/private/tmp") as folder:
        root = Path(folder)
        cache = root / "Artwork"
        cache.mkdir()
        video = {"id": "abcdefghijk", "title": "Maro bar check", "creator": "Paused fixture"}
        gif = root / "pixel.gif"
        gif.write_bytes(base64.b64decode("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"))
        image = cache / (video["id"] + ".jpg")
        run(["/usr/bin/sips", "-s", "format", "jpeg", "--resampleHeightWidth", "90", "160", gif, "--out", image])
        (root / "state.json").write_text(json.dumps({"schemaVersion": 1, "favorites": [],
            "loadedVideo": {"video": video, "positionSeconds": 5}}))
        environment = dict(os.environ, MARO_DATA_DIRECTORY=folder, MARO_SKETCHYBAR=bar,
                           MARO_SOCKET=str(root / "maro.sock"), MAROCTL=str(build / "maroctl"),
                           MARO_PYTHON=sys.executable, SKETCHYBAR_BIN=bar)
        # Never use launch recovery for this isolated probe or its cleanup.
        environment.pop("MARO_APP_BUNDLE", None)
        process = subprocess.Popen([str(build / "Maro")], env=environment,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        def command(*args):
            result = json.loads(run([build / "maroctl", "--socket", root / "maro.sock", *args], env=environment).stdout)
            assert result["ok"], result
            return result["snapshot"]

        def plugin_call(*args):
            run([sys.executable, plugin, *args], env=environment)

        def eventually(check):
            deadline = time.monotonic() + 6
            while time.monotonic() < deadline:
                if check():
                    return
                time.sleep(0.05)
            raise AssertionError("Bar update deadline exceeded")

        try:
            eventually(lambda: (root / "maro.sock").exists())
            eventually(lambda: command("status").get("localThumbnailPaths", {}).get(video["id"]) == str(image))
            plugin_call("register")
            assert query("maro.anchor")["label"]["value"] == video["title"]
            assert query("maro.anchor")["popup"]["drawing"] == "off"
            plugin_call("click")
            plugin_call("click")
            command("favorite", "toggle", video["id"])
            assert command("status")["localThumbnailPaths"][video["id"]] == str(image)
            run([bar, "--remove", "maro.anchor"])
            plugin_call("register")
            assert "maro.anchor" in query("bar")["items"]
            snapshot = command("status")
            assert snapshot["playback"] == "paused" and snapshot["loadedVideo"]["positionSeconds"] == 5
            assert len(snapshot["favorites"]) == 1
            print("PASS: native card routing, shared cached artwork, favorite state, anchor reload; paused state preserved")
        finally:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            owned = [name for name in query("bar")["items"] if name.startswith("maro.")]
            if owned:
                run([bar, *[arg for name in reversed(owned) for arg in ("--remove", name)]])
            assert query("bar")["items"] == original, "Unrelated bar item inventory changed"
            # SketchyBar custom events have no removal API; the empty event remains
            # registered until the user's next normal reload. No scripts subscribe.


if __name__ == "__main__":
    main()
