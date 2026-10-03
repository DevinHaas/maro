# SketchyBar integration (development)

These files are repository-owned. The managed installer deploys the plugin with
the matching Maro app/CLI; the native card requires the new `player` command.
The existing Spotify integration is independent and must remain untouched.

The item module expects `plugins/maro.py` under `PLUGIN_DIR`. It registers only
`maro.*` items and `maro_state_changed`, then pulls a fresh authoritative snapshot.
Registration centers music on notch-free displays and uses SketchyBar's `q` position
(left of the notch) on notched displays. `maroctl bar-displays` reads macOS safe areas;
display changes and wake refresh the display assignments. The card follows the visible anchor.
Click an idle item to search; click a loaded item to toggle the native player card
in the existing Maro companion app. Long titles scroll automatically in a 32-character
viewport using SketchyBar's native text animation. Previous, Play/Pause and Next share a horizontal
green strip. The card switches between Now Playing and Favorites; use the star or
right-click menu to remove a favorite. Click the bar again or press Escape to close.
Pointer exit does not dismiss controls. Registration removes only known legacy
popup children and refreshes the anchor handler, preserving unrelated items.

SketchyBar's horizontal popups give every item the full row height; attempting
to overlay metadata and transport rows causes overlapping click windows. A native
AppKit/SwiftUI card gives each action a distinct hit target without another app,
dependency, or playback controller. The card reads the same controller snapshots
and bounded thumbnail cache; progress updates stay in-process.

Development overrides must be exported before sourcing the item:

```sh
export MAROCTL=/absolute/path/to/maroctl
export MARO_APP_BUNDLE=/absolute/path/to/Maro.app
# Optional isolated service; its file name must be maro.sock for launch recovery.
export MARO_SOCKET=/private/tmp/maro-test/maro.sock
```

`MARO_PYTHON` and `SKETCHYBAR_BIN` can override the Python and SketchyBar paths.
The plugin passes rendered metadata directly as subprocess arguments, generates
click commands only from validated identities, and batches snapshot updates.

The app emits `maro_state_changed` when visible playback, favorites, or errors
change. Events coalesce for 150 ms; position-only ticks do not refresh the bar.
The app discovers Homebrew's SketchyBar executable, with an absolute
`MARO_SKETCHYBAR` override for development. Missing SketchyBar is nonfatal.

The controller publishes existing cached JPEG paths for loaded and saved videos.
The native card reads those files for the cover and favorite icons.
Missing files and rejected paths fall back to a music symbol. Normal app runs
store derived files in `~/Library/Caches/Maro/thumbnails/`; isolated development
runs keep them under their temporary data directory.

Native card routing and shared artwork state are checked by the opt-in probe
`python3 scripts/check-live-bar.py /absolute/build/directory`. It uses paused
fixture state and temporarily adds/removes Maro-only items. It refuses an existing
Maro installation and verifies the original item list after cleanup. The unused
custom event remains until the next ordinary bar reload.

Current remaining gates: visual layout,
hot reload during playback, and reversible installation. Do not call this ready
for daily use until those gates pass.

Run `python3 scripts/check-sketchybar-renderer.py` for offline anchor routing and
migration checks. `scripts/check-player-card.swift`, compiled with PlayerWindow.swift
and debug MaroCore objects, renders the actual native card for multiple states and
checks window open/close/reopen/Escape without resolving media or playing audio.
