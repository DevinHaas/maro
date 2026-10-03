# Persistent yt-dlp worker — implementation and measured acceptance

Verified and installed on 2026-10-01. No audible playback or sustained-listening gate was performed.

## Result

Maro now lazily starts one bundled Python/yt-dlp interpreter on first player/search
interaction or source request. Searches and stream resolutions reuse its imports
and process until app shutdown. Each request gets a fresh `YoutubeDL` instance and
options; retaining an interpreter does not share mutable request configuration.
The official YouTube API is not involved.

`YouTubeClient` copies share their worker actor. The controller owns the client
lifetime and shuts it down. The app warms the worker without fetching media when
opening the player or search. Only one queued request runs at a time. This is a
single private helper, not a web service or a pool.

## Measurements

Three paired sessions on the same machine, with public query `Bach cello suite no 1`
and video `c3suauAz0zQ`. Direct worker requests bypass the controller metadata cache.
Each session initializes a new worker, performs search/resolution twice, then runs
the old per-process CLI search/resolution. All requests succeeded. PID probes before
and after prove no healthy runtime relaunch. Every search returned 20 results.

Seconds (first request columns exclude the separately measured initialization;
the first resolution occurs after the first search, not on an untouched interpreter):

| Run | Initialization | First search | Warm search | First resolution | Warm resolution | Old search | Old resolution |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.341 | 1.211 | 1.010 | 1.432 | 3.483 | 7.732 | 8.407 |
| 2 | 0.350 | 1.076 | 0.931 | 1.698 | 1.212 | 7.409 | 8.892 |
| 3 | 0.349 | 1.151 | 1.357 | 1.581 | 1.476 | 8.852 | 8.012 |

- Median warm uncached search: **1.010s vs 7.732s**, about **87% faster**.
- Median warm resolution: **1.476s vs 8.407s**, about **82% faster**.
- Median initialization: **0.349s**, paid once per healthy app session.
- Six muted native HLS preparations: **0.242–0.515s** (separate from resolution).
- An earlier independent probe also exercised a distinct second query,
  `ambience nordic vikings`, on the same worker: 0.892s after the initial query and
  resolution. Offline tests exercise distinct uncached operations and correlation.

Network variance remains visible (one warm resolution took 3.483s); these are
measured samples, not latency guarantees. The improvement combines persistent
runtime reuse with replacing the slow per-invocation macOS PyInstaller startup.
It does not imply all 6.5 seconds were proven to be decompression alone.

Reproduce using `scripts/measure-worker.swift`, compiled against the debug MaroCore
objects with `@testable import` (same pattern as the existing timing scripts), then
pass the absolute `.build/tools` directory. It prints durations/counts/reuse only,
never signed media URLs, and never commits or plays the prepared native players.

## Progressive long-video verification

The signed standalone package resolved the exact supplied two-hour video with HLS
preferred. Both audio HLS candidates passed the existing muted `--verify-hls` probe:

| Candidate | Readiness | Initial buffer end | Bytes after initial muted play | Seek to 21 min | Position after seek/play | Total bytes |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| 0 | 0.681s | 34.389s | 561,398 | true | 1262.865s | 1,442,523 |
| 1 | 0.187s | 34.412s | 212,798 | true | 1262.855s | 545,688 |

Duration was 7308.207s; post-seek buffers ended near 1295.9s. This remains segmented
progressive playback, without fetching the whole video at startup. The player's
existing short buffer, HLS preference, progressive fallback, loaded-item reuse,
favorites and 8-batch/60-second metadata cache remain in place.

## Request and recovery bounds

- Private pipes, UUID correlation, one active request, at most eight live jobs.
  Duplicate operation/value requests share work; canceling one waiter leaves the
  other waiters intact. An explicit resolution preempts active search work.
- Input frame at most 4096 bytes, response at most 8 MiB, 15-second initialization
  deadline within the 45-second request budget, 15-second extractor socket limit,
  no extractor retries. Queue size and per-request deadlines bound backlog.
- Canceling an active request kills/reaps that worker process group; queued
  cancellations are removed. The next request starts a fresh helper. Ordinary
  extraction errors keep the healthy helper alive. Three transport/crash failures
  within a minute stop further starts until the rolling recovery window permits it.
- Stale/mismatched replies, output floods, hangs and crashes fail callers safely.
  Existing controller generations prevent obsolete results replacing current state.
- App shutdown kills the helper group and descendants. A helper watchdog also
  kills its dedicated group if the app is force-quit. The helper refuses execution
  outside its own process group to make that watchdog safe.
- No shell, inherited proxies/secrets, user configs/plugins, account cookies,
  remote components, runtime dependency downloads, or raw diagnostic forwarding.
  Existing Swift ID/query/media-host/header/DRM validation stays authoritative.

## Packaging and verification

`Resources/worker.json` pins Python 3.13.15 (Astral standalone 20260929), yt-dlp
2026.8.19, yt-dlp-ejs 0.8.0 and certifi 2026.7.22 by size and SHA-256. The build-only
fetcher verifies archives, materializes internal links, preserves component license
notices and records a manifest/tree receipt. The bundler verifies that receipt,
signs native dependencies, and seals the app. The installer retains its strict
no-symlink inventory and edit protection. No system Python or Homebrew is needed
by the installed player. The old macOS extractor remains bundled for comparison
and compatibility tooling; the app no longer launches it.

Passed checks:

- Full Swift suite: **78 tests passed**, opt-in network source test separately skipped.
- Three new focused worker tests: shared initialization, correlation, duplicate
  coalescing, healthy request failures, startup/queued cancellation, selection
  priority, overload, stale replies, floods, hangs, crashes, bounded restarts and
  worker/descendant shutdown.
- `scripts/check-worker-protocol.py`: request option isolation, validation,
  anonymous options, no remote component downloads and diagnostic redaction.
- Release build and signed standalone bundle. All 16 native files use system or
  relative dependencies; deep/strict signature and no-symlink inventory pass.
- `scripts/check-app-lifecycle.py`: disposable paused restore/favorites, duplicate
  app, lazy helper startup, repeated window reuse, graceful shutdown and force-quit
  watchdog cleanup.
- `scripts/check-package-dependencies.py`: missing Node, legacy anchor executable,
  Python or worker script reports a safe error and preserves state/favorites.
- `scripts/check-installer.py`: install, idempotence, quoted paths, edit protection,
  upgrade backup, rollback, removal and unrelated-file preservation.
- SketchyBar renderer/routing check, including the concurrently added centered item.

## Installed artifact and rollback

Tested bundle: `/private/tmp/maro-worker-20261001/Maro.app`.

Managed installation: `/Users/devinhasler/Applications/Maro Local`.
Immediately before shutdown, two status reads confirmed the same paused/nonselecting
state. After installation and actual app restart, track `7rlIwnDh7dE`, exact position
`60.980263784`, favorites, playback state and volume matched. The volume-slider UI
and centered SketchyBar changes from other chats were preserved.

Rollback backup:
`/Users/devinhasler/Applications/Maro Local.backup-88cb5c6e7f9446dc9f1ff783ce198110`.
That is the backup created by this worker upgrade. A subsequent concurrent card
positioning task rebuilt/reinstalled the shared app, so the currently active receipt
may point to a newer backup. Its worker helper and pin manifest still match this
tested bundle. Preserve that newer UI work; do not reinstall an older binary merely
to match this report. The normal rollback command follows the **current** receipt
and restores the immediately preceding managed installation, not a fixed historical
pre-worker release:

```sh
python3 scripts/install.py rollback --prefix '/Users/devinhasler/Applications/Maro Local'
```

Run rollback only after orderly shutdown while paused, then relaunch. The first
upgrade attempt stopped before changing anything when another chat was updating
the installed plugin/receipt. After that completed, inventory validated and the
normal backup-preserving upgrade succeeded. No receipt protection was bypassed.

The paused implementation heartbeat and separate sustained audible-listening hold
remain unchanged.
