#!/usr/bin/env python3
"""Create an ad-hoc signed UI-test bundle; not a standalone release package."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build_directory", type=Path)
    parser.add_argument("output_app", type=Path)
    parser.add_argument("--standalone", action="store_true", help="Bundle verified pinned extractor and official Node")
    args = parser.parse_args()
    build = args.build_directory.resolve()
    root = Path(__file__).resolve().parents[1]
    app = args.output_app.absolute()
    if app.suffix != ".app" or app.exists():
        parser.error("Output must be a new .app path; existing artifacts are never replaced.")
    for executable in ("Maro", "maroctl"):
        if not (build / executable).is_file():
            parser.error(f"Missing built executable: {executable}")
    if args.standalone:
        spec = importlib.util.spec_from_file_location("fetch_worker", root / "scripts/fetch-worker.py")
        worker_build = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(worker_build)
        receipt_path = root / ".build/tools/worker-build.json"
        if not receipt_path.is_file():
            parser.error("Missing worker runtime; run scripts/fetch-worker.py")
        receipt = json.loads(receipt_path.read_text())
        if receipt != {"manifestSHA256": hashlib.sha256((root / "Resources/worker.json").read_bytes()).hexdigest(),
                       "treeSHA256": worker_build.tree_digest(root / ".build/tools/python")}:
            parser.error("Modified worker runtime; rerun scripts/fetch-worker.py")
        for name, manifest, key in [("yt-dlp_macos", "extractor.json", "sha256"),
                                    ("node", "runtime.json", "executableSHA256")]:
            pin = json.loads((root / "Resources" / manifest).read_text())
            source = root / ".build/tools" / name
            if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != pin[key]:
                parser.error(f"Missing or modified pinned {name}; run the build-time fetch script.")
        notices = json.loads((root / "Resources/extractor.json").read_text())["notices"]
        runtime = json.loads((root / "Resources/runtime.json").read_text())
        notices += [{"file": "node-LICENSE", "sha256": runtime["licenseSHA256"]}]
        for notice in notices:
            source = root / ".build/tools" / notice["file"]
            if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != notice["sha256"]:
                parser.error("Missing or modified third-party notice; rerun the build-time fetch scripts.")
    macos = app / "Contents" / "MacOS"
    macos.mkdir(parents=True)
    resources = app / "Contents" / "Resources"
    resources.mkdir()
    nested = []
    if args.standalone:
        for name in ["yt-dlp_macos", "node", *[notice["file"] for notice in notices]]:
            shutil.copy2(root / ".build/tools" / name, resources / name)
        for name in ("extractor.json", "runtime.json", "THIRD_PARTY_NOTICES.md"):
            shutil.copy2(root / "Resources" / name, resources / name)
        nested = [resources / "yt-dlp_macos", resources / "node"]
        shutil.copytree(root / ".build/tools/python", resources / "python")
        for name in ("worker.json", "maro-extractor.py"):
            shutil.copy2(root / "Resources" / name, resources / name)
        # Sign every native extension/library before sealing the Python executables and app.
        native = []
        for path in (resources / "python").rglob("*"):
            if path.is_file():
                with path.open("rb") as stream:
                    if stream.read(4) in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
                        native.append(path)
        nested = sorted(native, key=lambda path: ("bin" in path.parts, str(path))) + nested
    for executable in ("Maro", "maroctl"):
        shutil.copy2(build / executable, macos / executable)
    info = {
        "CFBundleIdentifier": "local.maro.player.development",
        "CFBundleName": "Maro",
        "CFBundleDisplayName": "Maro",
        "CFBundleExecutable": "Maro",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "dev-3" if args.standalone else "dev-1",
        "LSMinimumSystemVersion": json.loads((root / "Resources/runtime.json").read_text())["minimumMacOSVersion"]
            if args.standalone else "13.0",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
    }
    with (app / "Contents" / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream)
    for target in nested:
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(target)], check=True)
    for target in (macos / "maroctl", macos / "Maro", app):
        subprocess.run(["/usr/bin/codesign", "--force", "--options", "runtime", "--sign", "-", str(target)], check=True)
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print(f"Development bundle: {app}")
    print("Pinned extractor/runtime bundled; ad-hoc acceptance build, not notarized." if args.standalone else
          "Extractor/runtime are not bundled; use MARO_EXTRACTOR and MARO_NODE for development.")


if __name__ == "__main__":
    main()
