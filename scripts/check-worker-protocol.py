#!/usr/bin/env python3
"""Offline embedding option isolation and validation; use the bundled Python."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("worker", root / "Resources/maro-extractor.py")
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)
seen = []


class FakeExtractor:
    def __init__(self, options):
        seen.append(options)
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass
    def close(self):
        pass
    def extract_info(self, url, download, process=True):
        assert not download
        if url.startswith("ytsearch"):
            assert process is False
            return {"entries": iter({"id": f"{i:011d}", "title": f"Track {i}", "channel": "Fixture"} for i in range(75))}
        return {"url": url}
    def sanitize_info(self, info):
        return info


worker.yt_dlp.YoutubeDL = FakeExtractor
import json
def page(query, offset=0):
    return worker.extract({"operation": "search", "value": json.dumps({"query": query, "offset": offset})}, "/node")

first = page("Bach")
assert len(first["entries"]) == 25 and first["continuation"] == "25"
second = page("Bach", 25)
assert second["entries"][0]["title"] == "Track 25" and second["continuation"] == "50"
assert len(seen) == 1, "Continuation must use the same lazy generator"
worker.close_search("Bach")  # Simulate interpreter preemption/restart.
third = page("Bach", 50)
assert third["entries"][0]["title"] == "Track 50" and len(third["entries"]) == 25
assert page("Bach", 75) == {"entries": [], "continuation": None}
assert page("Bach", 100) == {"entries": [], "continuation": None}, "A shortened replay must end cleanly"
assert page("Other")["entries"][0]["title"] == "Track 0"
assert worker.extract({"operation": "resolve", "value": "c3suauAz0zQ"}, "/node")["url"].endswith("c3suauAz0zQ")
assert seen[0] is not seen[-1]
assert seen[0]["extract_flat"] == "in_playlist" and seen[-1]["extract_flat"] is False
for options in seen:
    assert options["cachedir"] is False and options["remote_components"] == set()
    assert options["js_runtimes"] == {"node": {"path": "/node"}}
    assert options["proxy"] == ""
for operation, value in [("search", "\n"), ("search", "x" * 513), ("resolve", "https://invalid"), ("other", "x")]:
    try:
        worker.extract({"operation": operation, "value": value}, "/node")
        raise AssertionError("Invalid input accepted")
    except ValueError:
        pass
assert worker.classify(Exception("private video https://signed/secret")) == "accessRestricted"
assert worker.classify(Exception("https://signed/secret")) == "failed"
for offset in [-1, 500, True, "25"]:
    try:
        page("Bach", offset)
        raise AssertionError("Invalid cursor accepted")
    except ValueError:
        pass
print("PASS: 25-item lazy pages, cursor recovery, query isolation, bounded input and redacted failures")
