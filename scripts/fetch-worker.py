#!/usr/bin/env python3
"""Build-time-only verified standalone Python and embedded yt-dlp installation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("fetch", Path(__file__).with_name("fetch-extractor.py"))
fetcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetcher)


def tree_digest(root):
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError("Worker distribution must not contain symlinks")
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode() + b"\0")
            digest.update(str(path.stat().st_mode & 0o777).encode() + b"\0")
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def main():
    pin = json.loads((ROOT / "Resources/worker.json").read_text())
    tools = ROOT / ".build/tools"
    archive = tools / "python-worker.tar.gz"
    fetcher.fetch(pin["python"], archive, 0o644)
    full_archive = tools / "python-worker-full.tar.zst"
    fetcher.fetch(pin["pythonNotices"], full_archive, 0o644)
    wheels = []
    for wheel in pin["wheels"]:
        path = tools / (wheel["name"] + ".whl")
        fetcher.fetch(wheel, path, 0o644)
        wheels.append(path)
    with tempfile.TemporaryDirectory(dir=tools) as folder:
        temporary = Path(folder)
        with tarfile.open(archive) as stream:
            # Verified archive, and reject any member/link escaping the staging root.
            for member in stream.getmembers():
                destination = temporary / member.name
                if not destination.resolve().is_relative_to(temporary.resolve()):
                    raise ValueError("Unsafe archive member")
                if member.issym() or member.islnk():
                    target = (destination.parent if member.issym() else temporary) / member.linkname
                    if not target.resolve().is_relative_to(temporary.resolve()):
                        raise ValueError("Unsafe archive link")
                elif not member.isfile() and not member.isdir():
                    raise ValueError("Unsupported archive member")
            stream.extractall(temporary)
        # Materialize links, keeping the installer's strict link/edit protection.
        destination = tools / "python-worker-new"
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(temporary / "python", destination, symlinks=False)
        subprocess.run(["/usr/bin/tar", "-xf", str(full_archive), "-C", str(temporary),
                        "python/licenses", "python/PYTHON.json"], check=True)
        shutil.copytree(temporary / "python/licenses", destination / "licenses")
        shutil.copy2(temporary / "python/PYTHON.json", destination / "PYTHON.json")
        packages = destination / "lib/python3.13/site-packages"
        for wheel in wheels:
            with zipfile.ZipFile(wheel) as stream:
                for name in stream.namelist():
                    if not (packages / name).resolve().is_relative_to(packages.resolve()):
                        raise ValueError("Unsafe wheel member")
                stream.extractall(packages)
        previous = tools / "python"
        if previous.exists():
            shutil.rmtree(previous)
        destination.rename(previous)
    receipt = {"manifestSHA256": hashlib.sha256((ROOT / "Resources/worker.json").read_bytes()).hexdigest(),
               "treeSHA256": tree_digest(tools / "python")}
    (tools / "worker-build.json").write_text(json.dumps(receipt, indent=2) + "\n")
    shutil.copy2(ROOT / "Resources/maro-extractor.py", tools / "maro-extractor.py")
    print("Verified and materialized standalone worker runtime; no runtime downloads required")


if __name__ == "__main__":
    main()
