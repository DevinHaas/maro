# Tidal follow-up improvements — review backlog

Date: 4 October 2026. Research baseline: `32ccc9a57d3faf5d947a5087a46c21d027dd484e`
on `codex/tidal-integration`, draft PR #15. This is an investigation and product
review backlog, not an approved implementation spec. Each improvement has a
separate research sub-agent. Application implementation remains at the checkpoint.

The user requests more room in result rows, a shared save-destination interaction,
simpler account/sidebar controls, working playlist drag-and-drop, a playlist
toolbar, and a coordinated SketchyBar experience. Requested spacing and control
placement changes intentionally supersede the earlier exact-layout restriction
for those surfaces. Unrelated navigation, playback, occurrence identity, native
symbols and account behavior should remain stable.

## Reference images

- [Current cramped search row](assets/tidal-improvements/search-row-current.png)
- [Current sidebar status](assets/tidal-improvements/sidebar-status-current.png)
- [Playlist toolbar reference](assets/tidal-improvements/playlist-toolbar-reference.png)

The Spotify screenshot is a visual reference for supported controls only. It
does not authorize shuffle, downloads, album columns, collaboration or other
unsupported features.

## Review workflow

1. Review these findings and resolve the product decisions below.
2. Write and approve a focused follow-up spec with observable acceptance criteria.
3. In a new session, use `/implement-spec` with the approved spec and ticket graph.
4. Give each improvement its own implementer sub-agent/worktree, integrating
   shared dependencies first. Do not start implementation from this research pass.

The previous checkpoint's native acceptance and CLI/lifecycle checks are not
implicitly complete. Relevant failures must be reproduced and resolved before
claiming the SketchyBar/installed-app integration works.

## Work items

All nine issues are **proposals for review**, with no `ready-for-agent` label.
Each has its own independent investigation, source evidence, acceptance criteria
and validation approach.

| Issue | Improvement | Actionable finding / proposed change |
| --- | --- | --- |
| [#16](https://github.com/DevinHaas/maro/issues/16) | Roomier search results and scrolling titles | Current nominal64pt rows have4pt gaps and only about106pt derived metadata width at the minimum window with library open. Propose72pt rows/6–8pt gaps, bounded columns and narrow-width layout. Reuse the compact card's existing native scrolling-title component. |
| [#17](https://github.com/DevinHaas/maro/issues/17) | Home hover plus and destination popover | Replace Save text with a reserved bottom-right plus, revealed on hover/focus. Open a native button-anchored popover with Favorites and all eligible own playlists; preserve duplicate checks and explicit progress/error results. |
| [#18](https://github.com/DevinHaas/maro/issues/18) | Larger account icon without arrow | Keep the native account menu and all its current actions. Propose36pt icon/44×44pt actual target, hide native menu indicator and verify keyboard/target behavior. |
| [#19](https://github.com/DevinHaas/maro/issues/19) | Connection-only sidebar footer | Remove connected-success footer/padding. Show setup/reconnect guidance when needed; keep operation failures accessible elsewhere. Existing stored-token presence does not prove authorization health. |
| [#20](https://github.com/DevinHaas/maro/issues/20) | Fix native playlist drag/drop |15 focused model/API tests pass; native pointer delivery remains unverified. Reproduce in the disposable production-view fixture and trace handle→session→destination→payload→write to fix the first failing boundary. |
| [#21](https://github.com/DevinHaas/maro/issues/21) | Playlist search and per-track saving | Toolbar contains round Play, existing actions and right-side search. Save plus controls belong to individual tracks and reuse the destination popover. Preserve occurrence IDs, original positions and full playback queue. |
| [#22](https://github.com/DevinHaas/maro/issues/22) | Hover collapse at left of library header | Replace the leading library glyph with collapse on sidebar hover/focus. Proposed46pt collapsed rail keeps Show library accessible after removal of the global toggle. |
| [#23](https://github.com/DevinHaas/maro/issues/23) | Tidal compact SketchyBar card | The card is native `PlayerCard`, not SketchyBar popup content. Apply shared Tidal surfaces/controls while preserving compact layout, artwork, seek/volume, Favorites, focus and panel lifetime. |
| [#24](https://github.com/DevinHaas/maro/issues/24) | Connect SketchyBar to current app | Live handlers target the old managed installation; new test build is intentionally isolated. Repair its reproducible invalid status response first, then perform a verified managed upgrade and canonical socket cutover. |

## Decisions to settle before the spec

**Save scope confirmed by the user:** plus/save applies only to individual tracks.
There is no playlist-level plus, bulk playlist saving, playlist bookmark, or new
track-selection mode. Home cards and individual playlist-track controls bind the
shared destination popover directly to their own video.

1. **Scrolling activation.** Recommend hover/keyboard-focus activation for
   overflowing row titles, using the existing compact-card pan-and-return motion.
   Automatic scrolling is an alternative. The bar's own text uses a different
   wraparound motion. Reduced Motion always uses static truncation and full-title
   help/accessibility text. Propose applying the same row improvement to Favorites,
   which shares the component; preview/playlist-row titles stay outside this item.
2. **Collapsed library.** Recommend the46pt persistent left rail with Show library.
   A hidden sidebar cannot reveal its own hover-only button. Expanded collapse
   remains visually quiet except on hover/focus; keyboard and accessibility focus
   visibility are required exceptions to hover-only behavior.

Other proposed defaults for review: plus belongs to the **card** bottom-right,
separate from artwork playback; destination selection saves immediately; Favorites
retains toggle behavior; initial popover success stays visible until dismissal.
Reconnect uses the existing Google sign-in flow with clear wording, rather than
a disconnected no-op refresh. Choose the minimum auth-state extension required
to represent definitive reauthorization without confusing network/quota failures.
Compact transport uses separate main-app-style controls and a consistent heart.

For installation, preserve canonical installed favorites/account/state by default.
Review any newer isolated-test favorites/resume changes before migrating them;
never silently replace one state file with the other.

## Implementation order and ownership

- **First technical risks:** #24's status-response repair and #20's actual native
  drag reproduction. Both can be investigated independently of visual changes.
- **Shared UI foundations:** #16 extracts/reuses native title scrolling before
  #23 edits the same card title; #17 establishes save destination/result handling
  before #21 consumes it in individual track controls. Playlist search itself
  does not depend on the save popover. Save handling shares error-feedback
  decisions with #19.
- **Shell edits:** #18, #19 and #22 share `AppShellView.swift`. Keep one sub-agent
  per improvement, with explicit hunk ownership and sequential integration.
- **Playlist integration:** coordinate #20 and #21. Recommended first version
  disables pointer reorder during active filtering; keyboard Move to position
  can retain explicit full saved-order positions.
- **Final activation:** after integration/build/native checks, #24 promotes the
  verified app to the existing managed installation, preserving account/state,
  receipt and rollback. Verify both bar anchors, matching CLI/process/socket,
  status after Home discovery, loaded/empty clicks, notifier updates and recovery.

Current base matters: [PR #15](https://github.com/DevinHaas/maro/pull/15) remains a
draft on `codex/spotify-redesign`, while [PR #7](https://github.com/DevinHaas/maro/pull/7)
is open against `main`. Start future planning from the actual Tidal checkpoint,
not an older `main`. Recheck branch/PR state when the new session begins.

## Evidence and honest limits

- All nine improvements received distinct research sub-agents. Detailed reports:
  [search rows](../research/tidal-improvements/search-rows.md),
  [Home save](../research/tidal-improvements/home-save.md),
  [account button](../research/tidal-improvements/account-button.md),
  [sidebar status](../research/tidal-improvements/sidebar-status.md),
  [drag/drop](../research/tidal-improvements/playlist-drag.md),
  [playlist toolbar](../research/tidal-improvements/playlist-toolbar.md),
  [sidebar collapse](../research/tidal-improvements/sidebar-collapse.md),
  [compact card](../research/tidal-improvements/sketchybar-card.md),
  [routing](../research/tidal-improvements/sketchybar-routing.md).
- Drag research ran15 focused tests successfully using fresh scratch caches.
  It did not reproduce a physical pointer drop, and no root cause is claimed.
  Native drag/edge-scroll evidence is a required completion gate.
- Read-only bar queries confirmed the installed wrapper and old app route. Fresh
  status probes returned valid JSON for the installed app and exit75 for the
  new test app. The source-backed artwork-identity validation hypothesis still
  needs deterministic reproduction; do not treat it as a completed fix.
- Suggested dimensions are review proposals, not measured proof of a new layout.
  Shared scrolling reuse was cross-checked against the compact player to avoid
  adding a second implementation. New code, live playlist mutation, installation
  and SketchyBar configuration changes were not performed in this research pass.

The next deliverable after review is an approved follow-up specification. A new
implementation session should receive that spec, these issues, the research
reports and the `/implement-spec` workflow. It should not infer approval from the
existence of these review-stage tickets.
