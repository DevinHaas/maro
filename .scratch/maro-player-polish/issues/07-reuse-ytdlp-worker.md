# Reuse one initialized yt-dlp worker throughout a Maro session

ID: 07
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: resolved
Assignee: /root/persistent_ytdlp_worker
Blocked by: none

## Question

How can Maro initialize yt-dlp once on first use and reuse the running runtime for subsequent search and audio-resolution requests, eliminating the measured repeated startup cost?

## Goal

Implement, package, and verify one lazily initialized yt-dlp worker per running Maro app session, reuse it for subsequent searches and audio resolutions without repeated runtime startup, and demonstrate the latency improvement while preserving cancellation, bounded recovery, existing playback, and standalone installation behavior.

## User decision and evidence

The user explicitly chose session-wide reuse: initialize on the first player/search interaction, then reuse until the app exits. They authorized this ticket and handoff to a new implementation agent. This is implementation authorization, not a request for another design-only proposal.

[Startup measurements](../assets/extractor-startup-findings.md) show 6.46–6.69 seconds for the bundled extractor even when it only prints its version; the installed copy took 6.50–6.63 seconds. One search took 7.95 seconds total, and resolution of `c3suauAz0zQ` took 8.98 seconds. Most delay precedes network work. Initialization, unpacking and OS/runtime checks were not individually separated.

The current Swift `YouTubeClient` launches a new CLI process for every cache miss. Merely making that Swift object a singleton will not meet this goal. Reuse the actual initialized Python/yt-dlp runtime. The upstream [Python embedding API](https://github.com/yt-dlp/yt-dlp#embedding-yt-dlp) supports extracting metadata without downloading media. A pre-unpacked distribution can help packaging/startup, but alone is not the requested persistent-worker implementation.

## Implementation scope

1. Give the existing app lifecycle ownership of one worker. Initialize lazily on first player/search use (and direct resolution if used first). Concurrent first requests share one initialization. Keep the UI responsive, reuse until shutdown, and reap the worker and descendants on exit. Scope is one app lifetime, not persistence through reboot.
2. Embed the pinned yt-dlp library in a bundled helper/runtime and exchange bounded, correlated search/resolve requests over private local communication, preferably pipes. Reuse existing process, decoding and error-handling code where it fits. Avoid a web server, worker pool, generic service framework, or system Python/Homebrew dependency. Keep request-specific search/resolve options isolated; a warm runtime need not mean unsafe concurrent mutation of one `YoutubeDL` object.
3. Handle obsolete searches, duplicate work, explicit selection priority and cancellation. Do not let an abandoned search hold a selected track behind an unbounded queue. Apply startup/request deadlines, bounded queues/output, and a bounded restart policy after crashes or hangs. Exceptional recovery may restart the runtime; healthy requests must not. Fail pending callers deterministically and prevent late replies from replacing newer results or playback.
4. Preserve the no-shell invocation boundary, minimal environment, anonymous operation, disabled user configs/plugins/remote code downloads, validated video IDs and queries, HTTPS/media host/header/DRM/audio-only checks, error classification and diagnostic redaction. Keep signed audio URLs ephemeral. Do not blindly forward Python exception text or raw extraction output to logs or UI.
5. Preserve the existing eight-batch/60-second metadata cache, full twenty-result batch with five-at-a-time reveal, navigation, favorites, HLS preference with progressive fallback, short native buffering and loaded-player reuse. No automatic speculative preparation of five tracks, official API integration, or UI redesign.
6. Update pinned assets, checksums/notices, bundling, lifecycle and installer checks as needed for a self-contained signed development bundle. Download dependencies only during a verified build, never on first user playback. Preserve installation validation and edit protection rather than bypassing them for the helper layout.

## Acceptance and evidence

- An offline instrumented check proves concurrent first use launches one worker; multiple distinct uncached searches and resolutions reuse that healthy worker/runtime, including after a request failure. Cache hits alone do not prove worker reuse.
- Focused runnable checks cover request correlation/option isolation, stale replies, cancellation while initializing/queued/running, duplicate requests, bounded overload/output, worker crash/hang recovery, and shutdown with no orphan descendants. Reuse existing fixtures and test framework; do not build a separate testing system.
- Record at least three cold and three warm measurements on fixed representative queries and IDs. Separate initialization, metadata search, stream resolution and native audio preparation. Exercise fresh requests on an already warm worker so cache hits cannot mask startup. Healthy warm requests must show zero runtime relaunches. Target at least a 50% reduction in median uncached search and resolve elapsed time versus the existing per-process path on the same machine; report upstream failures and variance honestly. If uncontrolled network effects obscure the target, gather enough isolated startup evidence and investigate before declaring completion.
- Verify `c3suauAz0zQ` still prepares through HLS and preserves the progressive behavior documented in [long-video findings](../assets/long-video-findings.md). Use muted/disposable probes only; keep the user's separate sustained audible-listening hold in place.
- Run affected Swift/Python checks, the existing full Swift suite, release build, standalone dependency/signature checks, isolated lifecycle/paused restore and installer upgrade/rollback checks. Latest baseline: 74 Swift tests passing, with a separate opt-in source test skipped.
- Deliver the tested bundle, benchmark results, ticket resolution and rollback details. Use the established backup-preserving installer when the installed app is paused/idle and not selecting; verify the exact latest track/position/favorites before and after. If the user is actively listening, leave the tested bundle ready and report installation as pending. Never interrupt playback or restore an older state snapshot.

## Ownership and AFK execution

The delegated worker owns this ticket and the necessary source/client/process/lifecycle, helper, packaging, tests and documentation changes. It is not alone in the shared checkout: preserve all existing edits and coordinate any overlap. The current code and tickets are largely untracked; do not reset, clean, or create a fresh Git worktree that loses them, and do not stage unrelated files.

Claim this ticket before implementation. Read the map and relevant repository instructions, then call `create_goal` using Goal above verbatim, without inventing a token budget. Work until implementation and acceptance are complete; do not stop after a plan. If an existing native goal is already active, inspect it before attempting another. Record findings and limitations under `## Answer`, resolve the ticket and append a link/gist to the map only when justified. Mark the native goal complete only when its objective is achieved. Do not resume the paused heartbeat.

Useful entry points: `Sources/MaroCore/YouTubeClient.swift`, `YouTubeSource.swift`, `ExtractorProcess.swift`, `MaroController.swift`, `Sources/MaroApp/MaroApp.swift`, `SearchWindow.swift`, source/process/controller tests, `Resources/extractor.json`, `Resources/runtime.json`, `scripts/bundle-development-app.py`, `scripts/install.py`, and existing measurement/check scripts. Historical progress/acceptance files contain old status; the map and recent linked evidence describe the installed improvements.

Current managed prefix: `/Users/devinhasler/Applications/Maro Local`. Current pre-worker bundle: `/private/tmp/maro-progressive-20261001/Maro.app`. Read the running state and installation receipt afresh; paths and snapshots are not permission to overwrite newer user changes.

## Answer

Implemented and installed one lazy persistent Python/yt-dlp worker per Maro app
lifetime, with correlated private pipes, duplicate sharing, bounded queues and
recovery, selection priority, cancellation, and process-group cleanup. Runtime
and libraries are pinned and bundled; no runtime downloads/system Python required.

Three paired benchmarks show median uncached search improving from 7.732s to
1.010s (87%) and resolution from 8.407s to 1.476s (82%). Initialization is 0.349s
median, and all healthy requests reused the worker PID. The exact long video still
uses short HLS buffers and passes a muted seek beyond 21 minutes.

Full Swift suite: 78 tests passed, opt-in live source test skipped. Focused worker,
Python option/protocol, release/signature/dependency, lifecycle/crash cleanup,
installer upgrade/rollback and renderer checks passed. The signed bundle was
installed while paused with exact latest track/position/favorites/volume preserved,
including concurrent volume-slider and centered-bar improvements.

[Persistent worker findings](../assets/persistent-worker-findings.md) contain the
full timing table, bounds, reproduction steps, installed artifact and rollback
backup. The sustained-listening hold and paused heartbeat remain untouched.
