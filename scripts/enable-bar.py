#!/usr/bin/env python3
"""Append one backed-up Maro source block; never replaces existing bar definitions."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import uuid


def enable(config, module):
    if not config.is_absolute() or not module.is_absolute() or config.is_symlink() or not module.is_file():
        raise ValueError("Use an absolute regular config path and existing installed module")
    original = config.read_bytes()
    block = ("\n# BEGIN MARO\nsource " + shlex.quote(str(module)) + "\n# END MARO\n").encode()
    if block in original:
        print("Maro source block already present")
        return
    if b"# BEGIN MARO" in original or b"# END MARO" in original:
        raise ValueError("Different Maro block exists; preserving configuration for review")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=config.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(original + block)
        shutil.copystat(config, temporary)
        subprocess.run(["/bin/bash", "-n", str(temporary)], check=True, capture_output=True)
        if config.read_bytes() != original:
            raise ValueError("Configuration changed during preparation; retry after edits finish")
        backup = config.with_name(config.name + ".maro-backup-" + uuid.uuid4().hex)
        shutil.copy2(config, backup)
        os.replace(temporary, config)
        print("Enabled Maro source block. Backup: " + str(backup))
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--module", type=Path, required=True)
    args = parser.parse_args()
    enable(args.config, args.module)
