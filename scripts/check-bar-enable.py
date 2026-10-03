#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location("enable_bar", Path(__file__).with_name("enable-bar.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory(prefix="maro-enable-", dir="/private/tmp") as folder:
    root = Path(folder)
    config = root / "sketchybarrc"
    item = root / "Maro's item.sh"
    item.write_text("# module\n")
    original = b"# existing Spotify and other items\nprintf 'unchanged'"
    config.write_bytes(original)
    module.enable(config, item)
    updated = config.read_bytes()
    assert updated.startswith(original)
    backups = list(root.glob("sketchybarrc.maro-backup-*"))
    assert len(backups) == 1 and backups[0].read_bytes() == original
    module.enable(config, item)
    assert config.read_bytes() == updated and len(list(root.glob("sketchybarrc.maro-backup-*"))) == 1
    config.write_bytes(original + b"\n# BEGIN MARO\nchanged\n# END MARO\n")
    try:
        module.enable(config, item)
        raise AssertionError("Conflicting source block overwritten")
    except ValueError:
        pass
print("PASS: additive config block, exact backup, quoted path, idempotence, conflict refusal")
