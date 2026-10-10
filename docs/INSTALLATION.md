# Local acceptance installation

Maro is currently an arm64, macOS 13.5+ acceptance build with ad-hoc signing.
It is not notarized. Live reliability, visual acceptance and sustained listening
are still pending; see PROGRESS.md before daily use.

Build a standalone bundle using the commands in README.md. Choose a new,
dedicated installation folder, then run:

```sh
python3 scripts/install.py install --app /absolute/path/Maro.app \
  --prefix "$HOME/Applications/Maro Local"
```

The installer verifies the app signature and required tools, then copies the app,
CLI launcher and SketchyBar files into that folder. It prints an exact `source`
line for SketchyBar. Add that line to the existing `sketchybarrc` when ready to
enable Maro, preserving all existing item definitions. The installer does not edit
or reload your bar configuration. Python 3 and SketchyBar must be installed;
`MARO_PYTHON` and `SKETCHYBAR_BIN` override their default paths.

Standalone packages contain pinned upstream project/component notices under
`Contents/Resources`; packaging refuses missing or modified notice files. The
current checked and installed artifact is `.build/acceptance-navigation/Maro.app`.

The local acceptance installation is now at `~/Applications/Maro Local` and its
Maro source block is enabled in `~/.config/sketchybar/sketchybarrc`. The pre-change
backup is `sketchybarrc.maro-backup-06adb319910c4c82ac8f8997c7beb962` beside that file.
To remove integration later, remove only the `# BEGIN MARO` / `# END MARO` block;
do not restore the entire backup over subsequent unrelated edits.

Use the installed `bin/maroctl` launcher; it selects the app in this installation
for bounded launch recovery. Existing playback state and favorites remain in
`~/Library/Application Support/Maro`; installation does not touch that directory.

Stop Maro before replacing or removing an installation. Repeating installation
with identical inputs does nothing. An upgrade moves the verified prior install
to a hidden sibling backup folder (`.Maro Local.backup-<id>`, ignored by
Spotlight, Raycast and LaunchServices) before replacing it; the next successful
upgrade deletes the backup it supersedes, so at most one remains. Edited files or changed file
permissions cause an explicit refusal, preserving the installation for review.

```sh
python3 scripts/install.py rollback --prefix "$HOME/Applications/Maro Local"
python3 scripts/install.py uninstall --prefix "$HOME/Applications/Maro Local"
```

Rollback restores the previous verified install. Uninstall removes only the
unchanged managed installation; it preserves backups, state and bar configuration.
Remove its `source` line when uninstalling, then reload your bar normally. A backup
left by uninstall, or one that was edited, is never swept automatically.
Run only one installer operation at a time.

The runnable round-trip check uses temporary folders and two different signed
standalone bundles:

```sh
python3 scripts/check-installer.py /absolute/first/Maro.app /absolute/second/Maro.app
```

It covers repeated installation, paths with spaces/apostrophes, user edit
protection, upgrade backup, rollback, repeated removal, and unrelated files.

`python3 scripts/check-package-dependencies.py /absolute/path/Maro.app` checks
missing-helper behavior offline using temporary bundle copies. It verifies clear
errors, preserved state, working local edits, and no false source-update latch.
