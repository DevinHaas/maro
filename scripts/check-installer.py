#!/usr/bin/env python3
"""Exercise install/upgrade/rollback/removal against two signed standalone bundles."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    installer = Path(__file__).with_name("install.py")
    first, second = map(Path, sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="maro-install-", dir="/private/tmp") as folder:
        root = Path(folder)
        prefix = root / "Maro's installation"
        unrelated = root / "sketchybarrc"
        unrelated.write_text("# Existing user configuration\n")

        def run(operation, app=None, success=True):
            args = [sys.executable, str(installer), operation, "--prefix", str(prefix)]
            if app:
                args += ["--app", str(app)]
            result = subprocess.run(args, capture_output=True, text=True, timeout=30)
            assert (result.returncode == 0) == success, result.stderr

        run("install", first)
        receipt = (prefix / ".maro-install.json").read_bytes()
        run("install", first)
        assert (prefix / ".maro-install.json").read_bytes() == receipt
        result = subprocess.run([str(prefix / "bin/maroctl"), "--help"], capture_output=True, timeout=5)
        assert result.returncode == 0, result.stderr
        wrapper = prefix / "bin/maroctl"
        original = wrapper.read_bytes()
        wrapper.write_bytes(original + b"# user edit\n")
        run("uninstall", success=False)
        assert wrapper.read_bytes().endswith(b"# user edit\n")
        wrapper.write_bytes(original)
        run("install", second)
        updated = json.loads((prefix / ".maro-install.json").read_text())
        superseded = Path(updated["backup"])
        assert superseded.is_dir() and superseded.name.startswith(".")
        upgraded = (prefix / ".maro-install.json").read_bytes()
        run("install", first)
        latest = Path(json.loads((prefix / ".maro-install.json").read_text())["backup"])
        assert latest.is_dir() and not superseded.exists()
        assert sorted(p.name for p in root.iterdir() if not p.name.startswith(".")) == [prefix.name, unrelated.name]
        run("rollback")
        assert (prefix / ".maro-install.json").read_bytes() == upgraded
        run("uninstall")
        run("uninstall")
        assert not prefix.exists()
        assert unrelated.read_text() == "# Existing user configuration\n"
        prefix.mkdir()
        (prefix / "keep.txt").write_text("unmanaged")
        run("install", first, success=False)
        assert (prefix / "keep.txt").read_text() == "unmanaged"
        print("PASS: install, idempotence, quoted paths, edit protection, hidden single upgrade backup, rollback, removal, unrelated preservation")


if __name__ == "__main__":
    main()
