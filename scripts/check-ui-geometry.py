#!/usr/bin/env python3
"""Validate rendered native fixture observations, or compare two capture runs."""
import argparse
import json
import struct
from pathlib import Path

SIZES = ("1440x900", "1024x768", "1199x900", "1200x900", "1001x900", "1002x900")
ROUTES = ("home", "preview", "playlist", "rows", "fallback", "favorites", "results", "empty", "error", "filter")


def observations(directory, allow_missing=False):
    result = {}
    for size in SIZES:
        for route in ROUTES:
            name = f"{route}-{size}"
            path = directory / f"{name}.geometry.json"
            if allow_missing and not path.exists():
                continue
            assert path.exists(), f"Missing native geometry: {path}"
            value = json.loads(path.read_text())
            assert value["coordinateSpace"] == "content-top-left-logical-points", name
            assert value["viewport"] == [int(x) for x in size.split("x")], name
            assert value["backingScale"] > 0, name
            assert (directory / f"{name}.png").exists(), f"Missing native capture: {name}"
            pixels = struct.unpack(">II", (directory / f"{name}.png").read_bytes()[16:24])
            assert pixels == tuple(int(dimension * value["backingScale"]) for dimension in value["viewport"]), f"Native pixel dimensions differ: {name}"
            elements = value["accessibility"]
            for label in ("Home", "Hide library", "Filter your library", "Playback volume"):
                matches = [item for item in elements if item.get("label") == label]
                assert matches, f"Missing observable control {label}: {name}"
                assert any(item["frame"][2] > 0 and item["frame"][3] > 0 for item in matches), f"Empty frame {label}: {name}"
            assert value["views"], f"Missing native view boundary: {name}"
            assert value["limitations"], f"Missing observation limitations: {name}"
            result[name] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", type=Path)
    parser.add_argument("--compare", type=Path, help="Require identical observable geometry against this baseline")
    parser.add_argument("--allow-missing", action="store_true", help="Inspect available states only; never claim complete acceptance")
    args = parser.parse_args()
    try:
        current = observations(args.captures, args.allow_missing)
        assert current, "No native observations found"
        if args.compare:
            baseline = observations(args.compare, args.allow_missing)
            assert current.keys() == baseline.keys(), "Available capture states differ"
            for name, value in current.items():
                before = baseline[name]
                assert value["backingScale"] == before["backingScale"], f"Backing scale differs: {name}"
                # Label, role, order and frame are the public native accessibility boundary.
                # Exclude paint/content values; compare every observable rectangle exactly.
                def geometry(items):
                    return [(item["role"], item.get("label"), item["frame"]) for item in items]
                assert geometry(value["accessibility"]) == geometry(before["accessibility"]), f"Accessibility geometry differs: {name}"
                def view_geometry(items):
                    return [{key: value for key, value in item.items() if key not in ("font", "text")} for item in items]
                assert view_geometry(value["views"]) == view_geometry(before["views"]), f"Native view geometry differs: {name}"
        total = len(SIZES) * len(ROUTES)
        status = "PASS" if len(current) == total else "PARTIAL"
        print(f"{status}: {len(current)}/{total} native captures with nonempty control geometry" + ("; exact observable parity for available states" if args.compare else ""))
    except (AssertionError, OSError, ValueError) as error:
        parser.exit(1, f"FAIL: {error}\n")


if __name__ == "__main__":
    main()
