#!/usr/bin/env python3
"""Offline bar routing checks; no installed items or audible playback are touched."""
import importlib.util
import os
from pathlib import Path
import shlex

path = Path(__file__).resolve().parents[1] / "integrations/sketchybar/plugins/maro.py"
spec = importlib.util.spec_from_file_location("maro_bar", path)
bar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bar)
video = {"id": "abcdefghijk", "title": 'Title "$(touch /tmp/maro-must-not-exist)"\n--set evil'}
snapshot = {"loadedVideo": {"video": video}, "favorites": [], "playback": "paused"}
rendered = bar.render(snapshot)
assert rendered[:2] == ["--set", bar.ROOT]
assert "label=" + bar.text(video["title"], None) in rendered
assert "popup.drawing=off" in rendered
click = next(value.removeprefix("click_script=") for value in rendered if value.startswith("click_script="))
assert shlex.split(click)[-1] == "click" and "touch" not in click
assert "\n" not in bar.text(video["title"]) and "\x1b" not in bar.text("a\x1bb")
long_title = "A long music title with Unicode 🎵 " * 8
for title in ("Short title", long_title):
    labeled = bar.render({"loadedVideo": {"video": dict(video, title=title)}})
    assert labeled.count("label=" + title.strip()) == 2, "Both anchors must retain the full title"
assert "label=Search music" in bar.render({})
assert "label=Unavailable" in bar.render(snapshot, error="Unavailable")

calls, requests = [], []
bar.bar = lambda *args: calls.append(args)
bar.command = lambda *args: requests.append(args) or snapshot
sender = os.environ.get("SENDER")
try:
    os.environ["SENDER"] = "mouse.exited.global"
    bar.main(["refresh"])
    bar.main(["progress"])
    assert not calls and not requests
    bar.main(["click"])
    assert requests == [("status",), ("player",)], "A bar click must toggle presentation, not audio"
    requests.clear()
    bar.main(["click"])
    assert requests == [("status",), ("player",)], "A second click must reach the same window toggle"
    requests.clear()
    bar.command = lambda *args: requests.append(args) or {"favorites": [], "playback": "idle"}
    bar.main(["click"])
    assert requests == [("status",), ("search",)]
finally:
    if sender is None:
        os.environ.pop("SENDER", None)
    else:
        os.environ["SENDER"] = sender

calls.clear()
bar.query = lambda name: ({"popup": {"items": ["maro.title", "maro.progress", "unrelated.child"]}}
                         if name == bar.ROOT else {})
bar.register()
registration = calls[-1]
removed = [registration[i + 1] for i, value in enumerate(registration) if value == "--remove"]
assert removed == ["maro.title", "maro.progress"]
assert "script=" + bar.script("refresh") in registration
assert "click_script=" + bar.script("click") in registration
assert "position=center" in registration, "Existing items must move to the center on registration"
bar.query = lambda name: None
bar.register()
registration = calls[-1]
assert registration[registration.index("--add", 3):][:4] == ("--add", "item", bar.ROOT, "center")
assert "position=center" in registration
assert "position=q" in registration and "display_change" in registration
for name in (bar.ROOT, bar.NOTCHED):
    start = registration.index(name, registration.index("--set") + 1)
    end = next((i for i in range(start + 1, len(registration)) if registration[i].startswith("--")), len(registration))
    properties = registration[start + 1:end]
    assert "scroll_texts=on" in properties and "label.max_chars=32" in properties
    assert "label.scroll_duration=100" in properties
displays = [{"arrangement-id": 1, "DirectDisplayID": 42}, {"arrangement-id": 2, "DirectDisplayID": 99}]
layout = bar.display_layout(displays, [{"id": 42, "notched": True}, {"id": 99, "notched": False}])
assert layout == ["--set", bar.ROOT, "display=2", "drawing=on",
                  "--set", bar.NOTCHED, "display=1", "drawing=on"]
assert bar.display_layout(displays[1:], [{"id": 99, "notched": False}])[-1] == "drawing=off"
assert bar.display_layout(displays[:1], [{"id": 42, "notched": True}])[3] == "drawing=off"
try:
    bar.display_layout(displays, [])
    raise AssertionError("Unknown displays must not be assumed notch-free")
except ValueError:
    pass
print("PASS: safe metadata, native presentation toggle, idle search, stale event suppression, scoped legacy migration")
print("PASS: notch-aware placement, mixed displays, and display disconnection")
print("PASS: full long and Unicode titles, native scrolling on both anchors, short and idle titles")
