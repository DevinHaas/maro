# Maro

A native macOS YouTube music library with a synchronized SketchyBar player.

Maro opens on Home with playlist shortcuts and local, keyword-based discovery.
The searchable library stays beside Home, global search results, Favorites, and
playlist detail. Search previews support keyboard navigation; playlist rows offer
playback, focused action sheets, and drag editing saved to YouTube. Bottom playback,
the compact player, and `maroctl` share the same controller and captured queue.

- [Implementation plan](docs/IMPLEMENTATION_PLAN.md): artifact inventory, settled
  requirements, eight milestones, acceptance gates, and unattended execution rules.
- [Progress](docs/PROGRESS.md): verified work, test command, blockers, and next step.
- [YouTube playlists](docs/YOUTUBE_PLAYLISTS.md): connect your personal account,
  create and edit private playlists, and play them in saved order.
- [Application redesign](docs/specs/redesign-implementation.md): specification,
  implementation tickets, and verification evidence.
- [Player polish and performance goals](.scratch/maro-player-polish/map.md): AFK tickets for transport layout, audio reuse, and faster YouTube search.

The player uses native segmented audio when available, fetching a short forward
buffer so long recordings can start without a whole-file download. Healthy loaded
tracks reuse their player on pause/resume and reselection. Search keeps up to eight
metadata batches for sixty seconds; repeated queries show five results immediately
and retain all twenty for Load 5 more and navigation. Home separately caches bounded
discovery candidates for thirty minutes. New lookups still depend on
YouTube, and cached playback is not an offline-download guarantee.

Search and stream resolution share one lazily initialized, bundled Python/yt-dlp
worker until Maro quits. Opening the player or search warms it without fetching
media. Requests use private pipes and fresh extraction options; repeated cache
misses reuse the interpreter. A selection can cancel an obsolete search, and
timeouts/crashes restart the helper only within a bounded recovery policy.

Build and check the current library with Swift 6/Xcode on macOS:

```sh
swift test --no-parallel
swift run maroctl --help
```

For the restricted Codex environment, use the cache configuration in the progress
file. The Codex implementation heartbeat is paused; there is no repository daemon
to run.

`maroctl` accepts `--socket /absolute/path/maro.sock` for isolated development.
It prints one JSON response line, exits nonzero on failure, and never automatically
repeats an action after a lost response. When the default service is absent, it asks
Launch Services to open Maro in the background, waits up to four seconds, and retries
the command once. `MARO_APP_BUNDLE=/absolute/Maro.app` selects a development bundle;
with an explicit socket it also isolates the launched app's data directory.

The `Maro` executable runs as an accessory app. For isolated development, set
`MARO_DATA_DIRECTORY` to an absolute private directory; optional `MARO_EXTRACTOR`
and `MARO_NODE` paths override bundled tools. The search command opens the native
library window, which also opens on launch and reopen. Run `python3 scripts/check-app-lifecycle.py
/absolute/build/directory` to verify app/CLI startup, shutdown, and paused restore
using disposable state.

For UI inspection, `python3 scripts/bundle-development-app.py /absolute/build/dir
/new/path/Maro.app` creates an ad-hoc signed development bundle. It refuses to
replace an existing artifact and does not bundle the extractor or JavaScript runtime.

For a self-contained arm64 acceptance bundle, run `python3 scripts/fetch-extractor.py`,
`python3 scripts/fetch-runtime.py`, and `python3 scripts/fetch-worker.py`, then add
`--standalone` to the bundler command. Development `MARO_EXTRACTOR` overrides must
point into a tools folder containing `python/` and `maro-extractor.py` as well.
These are build-time downloads verified against repository pins; the app never
updates executables itself. The app/CLI use Hardened Runtime with ad-hoc signing;
bundled helper executables use ordinary ad-hoc signatures. This is not a notarized
release. The bundler accepts either a debug or release Swift build directory.
The pinned arm64 runtime requires macOS 13.5 or later; standalone bundles declare
that minimum. Omit the two tool arguments to `scripts/check-live-playback.py` to
verify a bundle's own resources under a minimal PATH. This probe checks short
playback only and does not satisfy the 30-minute listening gate.
For build comparisons, reuse the printed public ID with `--video-id VIDEO_ID` on
each bundle. This skips search-result variability while resolving fresh streams
through the app. Run comparisons sequentially so only one probe plays audio.

See [local installation](docs/INSTALLATION.md) for the explicit-prefix installer,
upgrade backups, rollback and removal. Active SketchyBar configuration is preserved.
