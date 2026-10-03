#!/usr/bin/env python3
"""Opt-in short live playback probe. Uses disposable state; not listening acceptance."""
import argparse
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("extractor", type=Path, nargs="?")
    parser.add_argument("node", type=Path, nargs="?")
    parser.add_argument("--video-id", help="Resolve this public video in both builds for a controlled comparison")
    args = parser.parse_args()
    if args.video_id and not re.fullmatch(r"[A-Za-z0-9_-]{11}", args.video_id):
        parser.error("Invalid video ID")
    if (args.extractor is None) != (args.node is None):
        parser.error("Provide both development tools, or neither to test bundled resources.")
    binaries = args.app.resolve() / "Contents" / "MacOS"
    extractor = args.extractor or args.app / "Contents/Resources/yt-dlp_macos"
    node = args.node or args.app / "Contents/Resources/node"
    with tempfile.TemporaryDirectory(prefix="maro-live-", dir="/private/tmp") as folder:
        root = Path(folder)
        env = {key: os.environ[key] for key in ("HOME", "USER", "TMPDIR") if key in os.environ}
        env.update(PATH="/usr/bin:/bin", MARO_DATA_DIRECTORY=folder, MARO_SKETCHYBAR="/usr/bin/true")
        if args.extractor:
            env.update(MARO_EXTRACTOR=str(extractor.resolve()), MARO_NODE=str(node.resolve()))
        if args.video_id:
            video = {"id": args.video_id, "title": "Fixed video playback probe", "creator": ""}
        else:
            with (root / "search.json").open("wb") as output:
                result = subprocess.run([str(extractor.resolve()), "--ignore-config", "--no-plugin-dirs",
                    "--no-remote-components", "--no-cache-dir", "--no-progress", "--skip-download",
                    "--dump-single-json", "--socket-timeout", "15", "--retries", "0", "--extractor-retries", "0",
                    "--no-js-runtimes", "--js-runtimes", "node:" + str(node.resolve()),
                    "--flat-playlist", "--playlist-end", "1", "--", "ytsearch1:Bach cello suite no 1"],
                    stdout=output, stderr=subprocess.DEVNULL, timeout=45, env=env)
            assert result.returncode == 0, "Live search failed; raw extractor diagnostics suppressed"
            assert (root / "search.json").stat().st_size <= 8 * 1024 * 1024
            entry = json.loads((root / "search.json").read_text())["entries"][0]
            video = {"id": entry["id"], "title": entry["title"], "creator": entry.get("channel") or entry.get("uploader") or ""}
        print("Testing public video:", video["id"], flush=True)
        (root / "state.json").write_text(json.dumps({"schemaVersion": 1, "favorites": [video]}))
        app = subprocess.Popen([str(binaries / "Maro")], env=env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        socket = root / "maro.sock"

        def command(*arguments):
            result = subprocess.run([str(binaries / "maroctl"), "--socket", str(socket), *arguments],
                capture_output=True, text=True, timeout=95, env=env)
            assert result.stdout, "App command failed without a response"
            return json.loads(result.stdout)

        try:
            deadline = time.monotonic() + 8
            while not socket.exists():
                assert app.poll() is None and time.monotonic() < deadline, "App failed to start"
                time.sleep(0.025)
            started = time.monotonic()
            selected = command("select", video["id"])
            print("Selection result:", json.dumps({"videoID": video["id"], "ok": selected["ok"], "error": selected.get("error"),
                "seconds": round(time.monotonic() - started, 2)}), flush=True)
            assert selected["ok"], "Live selection did not prepare"
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                snapshot = command("status")["snapshot"]
                if snapshot["playback"] == "playing" and snapshot["loadedVideo"]["positionSeconds"] >= 2:
                    print("PASS: native app reports playing with position advancing beyond 2 seconds; not 30-minute acceptance")
                    command("toggle")
                    return
                time.sleep(0.25)
            raise AssertionError("No advancing live playback observed")
        finally:
            app.terminate()
            try:
                app.wait(timeout=8)
            except subprocess.TimeoutExpired:
                app.kill()
                app.wait()


if __name__ == "__main__":
    main()
