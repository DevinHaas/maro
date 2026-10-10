#!/usr/bin/env python3
"""Install Maro into an explicit dedicated prefix; never edits SketchyBar config."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

RECEIPT = ".maro-install.json"


def inventory(root):
    result = {}
    for path in sorted(root.rglob("*")):
        if path == root / RECEIPT:
            continue
        if path.is_symlink():
            raise ValueError("Symlinks are not supported inside the managed installation")
        key = str(path.relative_to(root))
        if path.is_dir():
            result[key] = "directory"
        elif path.is_file():
            result[key] = str(path.stat().st_mode & 0o777) + ":" + hashlib.sha256(path.read_bytes()).hexdigest()
        else:
            raise ValueError("Unexpected file type in installation")
    return result


def checked_receipt(prefix):
    receipt = prefix / RECEIPT
    if prefix.is_symlink() or receipt.is_symlink():
        raise ValueError("Refusing a symlinked installation or receipt")
    if not receipt.is_file():
        raise ValueError("Destination is not a managed installation; preserving every file")
    saved = json.loads(receipt.read_text())
    if saved.get("version") != 1 or saved.get("prefix") != str(prefix) or saved.get("files") != inventory(prefix):
        raise ValueError("Installation changed or is not managed; preserving every file")
    return saved


def checked_backup(prefix, backup):
    backup = Path(backup)
    # Hidden sibling: same volume for atomic rename, and LaunchServices/Spotlight skip
    # dot-prefixed paths, so the backup Maro.app never shows up as a duplicate app.
    if backup.parent != prefix.parent or not backup.name.startswith("." + prefix.name + ".backup-"):
        raise ValueError("Invalid backup location")
    # Backup receipt still identifies its original destination.
    previous = json.loads((backup / RECEIPT).read_text())
    if backup.is_symlink() or (backup / RECEIPT).is_symlink() or previous.get("prefix") != str(prefix) or previous.get("files") != inventory(backup):
        raise ValueError("Backup changed; preserving it")
    return backup


def install(app, prefix):
    app = app.resolve()
    root = Path(__file__).resolve().parents[1]
    if app == prefix or prefix in app.parents or app in prefix.parents:
        raise ValueError("Source app and installation must be separate")
    for name in ("Contents/MacOS/Maro", "Contents/MacOS/maroctl", "Contents/Resources/node", "Contents/Resources/yt-dlp_macos"):
        if not (app / name).is_file() or not os.access(app / name, os.X_OK):
            raise ValueError(f"Incomplete standalone app: {name}")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleExecutable") != "Maro":
        raise ValueError("Not a Maro bundle")
    if info.get("CFBundleVersion") == "dev-3":
        for name in ("python/bin/python3", "maro-extractor.py", "worker.json"):
            if not (app / "Contents/Resources" / name).is_file():
                raise ValueError(f"Incomplete worker package: {name}")
        if not os.access(app / "Contents/Resources/python/bin/python3", os.X_OK):
            raise ValueError("Worker runtime is not executable")
    inventory(app)  # Reject links before copying an untrusted bundle tree.
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    old = checked_receipt(prefix) if prefix.exists() else None
    prefix.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".maro-stage-", dir=prefix.parent))
    backup = None
    try:
        shutil.copytree(app, stage / "Maro.app")
        (stage / "bin").mkdir()
        (stage / "sketchybar").mkdir()
        shutil.copy2(root / "integrations/sketchybar/plugins/maro.py", stage / "sketchybar/maro.py")
        wrapper = "#!/bin/sh\nexport MARO_APP_BUNDLE=" + shlex.quote(str(prefix / "Maro.app")) + "\n"
        wrapper += "exec " + shlex.quote(str(prefix / "Maro.app/Contents/MacOS/maroctl")) + ' "$@"\n'
        (stage / "bin/maroctl").write_text(wrapper)
        (stage / "bin/maroctl").chmod(0o755)
        item = "#!/bin/sh\nexport MAROCTL=" + shlex.quote(str(prefix / "bin/maroctl")) + "\n"
        item += '"${MARO_PYTHON:-/usr/bin/python3}" ' + shlex.quote(str(prefix / "sketchybar/maro.py")) + " register\n"
        (stage / "sketchybar/maro.sh").write_text(item)
        files = inventory(stage)
        if old and old["files"] == files:
            print("Already installed; unchanged")
            return
        if old:
            backup = prefix.with_name("." + prefix.name + ".backup-" + uuid.uuid4().hex)
        saved = {"version": 1, "prefix": str(prefix), "files": files,
                 "backup": str(backup) if backup else None}
        (stage / RECEIPT).write_text(json.dumps(saved, indent=2) + "\n")
        if backup:
            prefix.rename(backup)
        try:
            stage.rename(prefix)
        except BaseException:
            if backup:
                backup.rename(prefix)
            raise
        # Only the newest backup is referenced by a receipt; drop the one it supersedes.
        if old and old.get("backup"):
            try:
                shutil.rmtree(checked_backup(prefix, old["backup"]))
            except (OSError, ValueError):
                pass  # Missing, legacy-named or changed backups are left untouched.
        print("Installed: " + str(prefix))
        print("SketchyBar source line: source " + shlex.quote(str(prefix / "sketchybar/maro.sh")))
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def remove(prefix, rollback=False):
    if not prefix.exists():
        print("Already absent")
        return
    saved = checked_receipt(prefix)
    backup = saved.get("backup")
    if rollback:
        if not backup:
            raise ValueError("No previous installation to restore")
        backup = checked_backup(prefix, backup)
    retired = prefix.with_name(".maro-removed-" + uuid.uuid4().hex)
    prefix.rename(retired)
    try:
        if rollback:
            backup.rename(prefix)
    except BaseException:
        retired.rename(prefix)
        raise
    shutil.rmtree(retired)
    print("Previous installation restored" if rollback else "Installation removed; state, backups and bar configuration preserved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("install", "uninstall", "rollback"))
    parser.add_argument("--prefix", type=Path, required=True)
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    prefix = args.prefix.absolute()
    if not args.prefix.is_absolute() or prefix == Path("/") or prefix.is_symlink() or prefix.resolve() != prefix:
        parser.error("Use an absolute dedicated prefix without symlinked path components")
    if args.operation == "install":
        if not args.app:
            parser.error("--app is required for installation")
        install(args.app, prefix)
    else:
        remove(prefix, rollback=args.operation == "rollback")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print("Installation failed: " + str(error), file=sys.stderr)
        sys.exit(1)
