# Jump to a timestamp with the player timeline

ID: 08
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: claimed
Assignee: root / 01a0f292-f565-7cc2-8857-d15a8a2636b3
Blocked by: none

## Question

How can the existing Now Playing timeline support clicking and dragging to a
specific timestamp, like YouTube, without reloading healthy audio or disturbing
playlist navigation and the user's latest play/pause intent?

## Goal

Implement, package, and verify an accessible clickable and draggable timeline in
Maro's existing player popup that seeks the current video to a chosen timestamp,
preserves the latest playing or paused intent, safely handles unavailable ranges
and superseded operations, and preserves playlist behavior and saved position.

## User scope and research decision — 2026-10-02

The user requested research by a sub-agent, a new ticket, and placement in the
active AFK queue. This ticket is the next implementation priority, before the
remaining acceptance-only reconciliation. The research turn does not implement
or install it. This request supersedes the earlier display-only/no-seeking scope.

Default interaction: click the track or drag its thumb; preview the target time
locally while dragging and commit on release. Playing continues from the target;
paused stays paused. Seeking back from ended leaves a paused playable position
(Play resumes there, rather than restarting at zero). Do not add timestamp text
entry, chapter markers, thumbnail previews, global shortcuts or a second player.

### Repository findings

- `Sources/MaroApp/PlayerWindow.swift`, `PlayerCard.progress`, currently draws two
  noninteractive capsules and elapsed/duration labels. The popup already hosts
  SwiftUI and an AppKit `NSSlider` wrapper for volume. Use a macOS 13-compatible
  native slider first; an AppKit wrapper is justified only if SwiftUI cannot meet
  click-to-position, keyboard or styling requirements. Keep a generous hit target
  around the thin track and preserve the compact layout.
- `Sources/MaroCore/PlaybackEngine.swift` already provides `seekLoaded(to:)`,
  used by `MaroController.load` for reselection. It uses AVPlayerItem seeking with
  zero tolerances and a ten-second deadline. Its seek generation guard prevents
  an older completion's cleanup from cancelling a newer seek. However, its error
  path marks the item nonreusable for non-cancellation errors: a superseded seek
  must not poison a healthy item. Preserve or refine that distinction.
- `MaroController` owns transport intent, selection/queue identities, persistence,
  and end-event auto-advance. Add a narrow controller operation; the UI must not
  directly touch AVPlayer. Do not route scrubbing through public track selection,
  which can replace queue context and defaults to autoplay. Reuse loaded media;
  no fresh extractor request, YouTube API call, or whole-file download is needed.
- `PlayerSnapshot` exposes saved position and metadata duration but no playable
  range. Engine item readiness, finite duration and current seekable ranges need
  a small presentation contract. Existing `capturePosition`/`enqueueSave` and
  five-second position checkpointing should persist the confirmed seek, never
  intermediate drag previews. Existing playback identity filtering alone does
  not settle same-item end notifications racing a backward seek.

### Authoritative evidence and resulting design

Apple distinguishes [seekableTimeRanges](https://developer.apple.com/documentation/avfoundation/avplayeritem/seekabletimeranges)
from data already buffered (`loadedTimeRanges`); ranges may have gaps. Use actual
seekable ranges, not buffered data, to permit jumping ahead in long HLS videos.
Validate finite nonnegative bounds and intersect them with a finite positive item
duration. Prefer item duration over metadata; metadata alone does not prove an
item is seekable. Disable seeking while unready, with unknown/indefinite duration,
or without a usable range; reevaluate as readiness/ranges change. Live/DVR seeking
is out of scope. Clamp finite out-of-range targets to the closest allowed point
(ties choose the earlier point); never treat a gap as seekable.

Apple's [QA1820](https://developer.apple.com/library/archive/qa/qa1820/_index.html)
explains why a flood of seeks cancels useful work. Local drag preview followed by
one seek on release is sufficient here; Maro has no moving video preview. For
rapid commits or keyboard repeats, keep at most one seek in flight plus the newest
pending target, scoped to the current item/operation. Do not build an event queue
of every pointer movement. Cancellation on track replacement must remain bounded.

Apple's [seek completion API](https://developer.apple.com/documentation/avfoundation/avplayeritem/seek(to:tolerancebefore:toleranceafter:completionhandler:))
reports interruption as an unsuccessful completion; zero tolerances can add
decoding delay. Reuse the current exact-seek helper initially, with its bounded
deadline, and measure real HLS/progressive behavior. Do not promise instantaneous
network seeking or introduce a tolerance tuning framework without evidence.

The native [SwiftUI slider initializer](https://developer.apple.com/documentation/swiftui/slider/init(value:in:step:label:oneditingchanged:))
offers editing callbacks and an accessibility label. Validate keyboard and
VoiceOver changes independently: do not assume every input method emits a mouse
drag-end callback. Keep the draft value separate from periodic playback updates.

## Implementation boundaries

1. Preview `mm:ss`/`h:mm:ss` during drag and prevent position ticks from moving the
   thumb away from the user's pointer. Commit once on release/click; keyboard and
   accessibility adjustments commit too, with five-second increments clamped to
   valid ranges. Label the control “Playback position” with spoken time/duration.
2. Validate again in the controller/engine at commit, including NaN/infinity,
   readiness and changed ranges. Disable while selecting another track; allow
   safe seeks from playing, paused, buffering and ended when a ready item exists.
   An app restored with metadata but no prepared item shows a disabled timeline
   until playback preparation makes it seekable; do not start audio to enable it.
3. Preserve the latest explicit transport intent, including Pause pressed during
   a pending seek. Never resume from an old captured intent after a newer Pause.
   A successful ended-to-earlier seek clears ended state without autoplay.
4. Track changes, Next/Previous, queue advancement, replacement/recovery and
   shutdown invalidate pending seeks and local drafts. Same-video duplicate queue
   occurrences need playback/operation identity, not video ID alone. Closing the
   popup discards an uncommitted draft. A stale completion cannot update position,
   persistence, error state or playback for another occurrence/item.
5. Suppress stale end/position events while reconciling a seek; seeking backward
   near the end must not advance the queue. A completed seek to the actual end
   while playing follows existing end behavior exactly once (advance in a
   playlist, ended otherwise); while paused it must not auto-advance. Do not fake
   completion from metadata duration or advance from a cancelled seek.
6. On failure/timeout, leave the same track and queue available, display a concise
   existing-style error and reconcile to the actual engine position; do not save
   the requested target as success. Cancellation/supersession is not a user-facing
   playback failure. No automatic playlist skip or audible recovery from scrubbing.

## Acceptance and delivery

- Focused offline tests cover playing/paused/ended intent, Pause during seek,
  confirmed-position persistence/reopen, finite target validation, bounds/gaps,
  empty/changing ranges, unknown duration and seek failure/timeout. Reuse current
  `PlaybackEngineTests`, `MaroControllerTests`, `PlaybackEventTests` and fixtures.
- Race tests prove newest-target wins with bounded pending work, stale completion
  cannot affect a replacement/duplicate queue occurrence, and a near-end backward
  seek cannot advance the queue. Test deliberate end seeking and exactly-once
  advance versus paused no-advance. No extra resolution on a healthy loaded seek.
- Native UI check covers click-to-position, drag preview/release, keyboard focus
  and arrows, accessible time/value, popup close/reopen, compact hit targets and
  disabled states. Test progress ticks during drag and a track change during drag.
- Muted, disposable-state probes verify short progressive audio and the known
  long HLS video `c3suauAz0zQ`: forward beyond twenty minutes/outside the current
  buffer and backward again. Record requested/actual times, completion latency,
  source type and error outcomes; timeout/failure is not success. Never alter the
  installed user's playback for probes or claim a listening gate from these tests.
- Run focused checks, the full Swift suite, release build and existing standalone
  signature/dependency/package checks. Use the backup-preserving installer only
  when paused/idle and not selecting; compare latest track/position/volume/favorites
  before and after. If actively listening, leave the tested bundle ready. Keep
  unknown manual/physical acceptance explicit and do not resolve on fixture-only
  evidence when a required installed UI check remains unverified.

## Ownership and AFK execution

Claim before implementation; use this Goal verbatim with `create_goal` (inspect
an existing goal first, no invented token budget). Preserve all shared uncommitted
work. The implementation worker owns the minimum engine/controller/popup changes,
focused tests and delivery evidence. Do not create a clean worktree that loses
the largely untracked implementation. No implementation was performed by research.

Resolve only after the goal and acceptance are achieved; record evidence under
Answer and link a concise resolution in the map. Keep the existing active
five-minute heartbeat/coordinator, with this issue ahead of acceptance-only work.
Do not start audible playback or restart the held thirty-minute listening test.

## Answer

Latest delivery: final build installed 2026-10-03, 92 tests passing, signature and
four dependency checks passing. Exact latest paused state/volume preserved.
Timeout/supersession and draft cancellation/tick checks now pass. Installed
metadata-only disabled timeline observed. Remaining: physical drag/release and
ready-track installed interaction confirmation. Keep claimed until confirmed.

Native goal blocked on user/physical interaction evidence after repeated coordinate
tool failures. Confirm a prepared track remains paused after dragging/release and
retains the chosen position on popup close/reopen. This is not a completion claim.
See docs/PROGRESS.md for earlier build history and detailed verification evidence.
