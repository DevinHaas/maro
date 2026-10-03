#!/usr/bin/env python3
"""SketchyBar owns the anchor; the existing Maro app owns the native card."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

ROOT = "maro.anchor"
NOTCHED = ROOT + ".notched"
EVENT = "maro_state_changed"
BAR = os.environ.get("SKETCHYBAR_BIN", "/opt/homebrew/bin/sketchybar")
CLI = os.environ.get("MAROCTL", str(Path.home() / ".local/bin/maroctl"))
PYTHON = os.environ.get("MARO_PYTHON", sys.executable)
PLUGIN = str(Path(__file__).resolve())
NAMES = ["cover", "title", "creator", "state", "progress", "time", "previous", "transport", "next", "favorite", "search", "tab", "error", "empty"]
NAMES += [f"saved.{i}" for i in range(20)]


def text(value, limit=120):
    clean = "".join(char if char.isprintable() else " " for char in str(value or ""))
    return " ".join(clean.split())[:limit]


def video_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{11}", value):
        raise ValueError("Invalid video identity")
    return value


def script(*arguments):
    environment = [f"MAROCTL={CLI}", f"SKETCHYBAR_BIN={BAR}", f"MARO_PYTHON={PYTHON}"]
    for key in ("MARO_SOCKET", "MARO_APP_BUNDLE", "MARO_EXTRACTOR", "MARO_NODE"):
        if key in os.environ:
            environment.append(key + "=" + os.environ[key])
    return shlex.join(["/usr/bin/env", *environment, PYTHON, PLUGIN, *arguments])


def bar(*arguments):
    return subprocess.run([BAR, *arguments], capture_output=True, text=True, timeout=5)


def query(item):
    result = bar("--query", item)
    return json.loads(result.stdout) if result.returncode == 0 else None


def command(*arguments):
    args = [CLI]
    if os.environ.get("MARO_SOCKET"):
        args += ["--socket", os.environ["MARO_SOCKET"]]
    result = subprocess.run([*args, *arguments], capture_output=True, text=True, timeout=100)
    if len(result.stdout.encode()) > 1_048_576:
        raise ValueError("Oversized state response")
    response = json.loads(result.stdout)
    if not response.get("ok"):
        raise RuntimeError(response.get("error", {}).get("message", "Maro is unavailable."))
    return response["snapshot"]


def render(snapshot, error=None):
    loaded = snapshot.get("loadedVideo")
    video = loaded["video"] if loaded else None
    if video:
        video_id(video["id"])
    title = text(video["title"], None) if video else "Search music"
    return [argument for name in (ROOT, NOTCHED) for argument in
            ["--set", name, "label=" + (text(error, 64) if error else title), "icon=♫",
             "click_script=" + script("click"), "popup.drawing=off"]]


def display_layout(displays, safe_areas):
    known = {entry["id"] for entry in safe_areas if type(entry.get("notched")) is bool}
    notched = {entry["id"] for entry in safe_areas if entry.get("notched") is True}
    groups = {ROOT: [], NOTCHED: []}
    for display in displays:
        identity = display["arrangement-id"]
        if type(identity) is not int or not 1 <= identity <= 32 or display["DirectDisplayID"] not in known:
            raise ValueError("Invalid display arrangement")
        groups[NOTCHED if display["DirectDisplayID"] in notched else ROOT].append(str(identity))
    return [argument for name, ids in groups.items() for argument in
            ["--set", name, "display=" + (",".join(ids) if ids else "0"),
             "drawing=" + ("on" if ids else "off")]]


def update_displays():
    try:
        result = subprocess.run([CLI, "bar-displays"], capture_output=True, text=True, timeout=5, check=True)
        bar(*display_layout(query("displays") or [], json.loads(result.stdout)))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        # Keep music accessible if display detection is temporarily unavailable.
        bar("--set", ROOT, "position=left", "display=0", "drawing=on",
            "--set", NOTCHED, "drawing=off")
    else:
        bar("--set", ROOT, "position=center")


def register():
    events = query("events") or {}
    args = [] if EVENT in events else ["--add", "event", EVENT]
    existing = query(ROOT)
    if not existing:
        args += ["--add", "item", ROOT, "center"]
    else:
        # Remove only our retired popup children; preserve unrelated items.
        owned = {"maro." + name for name in NAMES}
        for name in existing.get("popup", {}).get("items", []):
            if name in owned:
                args += ["--remove", name]
    if not query(NOTCHED):
        args += ["--add", "item", NOTCHED, "q"]
    for name, position in ((ROOT, "center"), (NOTCHED, "q")):
        args += ["--set", name, "position=" + position, "updates=on", "popup.drawing=off",
                 "scroll_texts=on", "label.max_chars=32", "label.scroll_duration=100",
                 "script=" + script("refresh"), "click_script=" + script("click")]
    args += ["--subscribe", ROOT, EVENT, "system_woke", "display_change"]
    bar(*args)


def main(arguments):
    operation = arguments[0] if arguments else "refresh"
    if operation == "progress" or (operation == "refresh" and os.environ.get("SENDER") == "mouse.exited.global"):
        return  # Queued events from the old popup must not dismiss controls.
    if operation == "register":
        register()
    if operation == "register" or os.environ.get("SENDER") in ("display_change", "system_woke"):
        update_displays()
    try:
        if operation == "saved" and len(arguments) == 2:
            identity = video_id(arguments[1])
            action = ["favorite", "remove", identity] if os.environ.get("BUTTON") in ("right", "2") else ["select", identity]
            snapshot = command(*action)
        elif operation == "action":
            snapshot = command(*arguments[1:])
        elif operation in ("click", "view"):
            snapshot = command("status")
            snapshot = command("player" if snapshot.get("loadedVideo") else "search")
        else:
            snapshot = command("status")
        bar(*render(snapshot))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as failure:
        try:
            snapshot = command("status")
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            snapshot = {}
        bar(*render(snapshot, error=str(failure)))


if __name__ == "__main__":
    main(sys.argv[1:])
