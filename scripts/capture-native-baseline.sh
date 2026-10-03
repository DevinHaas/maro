#!/bin/bash
# Fresh fixture state per route/viewport avoids mutable playback/search carryover.
set -euo pipefail
cd "$(dirname "$0")/.."
capture_directory="${1:?Usage: bash scripts/capture-native-baseline.sh OUTPUT_DIRECTORY}"
shopt -s nullglob dotglob
existing_files=("$capture_directory"/*)
if [[ ${#existing_files[@]} -gt 0 ]]; then
    echo "Capture output must be empty: $capture_directory" >&2
    exit 1
fi
mkdir -p "$capture_directory"
fixture_binary="$(swift build --show-bin-path)/check-redesign-ui"
python3 scripts/capture-native-states.py "$fixture_binary" "$capture_directory"
python3 scripts/check-ui-geometry.py "$capture_directory"
