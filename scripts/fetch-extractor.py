#!/usr/bin/env python3
"""Build-time fetch of the exact pinned extractor; never invoked by the app."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request


def fetch(pin, destination, mode):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == pin["sha256"]:
        print(f"Verified existing {destination.name}")
        return
    temporary = None
    try:
        digest = hashlib.sha256()
        size = 0
        with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as output:
            temporary = Path(output.name)
            with urllib.request.urlopen(pin["url"], timeout=30) as response:
                while chunk := response.read(65536):
                    size += len(chunk)
                    if size > pin["sizeBytes"]:
                        raise ValueError("Download exceeds pinned size")
                    digest.update(chunk)
                    output.write(chunk)
        if size != pin["sizeBytes"] or digest.hexdigest() != pin["sha256"]:
            raise ValueError("Download checksum or size does not match pin")
        os.chmod(temporary, mode)
        os.replace(temporary, destination)
        print(f"Downloaded and SHA-256 verified {destination.name}")
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    root = Path(__file__).resolve().parent.parent
    pin = json.loads((root / "Resources/extractor.json").read_text())
    fetch(pin, root / ".build/tools/yt-dlp_macos", 0o755)
    for notice in pin["notices"]:
        fetch(notice, root / ".build/tools" / notice["file"], 0o644)


if __name__ == "__main__":
    main()
