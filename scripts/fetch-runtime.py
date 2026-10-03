#!/usr/bin/env python3
"""Build-time fetch of pinned official Node; extracts only its executable/license."""
import hashlib
import json
import os
from pathlib import Path
import tarfile
import tempfile
import urllib.request


def main():
    root = Path(__file__).resolve().parents[1]
    pin = json.loads((root / "Resources/runtime.json").read_text())
    tools = root / ".build/tools"
    tools.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryFile() as archive:
        digest = hashlib.sha256()
        size = 0
        with urllib.request.urlopen(pin["url"], timeout=30) as response:
            while chunk := response.read(65536):
                size += len(chunk)
                if size > 100 * 1_048_576:
                    raise ValueError("Runtime archive exceeds size limit")
                digest.update(chunk)
                archive.write(chunk)
        if digest.hexdigest() != pin["sha256"]:
            raise ValueError("Runtime archive checksum does not match pin")
        archive.seek(0)
        prefix = pin["archive"].removesuffix(".tar.gz")
        with tarfile.open(fileobj=archive, mode="r:gz") as contents:
            for source, destination, mode in [("bin/node", "node", 0o755), ("LICENSE", "node-LICENSE", 0o644)]:
                member = contents.getmember(prefix + "/" + source)
                if not member.isfile() or member.size > 150 * 1_048_576:
                    raise ValueError("Invalid runtime archive member")
                stream = contents.extractfile(member)
                data = stream.read()
                with tempfile.NamedTemporaryFile(dir=tools, delete=False) as output:
                    temporary = Path(output.name)
                    try:
                        output.write(data)
                        output.flush()
                        os.chmod(temporary, mode)
                        os.replace(temporary, tools / destination)
                    finally:
                        temporary.unlink(missing_ok=True)
                print(f"Verified {destination}: {hashlib.sha256(data).hexdigest()}")
    print(f"Official Node {pin['version']} ({pin['architecture']}) ready for packaging")


if __name__ == "__main__":
    main()
