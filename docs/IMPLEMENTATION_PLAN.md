# Maro implementation plan

Updated: 2026-09-30 (Europe/Zurich). Execution ledger: [PROGRESS.md](PROGRESS.md).

## Where HumanLayer stopped

The repository's only commit is `bfb50e9` (empty application tree). The existing
untracked `.gitignore` belongs to the workspace. No application, tests, package,
implementation plan, or release exists. Swift 6.2 and SketchyBar are available;
`yt-dlp` is not on PATH. The active bar currently includes a Spotify item.

Original HumanLayer artifacts are preserved in `docs/original-design/`.
They moved into the project on 2026-10-02 and no longer depend on HumanLayer.

| Artifact | Role in the implementation |
| --- | --- |
| `task.md` | Original request; later PRD supersedes initial C/next-track suggestions |
| `01-research-questions-player-architecture.md` | Research scope |
| `02-research-ray-j-reference.md` | Grayjay reference; not a requirement to copy its stack |
| `03-research-player-platform-map.md` | Empty-repository baseline and platform constraints |
| `research.md` | Detailed SketchyBar and source research |
| `04-prd-sketchybar-music-player.md` | Product behavior and acceptance authority |
| `05-tdd-sketchybar-music-player.md` | Latest architecture; ends at an empty Patterns to Follow heading |
| `mockup-search-entry-options.html` | Focused native search panel |
| `mockup-search-results-options.html` | Thumbnail/title/creator/duration result rows |
| `mockup-result-navigation-options.html` | Historical queue/Next proposal, superseded by final PRD |
| `mockup-bar-controls-options.html` | Explicit controls popup |
| `mockup-favorites-options.html` | Favorites inside the bar popup |
| `mockup-end-of-track-options.html` | Ended state and replay |
| `show-me-yt-dlp-avplayer-byte-flow.html` | AVFoundation fetches media directly; extractor returns metadata |

Mockups contain alternative proposals; implement the choices recorded in the PRD,
not every option. The TDD establishes architecture but leaves protocol limits,
timeouts, failure classification, migration policy, and acceptance procedures to
implementation. Resolve those narrowly and record evidence here or in PROGRESS.
The independent artifact audit confirmed all 14 artifacts and specifically rejected
the older queue/Next mockup as an implementation requirement.

## Fixed product and architecture decisions

User scope update, 2026-10-01: manual Next/Previous through current search results
is authorized by MARO-002. This supersedes the original exclusion of those manual
controls below; end-of-track autoplay and a separate queue remain out of scope.

- One native Swift/AppKit companion owns state and the search window. AVPlayer
  owns one loaded video. SketchyBar is a command/rendering surface.
- Anonymous YouTube search, at most 20 results fetched once per submission; show
  five, then reveal five locally. Results never become a queue.
- Selecting a playable result replaces the current video; failed selection keeps
  the existing video and its playback state. Search browsing never interrupts it.
- Audio-only M4A/AAC streamed directly by AVFoundation. No proxy, FFmpeg, combined
  audio/video fallback, media downloads, or runtime extractor self-updates.
- Click idle bar item to search; click loaded item to open Now Playing/Favorites.
  Popup has transport, favorite, and search actions. No system media-key controls.
- Pause/resume; retain the video at end and offer Replay. Relaunch paused at the
  saved position. No autoplay, next/previous, queue, account, or cloud sync.
- At most 20 favorites, newest first, no silent eviction. Unavailable favorites
  remain saved. Cache loss cannot lose favorites or metadata.
- One versioned JSON state file; atomic writes; preserve corrupt/unknown state
  for diagnosis. Never persist signed media URLs or transient search/error data.
  Optional `sourceDisabledBuild` records a confirmed incompatibility until the
  app/extractor build changes; it is a durable gate, not a transient error record.
- Local user-only AF_UNIX, versioned newline-delimited JSON, one request/response.
  `maroctl` performs bounded Launch Services recovery. No network listener.
- App triggers `maro_state_changed`; shell plugin pulls one authoritative status
  and updates SketchyBar in a batch. Hot reload does not restart playback.
- One main-actor controller commits mutations; stale async results cannot replace
  newer user intent. Slow subprocess/network/disk work stays off the UI thread.

## Ordered milestones and completion gates

### M1 — Durable state foundation

Create the Swift package and shared value models, bounded favorites and local
search pagination, validated state storage with atomic writes and preserved
corruption. Add only implemented targets; app/CLI targets arrive with real code.

Gate: `swift test` covers 20/21 favorites, duplicate identity, order/removal,
five-at-a-time pagination, invalid persisted data, round trip, and preservation of
corrupt/unsupported versions. No third-party package required.

### M2 — Source adapter and direct-playback feasibility

Pin an official macOS yt-dlp release and checksum in a manifest. Account for its
JavaScript runtime dependency explicitly. Current upstream documentation requires
a supported runtime for full YouTube support; the old TDD omits this dependency.
Prefer an existing compatible runtime for development; define reproducible
packaging before calling the app self-contained. Do not fetch scripts at runtime.

Invoke with argument arrays, `--ignore-config`, anonymous access, JSON output,
bounded stdout/stderr, timeout/cancellation, and no shell interpolation. Normalize
up to 20 metadata results; resolve an audio-only AAC/M4A descriptor. Reject invalid
IDs, non-HTTPS media URLs, malformed metadata, unsupported required headers, and
combined streams. Keep signed URLs out of logs/state. Classify unavailable video,
network/bot failures, extractor incompatibility, and missing runtime separately.

Gate: deterministic JSON fixtures and process failure tests; a real anonymous
search and AVFoundation preflight on public videos. Record exact binary/runtime
versions and live outcome. If live access is unavailable, mark this gate blocked
and continue independent fixture/UI/IPC work; do not claim playback is verified.

References: [yt-dlp](https://github.com/yt-dlp/yt-dlp),
[JavaScript requirements](https://github.com/yt-dlp/yt-dlp/wiki/EJS).

### M3 — Playback and controller

Implementation evidence (2026-09-30): moving a prepared AVPlayerItem from a muted
staging player into the persistent player raised AVFoundation's multiple-player
association exception despite `replaceCurrentItem(nil)`. Keep one PlaybackEngine
and one audible player, but commit by handing over the whole ready muted player,
pausing/releasing the old player first. This refines the TDD's literal singleton
AVPlayer identity to preserve its stronger requirement: failed preparation must
not interrupt current audio. No queue or additional audible player is introduced.

Implement AVPlayer preparation before committing replacement, documented asset
options, callbacks, pause/resume/replay, paused restoration, and coalesced position
persistence (flush on pause/end/replacement/quit). Use separate search/selection
operation identities. Keep old playback until a new candidate is ready. Cancel
obsolete work. Bound expiry recovery to one re-resolution per failure episode;
seek near the previous position, preserve pause intent, and expose failures.
Latch genuine extractor incompatibility for this app build and stop automatic
probing; preserve local metadata/favorites. Do not classify every timeout as drift.

Gate: deterministic controller checks for stale completion, failed replacement,
pause during pending work, end/replay, restore, persistence failure, source update
state, and recovery limit. Real playback evidence remains a separate live gate.

### M4 — App lifecycle and local CLI

Add working MaroApp/MaroCLI executables and shared Codable request/response types.
Implement user-owned socket directory/file permissions, current-user peer checks,
length limits, read/write deadlines, partial I/O, protocol/command validation,
request ID matching, stale-socket ownership checks, and orderly cleanup. A second
instance must not unlink a live server's socket. Launch Services recovery is
bounded and must not replay commands after an ambiguous executed response.

Initial commands: status, search (open panel), toggle, replay, select VIDEO_ID,
favorite toggle/remove. Expose typed error responses and nonzero CLI failure exit.

Gate: real local socket round trips, malformed/oversized/unsupported requests,
stalled peer, missing server, duplicate instance, and CLI argument checks. Keep
test data/socket under temporary directories; no real favorites are touched.

### M5 — Focused AppKit search and thumbnails

Build the compact search panel using native controls with keyboard focus, Return
submission/selection, Escape dismissal, accessible labels and visible loading,
empty, unavailable, retry, and needs-update states. Render title/creator/duration
and artwork for five rows; reveal locally. Close only after playback starts.
Cache validated images atomically by stable identity; publish only existing local
paths. Missing images never block playback. Bound downloads and cache growth.

Gate: native build plus panel interaction checks and cache failure tests; search
does not interrupt playback; failed selection keeps the panel open. Inspect UI.

### M6 — SketchyBar integration

Add repository-owned item/plugin shell scripts following the existing config
style. Register event once, launch Maro idempotently, pull on startup/reload,
render Now Playing/Favorites, all actions, end/error states, and artwork. Pass all
remote text as arguments; never eval it. Render a snapshot in one transaction.
Keep bar presentation in scripts. Do not replace the existing Spotify integration.

Gate: shell syntax, hostile-title argument test, snapshot rendering fixture,
event refresh, favorites capacity, and real hot-reload without audio interruption.

### M7 — Package and reversible installation

Assemble Maro.app, exact pinned extractor/runtime resources, Info.plist and CLI;
sign nested executables before the hardened app, with minimal entitlements.
Provide an idempotent installer with explicit destination options, backups,
uninstall/rollback, and clear dependency errors. Exercise it first in a temporary
destination. Install into the real user configuration only with tool permissions;
do not replace unrelated config or bypass rejected approvals.

Gate: release build, signature verification, packaged resource resolution with a
minimal GUI PATH, package launch/status, missing dependency behavior, and installer
round trip preserving unrelated files. No Developer ID/notarization claim without
the actual identity and verification.

### M8 — Acceptance and handoff

Run the complete PRD workflow: idle search, five/more, select, recognize artwork,
pause/resume, favorite/reselect, capacity/unavailable, end/replay, relaunch paused,
bar hot reload, corrupt-state recovery, source failure/update behavior. Complete a
measured 30-minute listening session, reporting observed stalls/failures honestly.
Provide build/run/install instructions and exact remaining limitations.

Gate: all applicable checks pass and live evidence is recorded. Missing playback
or a pending listening session means acceptance is pending, even if tests pass.

## AFK execution contract

User update, 2026-10-01: resume the AFK loop and implement the visual redesign ticket
[MARO-001](tickets/MARO-001-player-redesign.md) as the next coherent slice. Its saved
reference supersedes previous popup styling. Preserve existing single-track behavior
and the corrected popup click handling. Remaining acceptance gates still apply.

Use the native Codex heartbeat attached to this chat every five minutes. One
coordinator performs one coherent milestone or bounded slice per run, verifies it,
and updates PROGRESS with files, checks, failures, next action, and blockers.
Re-read current files/status before editing; never run overlapping build agents.
Use at most one short-lived sub-agent for an independent review or concrete blocker;
the initial artifact audit is that review. No persistent agent pool or custom daemon.

Preserve existing work. Do not push, deploy, or publish. Work in this checkout and
the existing feature branch. Prefer normal tool permission flow for necessary
installation/network actions. A blocked live dependency does not block independent
work. Do not repeatedly retry an unchanged failure or weaken acceptance to go green.

Notify only for a completed milestone, meaningful failure, required user action,
or final completion. Stay quiet when nothing actionable changes. When all gates
are complete, pause the heartbeat and report the result. If every remaining item
needs unavailable external input, record and report the blockers and pause the
heartbeat rather than burning repeated runs. Re-enable only after new input.
