#!/usr/bin/env python3
"""Offline acceptance: each missing packaged helper fails safely; source app untouched."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def main():
    source = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="maro-dependencies-", dir="/private/tmp") as folder:
        root = Path(folder)
        app = root / "Maro.app"
        shutil.copytree(source, app)
        binaries = app / "Contents/MacOS"
        for helper in ("node", "yt-dlp_macos", "python/bin/python3", "maro-extractor.py"):
            resource = app / "Contents/Resources" / helper
            absent = root / Path(helper).name
            resource.rename(absent)
            process = None
            try:
                subprocess.run(["/usr/bin/codesign", "--force", "--options", "runtime", "--sign", "-", str(app)],
                               check=True, capture_output=True, timeout=10)
                state = root / (Path(helper).name + "-state")
                state.mkdir(mode=0o700)
                video = {"id": "abcdefghijk", "title": "Dependency fixture", "creator": "Test"}
                document = {"schemaVersion": 1, "favorites": [video],
                            "loadedVideo": {"video": video, "positionSeconds": 5}}
                (state / "state.json").write_text(json.dumps(document))
                env = {key: os.environ[key] for key in ("HOME", "USER", "TMPDIR") if key in os.environ}
                env.update(PATH="/usr/bin:/bin", MARO_DATA_DIRECTORY=str(state), MARO_SKETCHYBAR="/usr/bin/true")
                env["MARO_KEYCHAIN_SERVICE"] = "Maro.Test." + root.name
                process = subprocess.Popen([str(binaries / "Maro")], env=env,
                                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                socket = state / "maro.sock"
                deadline = time.monotonic() + 8
                while not socket.exists():
                    if process.poll() is not None:
                        raise AssertionError(f"App startup failed ({process.returncode}): " + process.stderr.read(2048).decode(errors="replace"))
                    assert time.monotonic() < deadline, "App startup timed out"
                    time.sleep(0.025)

                def command(*arguments, success=True):
                    try:
                        result = subprocess.run([str(binaries / "maroctl"), "--socket", str(socket), *arguments],
                                                capture_output=True, text=True, env=env, timeout=5)
                    except subprocess.TimeoutExpired:
                        sample = Path("/private/tmp") / f"maro-dependency-{process.pid}.sample"
                        subprocess.run(["/usr/bin/sample", str(process.pid), "1", "1", "-file", str(sample)],
                                       capture_output=True, timeout=15)
                        print(f"FAIL: {helper} fixture command timed out; app stack: {sample}", flush=True)
                        raise
                    response = json.loads(result.stdout)
                    assert response["ok"] == success, response
                    return response

                assert command("status")["snapshot"]["playback"] == "paused"
                failure = command("select", video["id"], success=False)
                assert "missing" in failure["error"]["message"].lower(), failure
                snapshot = command("status")["snapshot"]
                assert snapshot["loadedVideo"] == document["loadedVideo"]
                assert snapshot["favorites"] == [video] and not snapshot["sourceNeedsUpdate"]
                command("favorite", "toggle", video["id"])
                command("favorite", "toggle", video["id"])
                process.terminate()
                assert process.wait(timeout=8) == 0
                saved = json.loads((state / "state.json").read_text())
                assert saved["loadedVideo"] == document["loadedVideo"] and saved["favorites"] == [video]
                assert not saved.get("sourceDisabledBuild")
                print(f"PASS: missing {helper} reports error, preserves paused state/favorites, permits local edits, no source latch")
            finally:
                if process is not None and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                if process is not None:
                    process.stderr.close()
                absent.rename(resource)


if __name__ == "__main__":
    main()
