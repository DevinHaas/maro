# Start long videos progressively without a whole-file preparation timeout

ID: 06
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: resolved
Assignee: root / 01a0f702-d970-7c31-8e5c-44de0c743491
Blocked by: none

## Question

Why does https://www.youtube.com/watch?v=c3suauAz0zQ time out, and can native progressive loading start it without downloading the whole recording or the first ten to twenty minutes?

## Goal

Reproduce and fix preparation timeouts for the supplied long video using bounded progressive playback, verify startup and fetching beyond twenty minutes without loading the full recording, preserve pause/resume reuse and safe fallback behavior, and package and install the verified player improvements without interrupting active listening.

## Acceptance

- Diagnose remote responses and native player requests before choosing buffering. Prefer native segmented streams over a custom downloader.
- Compare the exact video before and after, at least twice after the change. Retain finite deadlines and existing-player preservation on failure.
- Demonstrate silent playback and a jump beyond twenty minutes using a partial buffer. Record transfer bytes; distinguish preferences from hard caps.
- Keep progressive fallback for videos without HLS and source URL/header/DRM/audio-only validation. Never persist expiring URLs.
- Run affected regression and packaging checks. Preserve state during reversible installation; do not claim the separate sustained audible-listening gate has passed.

## Answer

Implemented, verified and installed on 2026-10-01. [Diagnosis, measurements and reproduction](../assets/long-video-findings.md) show the actual large native byte-range requests, the timeout, and the native segmented-stream fix.

- The supplied two-hour video now prepares in 0.383–0.427 seconds, or 8.412–8.511 seconds including fresh extraction, on two production-path runs.
- Both audio-only HLS variants advanced silently with approximately 34 seconds buffered, then successfully sought and advanced past 21 minutes. Cumulative transfer stayed below 1.5 MB rather than fetching the complete recording. No ten-minute initial download is required.
- Keep validated progressive audio fallback, finite preparation deadlines, current-player preservation and loaded-item reuse. An earlier short video remains intermittently unavailable upstream; that is not claimed fixed. AVFoundation's thirty-second forward buffer is a preference, not a hard storage bound or offline guarantee.
- The complete suite passed with 74 tests; the separate opt-in source test remains skipped. Standalone release/signature, upgrade/rollback, isolated app lifecycle/paused restore and bar-routing checks passed. The saved opt-in HLS diagnostic was rerun successfully after temporary relay cleanup.
- Installed bundle: `/private/tmp/maro-progressive-20261001/Maro.app`, through the managed prefix `/Users/devinhasler/Applications/Maro Local`. The installer verified exact preservation of the user's latest paused video, position and favorites, then re-registered the bar handler. It did not restore an older snapshot or start audible playback.
- Backup: `/Users/devinhasler/Applications/Maro Local.backup-d00a8036827e41a29332320dbdfd5d4d`. To revert, safely stop Maro, run `python3 scripts/install.py rollback --prefix '/Users/devinhasler/Applications/Maro Local'`, relaunch, and register the restored plugin. The separate sustained audible-listening gate remains outside this goal and is not claimed passed.
