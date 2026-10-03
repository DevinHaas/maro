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
    def extract_info(self, url, download):
        assert not download
        return {"url": url}
    def sanitize_info(self, info):
        return info


worker.yt_dlp.YoutubeDL = FakeExtractor
assert worker.extract({"operation": "search", "value": "Bach"}, "/node")["url"] == "ytsearch20:Bach"
assert worker.extract({"operation": "resolve", "value": "c3suauAz0zQ"}, "/node")["url"].endswith("c3suauAz0zQ")
assert seen[0] is not seen[1]
assert seen[0]["extract_flat"] == "in_playlist" and seen[1]["extract_flat"] is False
for options in seen:
    assert options["cachedir"] is False and options["remote_components"] == set()
    assert options["js_runtimes"] == {"node": {"path": "/node"}}
    assert options["proxy"] == "" and options["playlistend"] == 20
for operation, value in [("search", "\n"), ("search", "x" * 513), ("resolve", "https://invalid"), ("other", "x")]:
    try:
        worker.extract({"operation": operation, "value": value}, "/node")
        raise AssertionError("Invalid input accepted")
    except ValueError:
        pass
assert worker.classify(Exception("private video https://signed/secret")) == "accessRestricted"
assert worker.classify(Exception("https://signed/secret")) == "failed"
print("PASS: isolated options, bounded/validated input, anonymous operation, redacted failures")
