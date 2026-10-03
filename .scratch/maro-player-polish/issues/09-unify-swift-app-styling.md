# Make every Maro surface feel like part of the SketchyBar card

ID: 09
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: claimed
Assignee: original AFK coordinator
Blocked by: none

## Goal

Restyle all app-owned Maro Swift UI to match the existing player card and
SketchyBar, so opening search, playlists, or a dialog feels like continuing
inside the bar. Preserve playback, search, favorites, playlist behavior,
keyboard navigation, accessibility, and safe confirmation of destructive actions.

## User scope — 2026-10-02

The user requested a ticket covering styling throughout the current Swift app
and placement in the AFK queue. The desired experience is visual continuity:
moving from the card into another Maro surface should not feel like launching
a separate application. This authorizes comprehensive presentation changes,
including replacing mismatched app-owned window chrome and dialogs as needed;
it does not require a new app, playback engine, or navigation model.

Queue after issue 08, before acceptance-only reconciliation. This is an open,
unclaimed, unblocked implementation ticket, not a completed styling change.

## Reference and starting points

- Use the actual current `PlayerCard` in `Sources/MaroApp/PlayerWindow.swift`
  and the Maro integration in `integrations/sketchybar/` as the source of truth.
  Inspect the current code and rendered UI before choosing exact values.
- Supporting references: [installed native card](../assets/installed-native-player.jpeg)
  and [transport target](../assets/transport-target.png). Retain later card
  improvements, including issue 08's timeline, rather than reverting to an
  older screenshot.
- Current card: near-black background, subtle light border, rounded 12-point
  corners, restrained shadows, compact spacing, muted secondary text,
  pale-green accents, dark glyphs on the green transport capsule, rounded
  artwork, and small readable typography. Reuse those visual values across
  surfaces; use existing SketchyBar icon conventions where suitable.
- `SearchWindow.swift` currently presents a titled, resizable AppKit window
  with search controls, results, and a playlist tab. It is the principal visual
  break from the card and needs consistent framing and controls.
- `PlaylistLibrary.swift` owns the SwiftUI library and playlist detail views,
  account controls, credential import, create/rename flows, and delete
  confirmation. Include these app-owned surfaces in the styling audit.
- `MaroApp.swift` connects the card, search, and library. Preserve the accessory
  app lifecycle and shared controller; do not introduce a Dock app experience.

## Implementation scope

1. Audit every app-owned surface: Now Playing, Favorites, search and result
   rows, library and playlist detail, add-to-playlist, create/rename/delete,
   account/setup controls, and empty/loading/error/disconnected states.
2. Apply consistent backgrounds, typography, spacing, borders, corner radii,
   artwork, icons, tabs/navigation, input fields, buttons, and selection/focus/
   hover/disabled treatments. Reuse current code and native controls first;
   extract only the small shared styling actually needed, with no new dependency.
3. Make the search/library frame visually related to the anchored card.
   Preserve practical space for longer lists and editing; the search/library
   need not fit the card's fixed width. Keep the panel on the relevant display,
   within visible bounds, and visually near its SketchyBar entry point where
   practical. Opening/back/close transitions should feel coherent.
4. Keep text inputs fully focusable, Escape and existing shortcuts usable,
   scrolling and resizing practical, and VoiceOver names/values intact. Do not
   copy a nonactivating panel configuration blindly onto text-entry surfaces.
   Maintain readable contrast and visible focus/selection in both system
   appearance modes. Green is not the sole indicator of state or action.
5. Style app-owned dialogs consistently while retaining explicit labels,
   cancel paths, and safe destructive confirmations. System credential pickers
   and external Google authorization remain native/external; do not weaken
   security or embed a replacement browser merely to match the card.

## Acceptance and delivery

- Capture before/after visual evidence of the card, search/results, library,
  playlist detail, add/create/rename/delete flows, and representative loading,
  empty, error, and disconnected states. Use disposable data for UI fixtures;
  do not edit or delete real user playlists to obtain screenshots.
- Verify the transitions from SketchyBar/card to search and playlists and back,
  plus close/reopen/Escape, text entry, keyboard navigation, focus, scrolling,
  resizing, long titles, missing artwork, and accessible labels. Check relevant
  display placement and screen-edge behavior. Record what was inspected; a
  property dump alone does not establish the visual match.
- Reuse `scripts/check-player-card.swift`, the SketchyBar renderer check, and
  relevant existing app/library tests. Add the smallest runnable regression
  check only where changed interaction/window logic warrants it. Run the Swift
  suite and release build; preserve issue 08's timeline and existing transport,
  favorites, playlist, and IPC contracts.
- Build a verified standalone bundle using the existing packaging/signature
  checks. Install only when paused/idle and not selecting, with the established
  backup-preserving installer and fresh state comparison. If listening is
  active, leave the tested bundle ready and record the pending install.
- Do not start audible playback, restart the held listening test, expose
  credentials, or claim physical/manual acceptance from fixture evidence.
  Record remaining verification honestly; resolve only when required checks
  and delivery are complete.

## Ownership and AFK execution

Claim before implementation and use this Goal verbatim with `create_goal`, after
checking for an existing active goal. Preserve all shared uncommitted/untracked
work. The worker owns app presentation changes, necessary checks, and delivery
evidence; touch core playback only if a demonstrated presentation contract
requires it. Do not add feature scope such as shuffle, repeat, providers, or a
separate player. Follow the existing five-minute coordinator without competing
runs. On completion, append evidence under Answer and link the resolution in
the map; otherwise preserve the exact remaining work for the next AFK run.

## Answer

Current outcome (2026-10-03): implemented, installed and renderer-verified; final
user visual acceptance pending. Strict original before captures could not be
recovered: an isolated, uniquely identified rollback copy stayed idle/empty, but
supported CUA lookup timed out by path and ID. Stopped that copy; no installed
changes. Keep claimed rather than falsely resolving the evidence requirement.
The AFK loop is paused until visual feedback; no additional implementation or
repeated regression runs are justified without new information.

Claimed 2026-10-03. Issue 08 is installed and awaits physical user confirmation;
continue independent presentation work without closing that acceptance gate.
First slice: audit current surfaces and share the existing card palette with
search, preserving native input and selection behavior. Full visual/delivery
acceptance remains pending.

Foundation slice: shared the exact card palette with AppKit search, pinned its
appearance to dark like the card, applied green primary actions and rounded
artwork while retaining native table/input/button focus behavior. Debug build
passes; four app regression tests pass (0.040 s). Not packaged or installed.
Native create_goal was attempted after claiming but rejected because issue 08's
blocked goal is unfinished. Preserve that goal honestly; track independent
presentation work here until it can be created. Next: disposable visual fixtures
for search/library/dialogs, then remaining styling and window/input checks.

Library slice: card background, rounded lists/add area, compact text and empty
copy implemented. Seven disposable native states rendered via
`scripts/check-library-style.swift`, with no account/network/audio actions.
After images in `/private/tmp/maro-library-after`; inspected detail, empty, add
and disconnected. Baseline images have offscreen vibrancy artifacts, so visual
before/after acceptance is not complete. Four app tests pass; native interactive
focus/selection/accent still pending. Next: search and name/delete dialogs,
window placement, full verification and delivery. Installed app is unchanged.

Dialog slice: reused native alerts with card appearance and explicit safe Cancel
defaults. Factored constructors into `PlaylistDialogs` for silent inspection;
five app tests pass including editable name/focus and destructive default checks.
The fixture now renders ten states, but native alert PNGs have offscreen vibrancy
artifacts; they do not prove visual acceptance. Next: search/window placement
and supported on-screen dialog/input inspection. No real playlist changes or
installation occurred.

Search slice: relevant-display top anchoring and visible-bounds clamping added,
with existing resizing/text-entry semantics retained. Six app tests pass. New
injected-library search fixture renders four states and verifies programmatic
focus/cancel/reopen without real account/audio/network access. Native offscreen
chrome remains corrupted in PNGs; next run should use a persistent isolated
fixture with supported on-screen CUA inspection before visual acceptance.

Full regression: 94 tests pass (21.963 s). Interactive fixture mode added, but
the temporary app's registration/lookup failed in supported CUA; no on-screen
acceptance claimed. Exact fixture process stopped. Next: normal fixture app
lifecycle/registration, supported UI checks, then release/package and delivery.

Supported UI recovered with `check-style-ui.swift` (native delegate/run loop).
CUA screenshots inspected search/library/create/delete. Real keyboard typing and
Escape worked in the disposable name dialog; Return safely cancelled delete and
retained fixture detail. No real data or audio touched; fixture quit. Next refine
white-on-green AppKit labels and gray native dialog appearance, then remaining
input/window checks and delivery. This is partial evidence, not full acceptance.

Contrast refinement: dark native dialog surface and active primary titles now
observed via supported screenshots. Search typing/submit empty/results passed in
fixture. Inactive-window primary title remains too dark on gray and must be
fixed; settled-result Down navigation and reopen remain unverified. Fixture closed;
no installation or real playlist/audio changes.

Primary states now use per-button native appearance rather than a fixed title
color. Active contrast observed; inactive direct visual evidence remains pending.
Settled Down selects a row, and Escape/fixture Show Search reopens with field
focus and retained result. Release build log: `/private/tmp/maro-styling-release.log`.
Next: remaining scroll/resize/state/card checks and package/delivery.

Compact native fixture check passed: reveal 10, scroll, readable long-title rows
at 560×450, card/empty-Favorites/search transitions retaining results/scroll/focus.
Exposed metadata-only unavailable timeline drawn full despite partial elapsed;
presentation fallback needs correction before delivery. Candidate package path
`/private/tmp/maro-styling-candidate/Maro.app` (verify packaging log first).

Unavailable timeline discrepancy fixed with display-only metadata duration and
explicit SwiftUI disabled state. Seven app tests pass; supported UI shows disabled
position 90 and correct small fill for 01:30/1:00:00. No seeking behavior changed.
The earlier candidate is superseded; rebuild before delivery. Full regression log:
`/private/tmp/maro-styling-final-tests.log`.

Inactive contrast verified after activation-aware native appearance switch.
Supported error-state and rename screenshots inspected; cancel paths retained.
Earlier final bundle passed all dependency checks but predates this correction;
fresh build/package is `/private/tmp/maro-styling-v2/Maro.app` (verify logs before
delivery). Remaining representative states and safe installation are next.

Delivered: styling v2 installed 2026-10-03 after dependency/signature/release checks,
fresh paused/nonselecting guards and exact track/position/favorites/volume compare.
Supported installed Search screenshot confirms styling and focus. Add/detail/
disconnected/loading fixture screenshots inspected; no real playlist mutations.
Still claimed pending required card/SketchyBar renderer checks and final evidence
audit, including unusable earlier before captures. Do not reinstall older bundles.

Required renderer checks completed: eleven current native card states plus
toggle/hide/reopen/Escape pass with zero preparations; offline SketchyBar checks
pass metadata/routing/events/displays/long titles. Current source is delivered.
Remaining audit: original before baseline can be inspected from an isolated copy
of the rollback bundle (fresh state, unique Keychain service, no real bar/audio).
Do not rerun passed checks or reinstall to obtain that evidence.
