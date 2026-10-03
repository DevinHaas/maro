#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
build_directory="$(swift build --show-bin-path)"
app_sources=()
for source in Sources/MaroApp/*.swift; do
    if [[ "$source" != "Sources/MaroApp/MaroApp.swift" ]]; then app_sources+=("$source"); fi
done
swiftc -parse-as-library -g -I "$build_directory/Modules" \
    "${app_sources[@]}" scripts/check-redesign-ui.swift \
    "$build_directory"/MaroCore.build/*.o -o "$build_directory/check-redesign-ui"
echo "$build_directory/check-redesign-ui"
