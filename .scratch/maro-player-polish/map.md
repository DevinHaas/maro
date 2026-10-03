# Responsive SketchyBar player with reference-aligned controls

Status: open
Labels: wayfinder:map

## Destination

Make Maro's SketchyBar transport match the supplied visual reference, make repeated pause/resume reuse prepared audio, and reduce measured search and playback-start delays. Each implementation ticket is a separate AFK goal with evidence-based completion checks.

## Notes

- This is a local Markdown tracker, following `/Users/devinhasler/.agents/skills/setup-matt-pocock-skills/issue-tracker-local.md`. Earlier work remains in `docs/tickets/`; links below are relative to this map.
- Execution override: the user requested buildable AFK goal tickets, then authorized implementation with “perfect lets go then.” Work proceeds through sequential goals in this chat; the paused heartbeat remains untouched. This overrides the original one-chat-per-goal planning convention below.
- Follow-up authorization: the user requested a new implementation agent for session-wide yt-dlp reuse. That delegated agent owns the new worker ticket; the earlier completed goals remain resolved. Keep the existing checkout because it contains uncommitted/untracked implementation work.
- Consult wayfinder and quick-recap each session. Use research for external facts; use relevant design guidance for the layout. Preserve existing playback, Favorites, IPC, and navigation contracts.
- Vocabulary: **search** retrieves metadata; **resolution** obtains a playable source descriptor; **preparation** makes audio ready for the playback engine; **resume** continues the loaded track; **prefetch** speculatively prepares an unselected result. Measure these separately.
- Start one implementation chat per goal. Claim its ticket first (`Status: claimed`, `Assignee: <agent/chat>`), call `create_goal` with that ticket's Goal verbatim, and keep working through implementation and verification until its acceptance checks pass. Do not invent a token budget. Record evidence and call `update_goal(complete)` only on actual completion. If interrupted, preserve progress and the outstanding checks; a draft or elapsed time is not completion. Goal-tool blocking rules still apply.
- Keep work isolated from other agents and the installed player's audio. Use disposable state and silent/local fixtures. Respect the existing explicit hold on live audible probes in `docs/ACCEPTANCE.md`; do not start music or count the unfinished 30-minute listening gate as passed. Where installed/manual verification is unavailable, document the remaining gate and leave the goal incomplete.
- The user supplied both the target and current-player screenshots; their interpretation lives in the resolved reference ticket. Follow-ups extend [Compact player popup redesign](../../docs/tickets/MARO-001-player-redesign.md) and [Next and Previous](../../docs/tickets/MARO-002-track-navigation.md), without rewriting their historical evidence.
- Local tracker operations: child issues live in `issues/`; each records its parent, type, label, status, assignee, and `Blocked by` IDs. Open, unclaimed children whose blockers are resolved form the frontier, in numeric order. Claim before work; append resolution under `## Answer`, set resolved, and link a one-line gist here. This tracker has no native dependency UI.

## Decisions so far

<!-- Closed decision tickets only; details live in each ticket's Answer. -->

- [Determine the fastest suitable YouTube search and retrieval approach](issues/03-choose-search-provider.md): keep the no-key provider, measure stages and reuse metadata first; the official API is not a native-audio replacement.
- [Capture the new transport reference](issues/05-capture-transport-reference.md): target and current screenshots saved; replace stacked transport rows with aligned icons in a shared horizontal green strip.
- [Align Previous/Next and transport styling with the player reference](issues/01-align-transport-controls.md): installed a verified native card in the existing companion, with a shared horizontal transport strip and independent hit targets.
- [Reuse prepared audio and reduce playback preparation time](issues/02-reuse-prepared-audio.md): reuse the healthy loaded player, coalesce duplicate selections, and prepare a bounded fallback before a stalled preferred stream exhausts its timeout.
- [Reduce time to the first useful YouTube search results](issues/04-speed-up-search.md): retain eight fresh metadata batches for one minute, eliminating repeated extraction while preserving five-at-a-time reveal and all twenty navigable results.
- [Start long videos progressively without a whole-file preparation timeout](issues/06-progressive-long-video.md): native HLS fixes the supplied two-hour example, verifies fetching beyond twenty minutes, and delivers the combined installed update with state preservation and rollback.
- [Reuse one initialized yt-dlp worker throughout a Maro session](issues/07-reuse-ytdlp-worker.md): installed a lazy bundled worker; uncached search and resolution medians improved by 87% and 82%, with bounded cancellation/recovery and verified progressive HLS.

## Next AFK priority

- [08 — Jump to a timestamp with the player timeline](issues/08-seek-playback-timeline.md)
  is implemented and installed; physical drag/release confirmation is pending.
  Native goal is blocked, not complete. Do not redo issues 01–07 or repeatedly
  probe this user-dependent gate. The existing heartbeat is PAUSED (2026-10-03)
  for user acceptance; its original five-minute schedule is retained.

- [09 — Make every Maro surface feel like part of the SketchyBar card](issues/09-unify-swift-app-styling.md)
  is delivered and claimed pending final visual acceptance. The user requested this comprehensive Swift
  presentation restyle on 2026-10-02. Implementation proceeds after issue 08 delivery and before
  acceptance-only reconciliation. Match the current card across search,
  playlists, app-owned dialogs and all UI states; retain existing behavior.
  Implementation and renderer checks are complete; strict original baseline
  screenshots remain unavailable through supported tools. Current UI is inspected.
  The five-minute heartbeat is paused pending user feedback. Issue 09
  supersedes the older restriction on a wholesale UI rewrite only for the
  requested presentation work, not unrelated features or playback architecture.

## Not yet specified

The runtime-startup goal is implemented and measured. Further retrieval improvements require new evidence; upstream availability and latency remain variable.

## Out of scope

- Queue/autoplay, shuffle/repeat behavior, extra music providers, a second player, or a wholesale UI rewrite.
- Unbounded media retention, preparing all 20 search results automatically, credentials provisioning, or paid API setup without a separate need and user authorization.
- Completing the earlier manual sustained-listening acceptance by inference from automated checks.
