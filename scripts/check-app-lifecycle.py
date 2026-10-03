#!/usr/bin/env python3
"""Exercise the built native app/CLI with isolated state; no source/network calls."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def main():
    build = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="maro-app-", dir="/private/tmp") as folder:
        root = Path(folder)
        state = root / "state.json"
        video = {"id": "abcdefghijk", "title": "Lifecycle fixture", "creator": "Test"}
        state.write_text(json.dumps({"schemaVersion": 1, "favorites": [],
            "loadedVideo": {"video": video, "positionSeconds": 5}}))
        environment = dict(os.environ, MARO_DATA_DIRECTORY=folder,
            MARO_SKETCHYBAR="/usr/bin/true", MARO_KEYCHAIN_SERVICE=f"Maro.Lifecycle.{root.name}")
        has_worker = (build.parent / "Resources/python/bin/python3").is_file()
        socket = root / "maro.sock"
        processes = []

        def launch():
            process = subprocess.Popen([str(build / "Maro")], env=environment,
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            processes.append(process)
            return process

        def command(*arguments, expected=0):
            result = subprocess.run([str(build / "maroctl"), "--socket", str(socket), *arguments],
                capture_output=True, text=True, timeout=5)
            assert result.returncode == expected, (arguments, result.returncode, result.stderr)
            return json.loads(result.stdout)

        def ready(process):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                assert process.poll() is None, "App exited before readiness"
                if socket.exists():
                    return command("status")["snapshot"]
                time.sleep(0.025)
            raise AssertionError("App readiness timed out")

        def worker_pids(process):
            result = subprocess.run(["/usr/bin/pgrep", "-P", str(process.pid)], capture_output=True, text=True)
            children = []
            for value in result.stdout.split():
                name = subprocess.run(["/bin/ps", "-p", value, "-o", "comm="], capture_output=True, text=True).stdout.strip()
                if name.endswith("/python3"):
                    children.append(int(value))
            return children

        def wait_worker_exit(pid):
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    return
                time.sleep(0.025)
            raise AssertionError("Worker survived app shutdown/crash")

        try:
            first = launch()
            snapshot = ready(first)
            assert snapshot["playback"] == "paused"
            assert snapshot["loadedVideo"]["positionSeconds"] == 5
            assert command("favorite", "toggle", video["id"])["snapshot"]["favorites"] == [video]
            duplicate = launch()
            duplicate.wait(timeout=8)
            assert first.poll() is None
            assert command("status")["snapshot"]["favorites"] == [video]
            if has_worker:
                assert worker_pids(first) == [], "Worker must initialize lazily"
            assert command("search")["ok"]
            if has_worker:
                time.sleep(0.6)
                workers = worker_pids(first)
                assert len(workers) == 1
                assert command("player")["ok"] and command("search")["ok"]
                assert worker_pids(first) == workers, "Opening windows relaunched the worker"
            first.terminate()
            assert first.wait(timeout=8) == 0
            if has_worker:
                wait_worker_exit(workers[0])
            assert not socket.exists(), "Socket survived orderly shutdown"
            saved = json.loads(state.read_text())
            assert saved["favorites"] == [video]
            assert saved["loadedVideo"]["positionSeconds"] == 5
            restored = launch()
            snapshot = ready(restored)
            assert snapshot["playback"] == "paused" and snapshot["favorites"] == [video]
            restored.terminate()
            assert restored.wait(timeout=8) == 0
            assert not socket.exists()
            if has_worker:
                crashed = launch()
                ready(crashed)
                assert command("search")["ok"]
                time.sleep(0.6)
                workers = worker_pids(crashed)
                assert len(workers) == 1
                crashed.kill()
                crashed.wait(timeout=8)
                wait_worker_exit(workers[0])
            print("PASS: native app status, favorites, duplicate instance, shutdown, and paused relaunch")
            if has_worker:
                print("PASS: lazy singleton initialization, window reuse, graceful worker shutdown and crash watchdog")
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                if sys.exc_info()[0] is not None:
                    print(process.stderr.read(4096).decode(errors="replace"), file=sys.stderr)
                process.stderr.close()


if __name__ == "__main__":
    main()
