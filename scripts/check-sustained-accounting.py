#!/usr/bin/env python3
"""Offline checks only: never a substitute for a sustained real playback run."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

spec = importlib.util.spec_from_file_location("sustained", Path(__file__).with_name("check-sustained-playback.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.progress(10, 15, 5) == 5
assert module.progress(100, 0, 5) == 0  # Replay reset.
assert module.progress(10, 100, 5) == 0  # Seek jump.
assert module.progress(10, 10, 5) == 0  # Stall.
assert module.progress(10, 9, 5) == 0
print("PASS: media progress accounting excludes stalls, backward movement and seek/replay jumps")

# This fake CLI never touches Maro, audio, sockets, or the user's library.
with tempfile.TemporaryDirectory(prefix="maro-monitor-") as folder:
    root = Path(folder)
    fake = root / "ctl"
    state = root / "state.json"
    state.write_text(json.dumps({"playback": "paused", "loadedVideo": {
        "video": {"id": "abcdefghijk"}, "positionSeconds": 10}}))
    fake.write_text("#!" + sys.executable + "\n" + '''import json, sys
from pathlib import Path
file = Path(__file__).with_name("state.json")
state = json.loads(file.read_text())
if sys.argv[1] == "toggle":
    state["playback"] = "playing" if state["playback"] == "paused" else "paused"
    file.write_text(json.dumps(state))
print(json.dumps({"ok": True, "snapshot": state}))
''')
    fake.chmod(0o755)
    log = root / "evidence.jsonl"
    process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("check-sustained-playback.py")),
                                "--ctl", str(fake), "--log", str(log)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.monotonic() + 5
        while not log.exists() or '"sample"' not in log.read_text():
            assert process.poll() is None and time.monotonic() < deadline
            time.sleep(0.02)
        process.terminate()
        assert process.wait(timeout=5) != 0
        assert json.loads(state.read_text())["playback"] == "paused"
        evidence = [json.loads(line) for line in log.read_text().splitlines()]
        assert any(row.get("reason") == "interrupted" for row in evidence)
        assert evidence[-1]["kind"] == "paused_after_check"
        assert not any(row["kind"] == "pass" for row in evidence)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
print("PASS: terminated monitor pauses its own simulated playback and records interruption, not success")
