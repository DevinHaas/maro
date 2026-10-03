#!/usr/bin/env python3
"""Bound each native process independently; preserve successful states and failures."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("fixture", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
failures = []
for size in ("1440x900", "1024x768", "1199x900", "1200x900", "1001x900", "1002x900"):
    for route in ("home", "preview", "playlist", "rows", "fallback", "favorites", "results", "empty", "error", "filter"):
        name = f"{route}-{size}"
        with (args.output / f"{name}.log").open("w") as log:
            try:
                result = subprocess.run([str(args.fixture), "--capture", str(args.output), "--viewport", size, "--route", route],
                    stdout=log, stderr=subprocess.STDOUT, timeout=20)
                if result.returncode != 0:
                    failures.append(name)
                    print(f"FAIL {name}: native exit {result.returncode}", flush=True)
                else:
                    print(f"Captured {name}", flush=True)
            except subprocess.TimeoutExpired:
                # subprocess.run terminates only the process it launched and waits for it.
                failures.append(name)
                print(f"FAIL {name}: native capture timeout; see {name}.log", flush=True)
if failures:
    parser.exit(1, f"Incomplete native run ({len(failures)} failures): {', '.join(failures)}\n")
