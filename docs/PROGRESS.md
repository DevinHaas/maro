# Maro AFK progress

Updated: 2026-10-03 (Europe/Zurich).

## Current state

### Acceptance handoff; AFK loop paused — 2026-10-03

- All safely actionable implementation/delivery and required renderer checks are
  complete for the installed styling v2. No further source changes or regression
  reruns are justified without new feedback.
- Tried a read-only rollback baseline via a uniquely identified temporary copy,
  empty state, unused Keychain service and disabled bar notifications. Confirmed
  it stayed idle with no loaded video/favorites. Supported CUA lookup timed out
  both by exact path and unique bundle ID; no usable before screenshot obtained.
  Stopped the exact isolated process afterward. Original backup and installation
  are untouched. Do not bypass UI tooling or repeatedly retry this comparison.
- Issue 09 remains delivered/claimed pending user's visual acceptance because
  strict before/after evidence could not be completed. Current after views and
  interaction checks are observed; historical before PNGs are not reliable.
- Remaining user checks: review installed search/library/dialog styling; during
  the next deliberately started listening session pause a prepared track, drag
  and release the timeline, close/reopen and confirm chosen position/pause remain.
  The held 30-minute audible listening/playlist-navigation acceptance and real
  playlist follow-up verification remain unclaimed. No playback starts for testing.
- Pause only `maro-afk-implementation`; preserve coordinator and five-minute
  schedule for a later user resume. Native issue 08 goal stays blocked, not complete.

### Issue 09 required renderer checks passed — 2026-10-03

- Current native card renderer passes all eleven states and window toggle/hide/
  reopen/Escape with paused state unchanged and zero audio preparations. Log:
  `/private/tmp/maro-final-card-check.log`; images `/private/tmp/maro-final-card-evidence`.
- Offline SketchyBar renderer passes safe metadata/routing, stale-event handling,
  scoped legacy migration, notch/mixed-display/disconnection and long/Unicode
  title checks. No installed items changed by these checks.
- No more regression reruns are needed without another source change. Styling v2
  remains installed; do not reinstall. Outstanding evidence audit is the original
  before baseline, whose offscreen PNGs were corrupted. The install receipt retains
  the untouched pre-styling bundle at
  `/Users/devinhasler/Applications/Maro Local.backup-1c94bafc749c450792f24bfaab4fa534`.
  A safe next slice can copy that bundle to a uniquely identified temporary app,
  use fresh MARO_DATA_DIRECTORY, unique MARO_KEYCHAIN_SERVICE and
  MARO_SKETCHYBAR=/usr/bin/true, then inspect initial search/disconnected library
  without any source requests, real accounts or playback. Never run it against
  installed state or install it. Stop the isolated baseline process afterward.
- After reconciling that evidence, close only the styling acceptance supported
  by evidence and pause the loop for the remaining user-dependent timeline/listening
  gates. User-reported playlist success remains distinct from independent live tests.

### Issue 09 styling v2 installed — 2026-10-03

- Final representative supported screenshots: add-to-playlist (cancelled),
  playlist detail, disconnected account-free fixture, and loading feedback with
  disabled playback/add actions. Prior captures cover search/results/error/empty,
  create/rename/delete, card/Favorites, inactive and compact/scroll states.
- Styling v2 passed all four isolated dependency checks; log
  `/private/tmp/maro-styling-v2-dependencies.log`. Full source suite: 95 tests;
  final activation-only follow-up: seven app regressions. Release/signature pass.
- Installed `/private/tmp/maro-styling-v2/Maro.app` through `scripts/install.py`
  with rollback and module registration after two fresh paused/nonselecting checks.
  Exact latest loadedVideo (including position), favorites and volume=1 match.
  Fresh evidence `/private/tmp/maro-styling-v2-install-before.json` mode 0600.
  Installer deliberately defers for nondefault volume rather than losing it.
- Supported screenshot of installed initial Search confirms dark presentation,
  field focus and disabled selection actions. Hid it afterward. No audio started,
  real playlist changes, or unrelated SketchyBar edits.
- Remaining issue 09 acceptance bookkeeping/checks: rerun existing card renderer
  and SketchyBar renderer checks required by ticket, reconcile usable before/after
  evidence (old offscreen baseline was corrupted), and summarize precise remaining
  environment/manual gaps. Do not reinstall older packages. Issue 08 still awaits
  user physical drag confirmation; no source work or playback probes for that gate.

### Issue 09 inactive contrast verified and packaging advanced — 2026-10-03

- Direct inactive screenshot disproved the always-Aqua button approach: AppKit
  removed the pale background while retaining dark text. Replaced it with a tiny
  button-owned activation observer view; it switches native Aqua/darkAqua with
  key-window/app activity and leaves native drawing/actions/disabled states alone.
- Supported CUA now shows readable light labels on gray inactive buttons and
  dark text on green active Save. Inspected actual error state (message plus
  disabled actions) and rename dialog (preselected existing title, dark surface,
  visible focus); cancelled/quit. No real playlist or playback actions.
- `/private/tmp/maro-styling-final/Maro.app` passed release, signature and all four
  dependency checks, but predates this last contrast correction. Rebuilding fresh
  `/private/tmp/maro-styling-v2/Maro.app`; logs `maro-activation-tests.log`,
  `maro-styling-v2-release.log`, `maro-styling-v2-package.log` under `/private/tmp`.
  All seven app tests pass (0.172 s), release passes (5.39 s), v2 packaging and
  deep strict signature pass. Never install the superseded candidates.
- Next: last representative loading/add/detail/disconnected evidence, current
  bundle dependency verification and safe install with fresh paused-state checks.
  Timeline physical-drag confirmation remains a separate user gate.

### Issue 09 unavailable timeline corrected — 2026-10-03

- Added a display-only validated metadata duration fallback to the native slider.
  Without prepared ranges it now shows actual elapsed fraction, or zero when
  duration is unknown/invalid, while remaining noninteractive. Explicit SwiftUI
  disabled state prevents the representable environment from re-enabling it.
  Controller seeking/identity/range contracts are unchanged.
- Seven app tests pass (0.180 s), including new metadata/unknown/nonfinite cases
  and zero commits when disabled. Supported CUA observes disabled position 90,
  Seeking unavailable, and a small muted fill for 01:30/1:00:00 instead of a full
  bar. Screenshot inspected. Closed fixture; installed player untouched.
- Full regression passes: 95 tests in 21.747 s; log `/private/tmp/maro-styling-final-tests.log`. Previous
  signed candidate is now superseded by this presentation fix: do not install it.
  Next: remaining inactive/dialog/state visual checks, rebuild release and a fresh
  signed bundle, dependency checks, then safe installation.

### Issue 09 compact lists and card transitions — 2026-10-03

- Extended the silent native fixture with 20 metadata results, loading/error
  queries, a compact-window command and the real PlayerWindow wired to the same
  disposable controller. No source can prepare audio; no account is loaded.
- Supported CUA: Load 5 more revealed 10; compact 560×450 frame retained readable
  controls. Scroll moved from 0 to 0.493 and visibly showed rows 4–7. Long titles
  truncate while creator/duration remain visible. Search → card → Favorites
  (empty) → Search retained results, scroll and restored field focus. Screenshots
  inspected for compact list, card and Favorites. Closed fixture normally.
- Existing metadata-only card timeline is drawn full while unavailable despite
  elapsed 01:30/1:00:00. This is a presentation discrepancy exposed by the fixture;
  inspect/fix that fallback without enabling seeking or changing controller logic.
- Standalone candidate packaging and deep strict signature check passed at
  `/private/tmp/maro-styling-candidate/Maro.app`; log `/private/tmp/maro-styling-package.log`.
  Do not install until remaining
  checks pass: unavailable timeline visual, inactive primary screenshot, remaining
  on-screen dialog/state checks, package dependency verification. Installed player
  untouched; no real playlist changes or audio.

### Issue 09 native button states and search reopening — 2026-10-03

- Replaced fixed attributed primary titles with native Aqua appearance scoped
  only to pale-green AppKit buttons. AppKit now owns active/inactive/disabled
  text treatment; the surrounding window/dialog stays dark. Avoided custom cells
  or observers that could disturb native control behavior. Fixture compiles.
- Supported screenshot confirms active dark-on-green Search/Play labels. Settled
  Down key selected the result row; Escape followed by the fixture's Show Search
  shortcut reopened with search field focused and the result retained. No Return
  on a result or playback action was performed. Closed the fixture normally.
- Inactive appearance still needs a direct screenshot; native-state styling is
  not evidence by itself. Remaining: scrolling/resizing, remaining fixture states
  and card transitions, final packaging/installation. Release build passed in
  3.70 s; log `/private/tmp/maro-styling-release.log`. Not packaged or installed.

### Issue 09 primary contrast and dialog surfaces — 2026-10-03

- Shared primary AppKit styling now uses an attributed dark title (native
  contentTintColor did not affect text). Native alerts keep their controls and
  modal semantics but apply the card background after layout to the content layer.
- Supported CUA screenshots confirm the create dialog is now near-black with
  readable dark Save text on green; active Search likewise has dark text on green.
  Typed `empty` and submitted: correct empty message and disabled playback/add
  actions appeared. Replaced with `piano`: result and actions returned, no playback.
- Inactive-window screenshot exposed dark titles against AppKit's gray inactive
  button background; refine inactive label color before delivery. Keyboard Down
  immediately after asynchronous search still showed field focus; retry after
  result settles before diagnosing a real navigation issue. Escape hid the
  window, but the following hidden-window CUA lookup timed out, so that command
  chain does not prove reopen. Stopped only the disposable fixture afterward.
- App regressions rerun in `/private/tmp/maro-contrast-tests.log`. Next: inactive
  title treatment, settled-result keyboard/scroll/resize checks, remaining views,
  release/package. No installed app changes or real playlist/audio activity.

### Issue 09 supported UI verification recovered — 2026-10-03

- Added `scripts/check-style-ui.swift` using an NSApplication delegate/run loop
  and launched `/private/tmp/MaroStyleFixture.app` normally. Supported CUA now
  recognizes it. All transport is in-memory; fixture writes reject and audio
  preparation fails safely. Added controller render callback matching the real app.
- Observed actual screenshots of search, library, create and delete confirmation.
  Search/library use the dark card palette; titles and missing-art result are
  readable. Actual create dialog text entry worked and Escape cancelled back to
  the library. Opened fixture detail/delete; Return chose Cancel and returned to
  the unchanged detail. No real playlist mutations or playback.
- Visual refinements remain: AppKit green primary buttons show white labels
  despite contentTintColor; native dialogs render gray rather than card-black.
  Preserve working native focus and safe Cancel while addressing these. Screenshots
  are in this coordinator's CUA tool evidence; offscreen PNGs remain unreliable.
- Closed the fixture with its Quit shortcut. Next: contrast/dialog refinement,
  remaining search keyboard/scroll/resize/transition checks, then release/package.
  Existing full 94-test pass remains valid for production code (this slice changes
  only the fixture). Installed Maro remains unchanged.

### Issue 09 full regression and persistent fixture attempt — 2026-10-03

- Full Swift suite passes: 94 tests in 21.963 s, including timeline, source,
  playlist and new dialog/placement checks. Log:
  `/private/tmp/maro-styling-full-tests.log`.
- Added optional ten-minute interactive mode to the isolated search fixture and
  packaged it locally as `/private/tmp/MaroStyleFixture.app`. It still injects
  all dependencies and cannot play audio or call real playlists.
- Supported CUA inspection failed: initial application lookup timed out; sandbox
  launch aborted in macOS `_RegisterApplication`. Read only this fixture's crash
  reason with normal tool approval after context-mode's external-file restriction.
  Approved unsandboxed fixture launch remained running but CUA returned
  `procNotFound`; no visual/input acceptance obtained. Stopped only the exact
  disposable fixture process afterward. Installed Maro was untouched.
- Next: make the fixture launch through normal app lifecycle/registration and
  inspect it with supported CUA (do not bypass UI/security checks). Keep safe
  release/package work independent if UI tooling remains unavailable. Remaining
  gates are unchanged: on-screen styling/inputs, transitions, package/delivery,
  and the separate user-dependent timeline drag confirmation.

### Issue 09 search placement and isolated fixture — 2026-10-03

- Search now reopens near its invocation point below the bar on the pointer's
  display, clamps its frame inside that display's visible bounds, and preserves
  resized dimensions when they fit. Already-visible windows retain placement.
  Kept a titled/resizable activating panel for reliable native text entry.
- Added an optional injected playlist-library dependency and a wholly isolated
  `scripts/check-search-style.swift`. Four states (initial/results/empty/error)
  render with no Keychain, network, real playlists or audio. Opening assigns
  the text field editor as first responder; cancel hides and reopening works.
  These are programmatic checks, not physical typing/keyboard acceptance.
- Six app tests pass (0.164 s), including primary/negative-origin/small-display
  and left/center/right placement cases: `/private/tmp/maro-search-style-tests.log`.
  Fixture log: `/private/tmp/maro-search-fixture.log`.
- Inspected results PNG in `/private/tmp/maro-search-after`: row title, creator,
  duration, missing-art placeholder and selection are readable, but native tabs,
  controls and chrome have the known offscreen white/vibrancy artifact. No visual
  match claim from this export. Next: package a persistent isolated UI fixture
  and inspect through supported CUA screenshots, including dialogs, typing,
  keyboard/scroll/resize and transitions. Then final styling refinements and
  full build/package/delivery. Installed player remains unchanged and silent.

### Issue 09 native playlist dialogs — 2026-10-03

- Extracted construction of the existing name/delete NSAlerts into
  `PlaylistDialogs`, reused by the real flows and the silent visual fixture.
  Dialogs use the card's dark appearance/background; name entry retains initial
  focus and Save/Cancel. Delete remains warning-styled with explicit consequence
  text, Cancel first/default/focused, and no Return shortcut on Delete.
- Added a focused regression for cancellation defaults, warning text, editable
  accessible names, preserved initial value/focus and appearance. All five app
  tests pass (0.124 s), `/private/tmp/maro-dialog-tests.log`.
- Expanded the disposable fixture to construct create/rename/delete without
  entering a modal loop or invoking actions. All ten states render, but inspected
  native-alert PNGs have white/vibrancy artifacts (as earlier baseline captures).
  These are NOT visual acceptance; use supported on-screen fixture inspection
  before claiming dialog appearance. Evidence: `/private/tmp/maro-library-dialogs-after`.
- Next: search fixture and window placement/input work; on-screen native dialog
  inspection remains pending. No real playlist calls, audio or installation.

### Issue 09 library surfaces and silent visual fixture — 2026-10-03

- Added `scripts/check-library-style.swift`: seven real SwiftUI library states
  using disposable controller data and an injected API that rejects every request.
  It never loads an account or prepares audio. Rendered disconnected, empty,
  library, detail, add, loading and error at 620×500.
- Applied the card's near-black background, compact typography, section icon,
  rounded list surfaces, bordered add-to-playlist area and helpful empty copy.
  Native list selection, scrolling, buttons and their actions remain intact.
- Compiled the fixture and inspected detail, empty, add and disconnected PNGs in
  `/private/tmp/maro-library-after`. Text and controls fit; native selection/focus
  and active-window accent appearance still require supported interactive checks.
  `/private/tmp/maro-library-before` was captured first but has offscreen vibrancy
  artifacts (white controls/text); it is not sufficient baseline visual evidence.
- Four app regression tests pass (0.039 s), log
  `/private/tmp/maro-library-styling-tests.log`; final presentation-only modifier
  adjustment was recompiled and all seven fixture renders succeeded afterward.
  No installation, real playlist mutations or audio playback.
- Next: search and app-owned name/delete dialog fixtures/styling; then window
  placement, full interactive acceptance and packaging. Native goal 08 remains
  blocked only on the separate user drag check; do not retry goal creation.

### Issue 09 presentation foundation — 2026-10-03

- Claimed issue 09 and continued independent styling while installed timeline
  physical acceptance awaits the user. The native goal tool refuses a second
  goal while 08 is unfinished; no false completion or repeated retry is needed.
- Shared current card colors with search, added matching dark appearance,
  primary green native buttons and rounded result artwork. Search/controller,
  keyboard actions, timeline and playlist logic are unchanged.
- Debug build passes (2.40 s); all four MaroAppTests pass (0.040 s).
  Logs: `/private/tmp/maro-styling-foundation-build.log` and
  `/private/tmp/maro-styling-foundation-tests.log`. Not installed; no audio started.
- Next: capture disposable search/library/dialog before/after fixtures and finish
  issue 09's full styling, placement, focus and accessibility checks. Current
  installed build remains timeline-final. Updated the existing heartbeat to
  remove obsolete install instructions and retain this actionable styling queue.

### Timeline acceptance blocked on physical confirmation — 2026-10-03

- Revalidated final delivery and remaining gate. Coordinate-based physical drag
  has remained unavailable across repeated goal turns; user confirmation is still
  pending. Unit/component/media checks cannot prove installed dragging. No further
  automated reruns or source changes are justified for this gate alone.
- Mark native timeline goal blocked (not complete). To unblock: during the user's
  next listening session, pause a prepared track, drag to a different timestamp,
  release, and confirm it reaches that position and stays paused. Close/reopen the
  popup and confirm that position remains. Do not start audio on the user's behalf.
- Issue 09 remains queued; do not confuse blocked timeline acceptance with full
  project completion or repeat installation of older packages.

### Final timeline build installed — 2026-10-03

- Final source (92 passing tests) built in release and packaged at
  `/private/tmp/maro-timeline-final/Maro.app`. Deep strict signature and all four
  isolated missing-dependency checks pass. Installed through backup-preserving
  installer after fresh paused/nonselecting checks; exact latest loadedVideo,
  position, favorites and volume match. No audio started. Evidence snapshot:
  `/private/tmp/maro-timeline-final-install-before.json`, mode 0600.
- Opened installed popup through CLI and inspected it using supported CUA:
  Play shown, existing elapsed/duration retained, timeline says Seeking unavailable
  because restart restored metadata without preparing audio. This is expected;
  do not start audio merely to enable it. User drag confirmation remains pending.
- Automated timeout/supersession, latest-target/pause/persistence, duplicate
  occurrence, failure/replacement/shutdown and drag-state lifecycle checks are
  recorded above/below. Real progressive and long-HLS seeks passed paused/muted.
  Remaining acceptance is physical drag/release and installed ready-track seeking;
  do not equate component tests with those checks. Goal remains incomplete.

### Deterministic timeline lifecycle checks — 2026-10-03

- Internal seek deadline defaults to the same 10 s bound but accepts a deadline
  for verification. Expired-seek and overlapping-seek checks pass: timeout and
  supersession retain the same reusable paused item, and the newer target wins.
- Extracted existing slider begin/end gesture bodies without changing behavior.
  Direct lifecycle check passes: preview only while dragging, progress ticks
  preserve draft, release commits once, identity/hide/unavailable changes cancel.
  These are deterministic component checks, not physical-drag acceptance.
- Focused results: timeout/supersession 0.060 s; drag lifecycle 0.024 s. Full
  suite passed all 92 tests in 21.967 s; log
  `/private/tmp/maro-timeline-complete-suite.log`.
- Source contains these verification-oriented refactors beyond installed v2.
  After full suite, rebuild/package and deliver only paused; physical user check
  remains pending. Goal stays active; no installed playback touched this slice.

### Timeline cancellation evidence — 2026-10-03

- Added a silent-media regression with failure, replacement and shutdown cases.
  All three pass (0.320 s): no late seek target/state persists; failure keeps the
  item available and does not re-extract; old player events cannot affect the
  replacement; shutdown retains saved paused position. Only tests changed.
- Current supported CUA observations show the slider and accessible elapsed
  value, but coordinate drag/click returned windowNotFoundAtPosition or no change.
  Do not infer drag acceptance from AX click/keyboard success. Asked user for a
  paused loaded-track drag check; no automatic resume or installed-player change.
- Remaining: deterministic timeout/coalescing detail and mid-drag lifecycle gates,
  user/physical drag evidence. Full suite after added cancellation test passed
  all 90 tests (21.990 s); log `/private/tmp/maro-timeline-cancellation-suite.log`. Installed
  v2 remains current. Goal remains active; this is progress, not a blocker-only turn.

### Timeline delivered with exact paused-state preservation — 2026-10-03

- Rebuilt package `/private/tmp/maro-timeline-delivery-v2/Maro.app` passed deep
  strict signature verification and all four isolated missing-dependency checks
  (node, extractor, Python, worker). Keychain isolation resolved the fixture stall.
- Supported native UI click focused the updated slider; two Right presses changed
  150 to 160 seconds with matching visible and accessibility values. Drag remains
  unverified; the latest screenshot was blank, so no coordinate claim is made.
- Installed with the backup-preserving installer after two fresh paused/nonselecting
  checks. Compared exact latest loadedVideo (including position), favorites and
  volume before/after; all matched, playback paused. Prior snapshot retained in
  `/private/tmp/maro-timeline-install-before.json` (mode 0600). Module registered.
  Do not reinstall earlier packages. No audible playback or live playlist edit.
- Issue 08 remains claimed: drag/release, cancellation during drag, remaining
  failure/race acceptance and installed interactive seeking still need evidence.
  Newly restored playback has no ready media item until user resumes; do not
  automatically resume to enable seeking. Continue safe isolated verification.

### Package timeout diagnosed; native click observed — 2026-10-03

- Repeated dependency harness now passed missing-node, then stalled on the next
  fixture. Stack `/private/tmp/maro-dependency-9215.sample` identifies synchronous
  real-account Keychain access during PlaylistLibrary startup. Added explicit
  MARO_KEYCHAIN_SERVICE override (normal default unchanged); harness uses a unique
  test service so disposable signed copies never request real-account credentials.
  Rebuild/repackage and rerun dependency gate still required.
- Added `scripts/check-timeline-ui.swift`, a silent interactive real-card fixture
  with no controller/account/network. Supported sky click on timeline changed AX
  position and visible elapsed time from 60 s to 150 s. Drag attempts yielded no
  change and are NOT acceptance. A focus check showed window focus; slider now
  explicitly accepts first responder when enabled and focuses on mouse down.
  Focus assertions added. Fixture rebuilt but its currently running process is
  still the older binary; reload only this fixture before verifying arrows.
- Fixture app `/private/tmp/MaroTimelineFixture.app`, bundle ID
  `local.maro.timeline-fixture`. Existing native goal remains active. Next: reload
  fixture, finish physical input checks, rebuild final package with latest fixes,
  rerun isolated dependency gate, then safe install preserving latest volume/state.

### Timeline occurrence identity and remote coverage — 2026-10-02

- Fixed stale drafts across duplicate-video playlist entries: snapshots now carry
  a selection-scoped timeline identity, independently of the reused engine item.
  Old occurrence commits are rejected. Added a regression assertion.
- Exposed the latest pending seek target so keyboard increments build on pending
  position instead of being reset by controller snapshots during an in-flight seek.
- Focused tests pass; full suite after both fixes passes all 89 tests (21.504 s).
  Log `/private/tmp/maro-timeline-final-regression.log`. Release build succeeds.
- Short progressive probe jNQXAC9IVRw passes: target 19.0396 / actual 19.0383 s,
  then target/actual 5 s; each ~0.027 s, paused and muted. Alongside the prior HLS
  forward/back probe this establishes actual remote seek results for both formats.
- Supported node_repl + @oai/sky tools are now available; skill read and import
  succeeds. Next: safe isolated native input checks, finish package verification,
  and install only under the existing latest-state/volume preservation policy.
- Standalone package created at `/private/tmp/maro-timeline-delivery/Maro.app`;
  deep strict signature verification passed. Dependency-failure harness timed
  out waiting 5 s for the disposable node-missing app's status socket; this gate
  is not passed. Log `/private/tmp/maro-timeline-dependencies.log`. Diagnose
  harness startup before installation. Installed app remains unchanged.

### Awake retry clears regression gate — 2026-10-02

- User reported closing the laptop and requested a retry. Full suite rerun with
  required socket permissions passed: all 89 tests, 21.379 s, including rapid
  resume, latest seek target/persistence and navigation. No production change
  was needed for those failures. Log `/private/tmp/maro-timeline-retry.log`.
- Found and fixed a separate probe setup error: bundled extractor filename is
  `yt-dlp_macos`, not `yt-dlp`. The earlier extraction failure was probe setup,
  not evidence of a YouTube outage.
- Corrected remote HLS probe passed on c3suauAz0zQ: 1260 s target/actual in
  0.555 s, then 30 s target/actual in 0.183 s. Disposable engine remained paused
  and muted throughout; installed player untouched. This does not establish
  physical input or sustained audible listening acceptance.
- Short progressive attempts remain unverified: BaW_jenozKc returned extractor
  failure; dQw4w9WgXc returned SourceFailure before a seek result. Do not count
  these as passes. Next: identify a resolvable short progressive candidate and
  retain safe diagnostics, finish remaining input/race gates, package/install.

### Broader regression exposed failures — 2026-10-02

- Approved suite excluding the previously stalled rapid-resume test completed:
  88 tests, 3 issues (83.902 s). New latest-target test ended at 0.2 instead of
  0.7 and failed saved-position assertion; existing navigation test reported
  audio preparation timeout. Focused green results do not establish full-suite
  stability. Log: `/private/tmp/maro-timeline-suite.log`. Investigate actual
  media timing/failures before packaging; do not label these environment-only.
- Added opt-in `scripts/check-timeline-media.swift`: disposable engine committed
  paused, verifies muted state throughout forward/back seeks, prints only target,
  actual position and latency. Long HLS invocation failed during extraction;
  no playback started. Added safe extractor diagnostic message for next attempt.
- Next: diagnose failures with isolated tests and safe remote extractor diagnostics;
  complete missing cancellation/failure/UI tracking gates, then package/install.

### Timeline edge and native-render checks — 2026-10-02

- Five focused tests passed (1.752 s), now including seeking backward from ended
  while remaining paused, resuming at the chosen position, paused seek-to-end
  retaining the playlist occurrence, and playing seek-to-end advancing exactly
  once across duplicate-video occurrences.
- Updated the existing native card renderer to include the new slider source and
  ready-item fixture timelines. Eleven states rendered without actions/audio;
  toggle/hide/reopen/Escape fixture passed. Inspected paused.png: title, timeline,
  elapsed/duration, transport and library/favorites fit the 430×193 card. Evidence:
  `/private/tmp/maro-timeline-card-evidence/`. This is rendered-fixture evidence,
  not physical mouse/VoiceOver or installed acceptance.
- Full suite initially hit restricted socket access. Approved unrestricted run
  passed those tests but stalled; sampled helper PID 80492 showed the main thread
  blocked inside AVPlayerItem.currentTime during the existing rapid pause/resume
  test. Buffered output misleadingly ended at command recovery. Stopped only
  test helper/runner. Evidence `/private/tmp/maro-test-stall.sample`; full suite
  remains unverified. Next: isolate that test and rerun remaining suite, then
  media probes/package/delivery and outstanding interaction gates.

### Native timeline control wired — 2026-10-02

- Replaced the display-only progress bar with a native NSSlider, matching green
  track and thumb, 18-point hit area, local drag preview and release-only commit.
  Arrow keys and accessibility increment/decrement commit five-second steps.
  Actual seekable ranges enable the control; restored metadata alone does not.
- Popup hiding increments a presentation epoch. Identity/epoch/range invalidation
  cancels an unfinished drag; native tracking prevents periodic position updates
  from moving the draft thumb. This behavior still needs physical UI verification.
- App and tests compile. Three focused timeline checks pass, including native
  accessibility label/actions, keyboard action and disabled control, plus range
  handling and controller persistence. No installed player or live playlists changed.
- Remaining: physical tracking/close/reopen and rendering evidence, broader
  controller race/failure/playlist coverage, muted progressive/HLS probes, full
  regression/package checks and safe installation. Issue 08 remains claimed.

### Timeline controller implementation — 2026-10-02

- Added item-identity-scoped seek commits, one in-flight operation plus newest
  pending target, latest play/pause intent, actual-position persistence and
  suppression of position/end callbacks during seeks. Replacement, shutdown and
  source disable cancel pending work. Seek failures preserve the item and queue;
  media failures during a seek pause with a concise error instead of auto-skipping.
- Snapshots expose live seekable ranges and player identity; duration/range/status
  changes trigger refresh. Confirmed seeks to the real end use the existing end
  path, guarded against duplicate end delivery. Replay resets that guard.
- Three focused tests passed: new silent-audio seek test verifies newest target,
  pause, unchanged player/preparation count, stale identity rejection and saved
  position; existing reuse and ended/replay regressions pass. Earlier range and
  engine preparation regressions also passed. No installed player was changed.
- Still pending: native timeline control, broader race/failure/playlist tests,
  muted progressive/HLS probes, packaging and safe delivery. Goal stays active.

### Timeline range foundation — 2026-10-02

- Added an engine timeline derived from the ready item's actual duration and
  seekable ranges. Invalid/empty ranges disable seeking; out-of-range targets
  clamp to reachable boundaries and gaps use the nearest boundary (earlier on ties).
- Superseded engine seeks now exit explicitly without marking the reused item
  unhealthy. Existing cancellation cleanup remains generation guarded.
- Debug app, CLI and tests compiled; focused timeline test passed (1 test),
  covering empty/invalid ranges, clipping, gaps, endpoint clamping and nonfinite
  input. No installed player interaction, audio or playlist write occurred.
- Next: controller seek coalescing/intent and stale-event handling, then native
  timeline interaction. Controller, UI, muted media probes and delivery gates
  remain open; issue 08 and its native goal remain active. Issue 09 follows.

### Playlist fix installed; timeline claimed — 2026-10-02

- Installed `/private/tmp/maro-playlist-item-fixes/Maro.app` after two fresh
  paused/non-selecting checks. Exact latest track/position/favorites preserved;
  no audio started and no playlist mutated. Updated module registered.
- Volume preservation check FAILED: restored volume is 1.0. Investigation shows
  volume is session-only (`engine.volume`); state.json contains no volume. The
  pre-restart value was not retained after the check process exited, so its exact
  value cannot be restored honestly. Do not claim full state preservation. Player
  stays paused; user notified of volume reset. Future installation checks must
  retain the pre-stop volume outside the subprocess and restore via existing CLI
  before reporting success or any user-started playback.
- Claimed timeline ticket 08; no existing native goal was active. Continue its
  complete bounded-seek/range/transport/UI checks, then issue 09. Do not pause the
  heartbeat for acceptance-only work while these implementation tickets remain.


### Playlist occurrence removal and duplicate prevention — 2026-10-02

- User confirms playlist creation and deletion work well. New reported gap: a
  removed video remains visible until manual refresh. Reused the confirmed-write
  reconciliation path to remove the exact occurrence immediately and after a
  lagging refresh; failed DELETE preserves all entries, including duplicates.
- Add now checks all destination playlist pages by YouTube resource video ID,
  including entries with missing display metadata. Existing IDs receive an
  already-in-playlist message; different IDs with the same title remain allowed.
  Simultaneous same-video additions within the API instance are rejected. This
  check is not an atomic lock against independent edits made on YouTube itself.
- Three focused tests passed (0.014 s), including both deletion success/failure
  cases, stale responses, duplicate occurrences, a duplicate on a later page,
  and same-title/different-ID addition. No real playlist was mutated in testing.
- Release built and signed package prepared at
  `/private/tmp/maro-playlist-item-fixes/Maro.app`. Installed app was playing,
  not selecting; no process stopped or installation attempted. Install when
  paused, preserving current track/position/favorites/volume and rollback.
- Resumed the existing Maro heartbeat with that exact pending-install handoff;
  API confirmed ACTIVE. It waits quietly during listening, installs only while
  paused/non-selecting, then reports and pauses if only manual checks remain.


- Project root is `/Users/devinhasler/projects/maro`; separate research worktree is
  under `/Users/devinhasler/worktrees/maro`. Original design artifacts are preserved
  in `docs/original-design/`. HumanLayer paths are no longer runtime dependencies.
- Native player, search, favorites, popup and manual search-result navigation are
  implemented. The later authorized scope adds one personal YouTube account's own
  playlists, API edits and session-only playlist playback with automatic advance.
  This supersedes the original single-track/no-queue restriction for playlists.
- Playlist implementation and desktop OAuth setup are present; the user reports
  successful setup. Importing the client file and having a working Google grant
  are separate checks. Live cross-app playlist acceptance remains unverified.
- Native AFK heartbeat `maro-afk-implementation` resumed at the user's
  request on 2026-10-02, retaining its five-minute schedule and coordinator.
  This does not authorize starting audio or the interrupted listening run.
- Issues 01–07 in `.scratch/maro-player-polish/issues/` are resolved. The user's
  next priority is [08 — seek with the timeline](../.scratch/maro-player-polish/issues/08-seek-playback-timeline.md),
  researched by a delegated agent and now open, unclaimed and unblocked. Implement
  it before acceptance-only reconciliation. The recommended native slider previews
  locally and commits on release, preserving play/pause intent with bounded seeks.
  No seeking implementation or installation was performed during research.
- After issue 08, reconcile stale parent-ticket notes and remaining safe installed
  playlist/player acceptance. Distinguish user reports from independently observed
  two-way sync or listening evidence. Pause once only user-dependent checks remain;
  preserve unrelated playlists and the held listening test.

## Acceptance reconciliation — 2026-10-02

- Reconciled MARO-001 and MARO-002 with all seven resolved polish-map issues,
  including actual native-card renders/installed inspection and later playlist
  navigation scope. Preserved historical evidence instead of reopening completed
  implementation. Updated stale layout and latency statements in ACCEPTANCE.
- User playlist success remains explicitly user-reported. The uncertain prior
  verification-playlist creation has not been retried or claimed successful.
- This run has no callable computer-use/browser tools, so safe live dialog checks
  cannot be independently performed. No credentials read, playlists mutated,
  playback started, installation changed, or browser-policy bypass attempted.
- Only external-input/tool-dependent gates remain. Paused the Maro heartbeat;
  preserve its five-minute schedule and coordinator. Exact remaining creation,
  cancel/delete, cross-app sync and user-started listening steps are in ACCEPTANCE.
- Verification: reviewed resolved ticket evidence and all edited documentation;
  no runtime code changed, so no test rerun is required for this reconciliation.

## Playlist refresh and deletion follow-up — 2026-10-02

- User confirmed playlist operation works, then reported that creation required
  manual refresh and requested whole-playlist deletion.
- Creation now publishes the returned playlist immediately and reconciles it
  after the automatic reload, including lagging list responses. Requests bypass
  the local URL cache. New playlists appear first and become the add destination.
- Playlist details now offers Delete playlist with an explicit YouTube deletion
  confirmation. Successful deletion clears selection/destination and removes the
  row even if the immediate refresh lags; failed deletion retains the playlist.
- API and app-state regression tests passed (two tests, including success/failure
  parameter cases). Signed standalone package prepared at
  `/private/tmp/maro-playlist-refresh-delete/Maro.app`.
- Installed after the user stopped playback. Verified the installed executable
  matches the tested package; relaunch restored the same video paused at
  2079.206619243 seconds. Previous installation preserved at
  `/Users/devinhasler/Applications/Maro Local.backup-8bb57cbfdf474a3f8a6e6933e35fefc9`.
  No live playlist deletion was performed.

## Acceptance handoff refresh — 2026-10-02

- Replaced the stale M2/ACTIVE opening handoff with current migration and playlist
  scope. Updated the existing `maro-afk-implementation` prompt, retaining **PAUSED**,
  its five-minute schedule and original coordinator thread.
- Coordinator inspected native Maro UI: Playlists was selected, Ambience contained
  one Silent Fjord entry, and status was “Up to date with YouTube.” This establishes
  a connected live library read; test-playlist mutations require separate evidence.
- Added an explicit Previous-through-duplicate check to the existing playlist
  controller test. Four focused playlist/OAuth tests passed in 3.164 seconds,
  including next/previous, automatic advance, unavailable-item skip, stop at end,
  preparation cancellation and loopback state validation. Silent fixture evidence
  does not replace installed UI or live listening acceptance.
- Ordinary test launch encountered denied user module-cache access; reran through
  normal escalation with temporary caches and the relocation scratch path. No
  application change or broader suite rerun was needed after this test-only edit.
- Remaining live evidence is tracked in `ACCEPTANCE.md`. Do not restart audio or
  the stopped 30-minute listening monitor automatically.
- Live creation was attempted with private title `Maro verification 2026-10-02`;
  its outcome is unknown after the dialog closed and native inspection became
  unavailable. Refresh and inspect for that exact title before retrying. YouTube
  browser navigation was blocked by an unavailable administrator-policy check;
  do not bypass it. No live add/reorder/remove or reverse-refresh pass is claimed.

## Completed slice — M1

- `Package.swift`: Swift 6 package, macOS 13 minimum, MaroCore + test target.
- `Sources/MaroCore/PlayerState.swift`: validated stable metadata, loaded position,
  bounded/ordered favorites, ephemeral deduplicated search pagination.
- `Sources/MaroCore/StateStore.swift`: serialized atomic persistence, schema and
  size validation, unique preservation of unreadable state, surfaced recovery.
- `Tests/MaroCoreTests/StateTests.swift`: six tests covering capacity/no eviction,
  removal/order, pagination, untrusted metadata, round trip/permissions,
  corrupt/unsupported/oversized state preservation, duplicate persisted favorites.
- Initial tests found Foundation reports a missing state file as `fileNoSuchFile`
  on this host. Fixed the read boundary to handle both missing-file codes.
- Final test result: six tests passed, zero failures, 2026-09-30 15:54 Europe/Zurich.
- `git diff --check` passed; files remain uncommitted on the original feature branch.

### Reproducible restricted-environment test command

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/maro-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/maro-swift-module-cache \
  swift test --scratch-path /private/tmp/maro-swift-build \
  --cache-path /private/tmp/maro-swift-cache --disable-sandbox
```

The initial ordinary `swift test` could not write user-level compiler caches in
this tool sandbox. The command above keeps build caches in allowed temporary
paths; `--disable-sandbox` disables SwiftPM's nested manifest sandbox, not the
Codex host permission boundary. Two harmless user-cache warnings remain.

## Completed slice — M2 source decoding (16:04 Europe/Zurich)

- `Resources/extractor.json` records official yt-dlp 2026.08.19 macOS asset URL,
  size and GitHub release SHA-256. This is a metadata pin, not a downloaded or
  verified binary. [Release metadata](https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest).
- Existing `/opt/homebrew/bin/node` is v26.7.0. Upstream supports Node >=22 and the
  official macOS extractor bundles EJS scripts. Runtime bundling remains open;
  no remote component downloads are enabled. [EJS guide](https://github.com/yt-dlp/yt-dlp/wiki/EJS).
- `YouTubeSource.swift` builds literal argument arrays with config/plugins/remote
  components disabled, bounded query size, 20-result search, network retry limits,
  and an explicit Node path. Flags checked against the pinned upstream options.
- Decoder caps input at 8 MiB, normalizes/deduplicates search metadata, tolerates
  missing artwork, restricts thumbnail hosts, verifies selected video identity,
  rejects combined/DRM/non-AAC/non-HTTPS formats, and ranks compatible candidates.
- Media candidates are ephemeral non-Codable values. Only Google media CDN HTTPS
  URLs are accepted. Header context merges format overrides; only User-Agent and
  recognized benign browser defaults are supported. Required Cookie/Authorization/
  Referer context is rejected, not silently discarded. Anonymous-only first slice;
  no cookie forwarding has been implemented.
- Five focused fixture tests added. They caught CRLF being treated as one Swift
  grapheme; header control-character validation now checks Unicode scalars.
- All 11 tests pass, zero failures, 2026-09-30 16:04 Europe/Zurich.
- No external process is launched by this slice. JSON byte limits are implemented;
  bounded pipe capture, timeouts/cancellation, and stderr classification are next.

## Completed slice — M2 process execution (16:08 Europe/Zurich)

- `ExtractorProcess.swift` launches an executable directly using `posix_spawn`,
  with a separate process group for each invocation and a minimal environment.
- Explicit stdin/stdout/stderr actions and close-on-exec defaults prevent unrelated
  file descriptor inheritance. No shell or inherited runtime/proxy flags are used.
- A detached worker drains both nonblocking pipes with per-pass fairness, capped
  stdout/stderr, monotonic timeout, cancellation propagation, and typed failures.
- Timeout, cancellation, output overflow, and normal completion kill remaining
  group descendants and reap the direct child. Success returns both byte buffers
  and an exit code; errors do not expose raw diagnostic text or signed media URLs.
- Six process tests cover dual-pipe pressure, nonzero exit, stderr flood, timeout,
  cancellation, invalid/missing executable, and cleanup of a background descendant
  after its parent exits. Tests use local deterministic shell fixtures only.
- All 17 tests passed, zero failures, 2026-09-30 16:08 Europe/Zurich.
- Deliberate limit: one worker polls at 100 Hz. Suitable for the bounded extractor
  workload; reconsider DispatchSource only if sustained concurrency is needed.

## Completed slice — M2 adapter and live probe (16:15 Europe/Zurich)

- `YouTubeClient.swift` connects validated arguments, bounded process execution,
  and normalized JSON responses. Conservative error classification distinguishes
  access restrictions, unavailable video, network, runtime, explicit signature
  extraction failure, and unknown errors. User messages contain no raw diagnostics.
- `scripts/fetch-extractor.py` downloads only the manifest's pinned asset into
  `.build/tools/yt-dlp_macos`, enforces expected size/SHA-256 before atomic install,
  and reuses matching binaries. Download and checksum verification succeeded.
- Sandbox DNS initially blocked the download; normal escalated approval succeeded.
  The PyInstaller executable also cannot initialize its semaphore inside the tool
  sandbox. Live checks require the ordinary escalated execution route on this host.
- First actual client search returned 20 normalized videos. Resolution exposed the
  pinned extractor's standard Accept header, which was missing from the decoder's
  narrow allowed defaults. Added that exact value and its regression fixture.
- Second live check: 20 search results, 2 compatible audio-only candidates. The
  highest-bitrate candidate's AVURLAsset `isPlayable` load failed at the 30-second
  deadline. Whole live check lasted 46.278 seconds. Do not call M2 or playback done.
- All 19 deterministic tests passed in that same run; the one opt-in live test
  failed. The suite exits nonzero when a live check fails (no masked green result).
- Live test now prints only Foundation error domain/code for a future diagnosis;
  neither signed URLs nor raw NSError descriptions are logged. It never emits sound.

### Opt-in live check

Use the normal tool approval flow where network/native process access is restricted:

```sh
env MARO_LIVE_EXTRACTOR="$PWD/.build/tools/yt-dlp_macos" \
  CLANG_MODULE_CACHE_PATH=/private/tmp/maro-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/maro-swift-module-cache \
  swift test --scratch-path /private/tmp/maro-swift-build \
  --cache-path /private/tmp/maro-swift-cache --disable-sandbox \
  --filter liveAnonymousSearchAndAssetPreflight
```

## Completed slice — M2 diagnosis / M3 asset loader (16:21 Europe/Zurich)

- The live probe now checks at most 1024 media bytes using an ephemeral URLSession,
  a Range header and the candidate's User-Agent. It prints status/count only.
- Fresh highest-quality candidate: HTTP 206, 1024 bytes. AVFoundation then reached
  its 30-second cancellation deadline. Error -11878 is `AVErrorOperationCancelled`
  per the installed SDK, not evidence of a sandbox or unsupported-codec error.
- This establishes media access via URLSession; it does not establish AVFoundation
  network access or playback. No local proxy, downloads, or transcoding introduced.
- `AudioAssetLoader.swift` now provides reusable codec preflight, bounded asset
  loading, caller cancellation, and safe domain/code-only errors, without touching
  the current player. Player-item readiness is still a later commit gate.
- Three new tests validate silent local WAV loading/duration (passed in 7 ms),
  pre-cancelled loading, invalid timeout, and unsupported codec before networking.
  All 22 deterministic tests passed; the one live test was skipped in that run.
- A distinct probe of the second live candidate also got HTTP 206/1024 bytes but
  returned `incompatible` in 17.939 seconds total. At that moment static codec and
  asset rejection shared one case, so that result alone does not identify which
  rejected it. Split the static failure to `unsupportedCodec` afterward and added
  codec/bitrate-only diagnostics for the next justified live probe.
- Standalone local SDK checks report audio/mp4, AAC-LC (mp4a.40.2), and HE-AAC
  (mp4a.40.5) statically playable on this Mac. Do not generalize the current remote
  failure to all AAC or assume a format workaround is required.

## Completed slice — M3 native playback (16:26 Europe/Zurich)

- `PlaybackEngine.swift` prepares candidates in descending quality with a 30-second
  overall budget, checks AVPlayerItem readiness using a muted staging player, seeks
  before commit, and leaves the current player untouched on preparation failure.
- Preparation produces a one-use `PreparedPlayback`. Commit switches synchronously
  to the ready player, with explicit autoplay/paused behavior. Pause, resume,
  replay, stop, finite position validation, and seek deadlines are implemented.
- Replay tracks transport intent; a later pause/replacement cannot be undone by
  its delayed seek callback. Older seek cleanup cannot cancel a newer seek.
- Initial native test crashed when migrating a prepared item between AVPlayers.
  Fixed the shared ownership boundary by handing over the ready player itself;
  rationale is recorded in IMPLEMENTATION_PLAN. One player is audible at a time.
- Two native tests use the existing silent WAV fixture and cover paused restoration
  at 0.25 s, one-use commits, failed replacement preserving state, pause/resume/replay,
  invalid positions, missing selection, and expired preparation. No external audio
  or YouTube is required. The source/live acceptance gate remains open.
- Full suite: 24 deterministic tests passed, one opt-in live test skipped.

## Completed slice — M3 native events (16:30 Europe/Zurich)

- `PlaybackObservation.swift` owns native end/stall/failure notifications, item
  failure and transport KVO, plus half-second position callbacks. Its immutable
  ownership bag removes every observer when released. Errors expose only domain
  and code, never signed URLs or NSError userInfo.
- PlaybackEngine installs observations before playback, assigns a fresh playback
  identity on replacement, and rejects callbacks from older or stopped items.
  Queued position callbacks sample current time again to avoid pre-seek rollback;
  premature end and stale started callbacks are filtered against native state.
- Three checks exercise actual silent playback through completion, retained loaded
  identity, replay after end, stale callbacks, callback suppression after stop,
  and engine release without a callback-retention cycle. No YouTube involved.
- Full suite passed: 27 deterministic tests, one live test skipped. Native silent
  track completed and delivered end in about 1.05 seconds.

## Completed slice — M3 controller integration (16:38 Europe/Zurich)

- `MaroController.swift` is the main-actor authority for player snapshots, search
  state, loaded metadata/position, favorites, playback intent, and surfaced errors.
  Production wiring connects YouTubeClient, PlaybackEngine and StateStore; tests
  inject source/preparation closures while using real local native playback.
- Restored state is paused without resolving or loading media until explicit resume.
  Search and selection use separate identities and cancellation. Superseded results
  cannot commit. Pause during preparation produces a paused replacement.
- Fixed a test-discovered race where a delayed native started callback could mark
  a paused old track as playing during a failed replacement. New-selection autoplay
  intent no longer changes the paused old track's event handling.
- Favorites update immediately. Durable snapshots are queued in order, checkpoint
  position every five seconds, and flush on pause/end/replacement or explicit flush.
  Save failures remain visible while preserving in-memory changes; raw errors are
  not exposed. An unreadable-state warning is visible after restoration.
- Confirmed source drift blocks further requests for this controller session and
  preserves favorites/loaded metadata. **Build-version persistence of this latch is
  not implemented yet**; do not claim the until-update requirement is fully done.
- Six controller checks cover restoration, favorite/position persistence, failed
  replacement, stale search/selection, pending pause, save failures, source gating,
  and ordered queued saves. Full suite: 33 deterministic tests passed, live test
  skipped, approximately 1.09 seconds. No live playback claim.

## Completed slice — M3 shutdown and durable source gate (17:36 Europe/Zurich)

- Controller shutdown is idempotent: invalidate operation identities, cancel
  pending search/preparation, pause and capture position, remove engine callbacks,
  release playback, then await ordered persistence. Later commands cannot restart
  it, and delayed selection completions cannot commit after shutdown.
- StateDocument now has an optional `sourceDisabledBuild` field. Older schema-1
  files without the field still load; malformed build identities are rejected and
  preserved through the existing corrupt-state path.
- Confirmed source incompatibility persists the current build identity. Restoring
  the same build retains the source block; a different build clears it. Transient
  network or per-video errors do not write this gate. Packaging must pass an actual
  app/extractor build identity; the current default is explicitly a development ID.
- Tests prove the gate survives relaunch without another source request and that
  a new build permits a user-requested attempt. Shutdown tests release a deliberately
  late preparation and verify metadata/favorites remain saved and playback stopped.
- A native controller test observes actual silent track completion, retains the
  ended video, replays without a second source preparation, and saves the replay
  position during shutdown.
- Full suite passed: 35 deterministic tests and one skipped opt-in live test,
  approximately 1.10 seconds. Remote playback remains unverified.

### M3 access recovery — 2026-09-30 17:45 Zurich

- Native failure observations now distinguish HTTP 403/410 access rejection from
  generic playback failures using AVPlayerItem's error log. This is an access
  recovery signal, not proof that a signed URL expired. Unknown failures and stalls
  do not trigger extraction; platform failures without an HTTP status stay visible
  and require an explicit retry.
- The controller captures position and permits one automatic fresh resolution per
  explicit load. Recovery reuses bounded preparation and selection cancellation;
  pause remains authoritative and newer selections supersede it. A second access
  rejection or failed refresh stops with a visible error and retained metadata and
  favorites. Explicit resume can retry with a new descriptor.
- Added local native-audio checks for duplicate failures, saved position, pause
  during refresh, exhausted retry budget, explicit retry, newer selection, unknown
  failure classification, and failed-refresh metadata preservation.
- Full suite: 38 deterministic tests passed; one opt-in live test skipped (39
  discovered). These checks do not establish remote playback or real URL expiry.

### M4 command protocol — 2026-09-30 17:48 Zurich

- Added CommandProtocol.swift: version-1 Codable request/response envelopes with
  correlated bounded IDs, typed errors, authoritative status snapshots, and CLI
  argument parsing for status/search/toggle/replay/select/favorite toggle/remove.
  Requests carry only stable video IDs, never supplied stream URLs or metadata.
- Enforced one newline-delimited UTF-8 JSON frame, 4 KiB request and 1 MiB response
  limits, supported protocol/command values, command-specific payload validation,
  response-ID matching, valid stable metadata, and coherent success/error shape.
  Search opens the future panel; a query argument is deliberately not a CLI command.
- Three protocol tests cover all command forms, bad arguments/IDs, malformed JSON,
  missing/extra frames, oversized messages, unsupported versions/commands, quoted
  metadata, mismatched responses, and invalid success/error envelopes.
- Full suite passed: 41 deterministic tests, one skipped live test (42 discovered),
  approximately 1.10 seconds. No socket or executable is claimed by this slice.

### M4 bounded socket I/O — 2026-09-30 17:53 Zurich

- Added worker-only Darwin AF_UNIX I/O with nonblocking descriptors, close-on-exec,
  current-user peer credential checks, and SO_NOSIGPIPE. Reads enforce the protocol
  size limit before retaining more bytes; writes handle partial progress. Absolute
  monotonic deadlines and cancellation checks cover stalled readers/writers and
  interruptions without resetting the budget on each chunk.
- Four tests use real local socket pairs: fragmented request plus 300 KB response,
  peer credential/descriptor checks, oversized input, read/write timeout, extra
  frames, disconnect without process-killing signal, and task cancellation.
- Full suite passed: 45 deterministic tests and one skipped live test (46
  discovered), approximately 1.10 seconds. This verifies connected socket I/O;
  filesystem binding, stale-socket recovery, listener ownership, and app/CLI
  lifecycle are the next slice, not yet implemented.

### M4 filesystem listener — 2026-09-30 17:59 Zurich

- Added LocalSocketListener with private directory/socket checks (0700/0600),
  no-follow directory/lock handling, persistent exclusive startup lock, bounded
  nonblocking connect/accept, and current-user peer verification. Only a refused
  owned socket is reclaimed; a live listener without the lock is preserved too.
  Cleanup checks inode/device/type/owner before removing its socket and never
  unlinks the lock file. Workers retain descriptor ownership until completion.
- Three real filesystem socket tests verify command/response exchange, duplicate
  instance rejection, missing server, stale recovery, an uncoordinated live server,
  replacement-file preservation, symlink refusal, and unsafe directory modes.
- Host sandbox rejected filesystem bind with EPERM. Normal approved escalation
  ran temporary-directory tests successfully; socket pairs remain sandbox-safe.
  Future full-suite runs require that same normal escalation for these tests.
- First elevated full run exposed one intermittent existing playback assertion:
  pauseDuringPreparationWinsAndSupersededSelectionCannotCommit line 109 observed
  engine.isPlaying true after pause and release of an obsolete selection. A focused
  rerun passed (0.28s); a full rerun passed all 48 deterministic tests with one live
  skip (49 discovered, 1.51s). Do not treat the rerun as a root-cause fix: investigate
  native pause observation/intent timing next before claiming M3 fully reliable.

### Native pause timing investigation — 2026-09-30

- Reproduced the previous assertion with 20 concurrent native-audio cases: rate
  was zero immediately after pause, then nonzero while controller state remained
  paused. A second run showed delayed mute values too. This establishes delayed
  native observable state, not evidence of audible output from the silent fixture.
- PlaybackEngine now records the latest transport intent, requests mute on pause,
  and observes both native rate and mute changes to reapply mute/pause when delayed
  updates contradict that intent. Resume/replay and autoplay explicitly unmute.
  Observation callbacks retain playback identity guards and never change intent.
- Strengthened the existing superseded-selection regression with 20 repetitions:
  assert authoritative paused state, native rate convergence within 250 ms, muted
  state and stable position after another 50 ms. Repetitions are serialized to
  avoid flooding the shared native audio service. Raw isPlaying still reads rate;
  it was not changed to conceal delayed native values. Heavy concurrent stress also
  hit another instantaneous-rate assertion; no hard real-time pause guarantee is
  claimed while main-actor delivery is delayed. Actual listening remains required.
- Fixed the manually bound stale-socket test fixture to configure close-on-exec,
  preventing concurrent process tests from retaining its listener after close.
- Final approved full run passed 48 deterministic test declarations (including
  20 pause cases) and one skipped live test: 49 discovered, 4.52 seconds.

### M4 controller command dispatch — 2026-09-30

- MaroController.execute validates requests and dispatches status, panel opening,
  toggle, replay, select, and favorite changes through the authoritative controller.
  Responses correlate request IDs and carry snapshots or safe typed errors. Toggle
  uses transport intent, including pending preparation; Replay is valid at end.
- Select/favorite commands resolve IDs against owned favorites, visible search
  results, or loaded metadata. Unknown IDs return video_unavailable; this API does
  not accept invented caller metadata. The app must provide a real panel callback.
- Two tests exercise encoded responses, missing/unknown video, search callback,
  selection/toggle, invalid replay, favorites capacity/removal, source-update gate,
  and shutdown rejection without losing saved state.
- Parallel suite runs again exposed transient alreadyRunning results in socket
  cleanup fixtures despite close-on-exec. The previous attribution to descriptor
  inheritance is a hypothesis, not a confirmed root cause. The stale fixture now
  drains the earlier live probe. Production still refuses to unlink a potentially
  active server; no safety check was weakened to accommodate tests.
- Full sequential verification passed: 50 deterministic declarations (including
  20 pause cases), one live skip, 51 discovered, 7.99 seconds. Use the recorded Swift
  command with `--no-parallel` for native integration acceptance. Concurrent socket
  teardown flakiness remains a test/lifecycle investigation, not resolved evidence.

### M4 command client and CLI — 2026-09-30

- Added CommandClient.send with bounded connect/response deadlines, cancellation
  propagation to its detached I/O worker, peer checking, validated response IDs,
  and descriptor cleanup. Missing/refused connection is distinct from an unknown
  outcome after write begins. No automatic replay occurs after ambiguous delivery.
- Added the real `maroctl` executable: validated command arguments, optional absolute
  development socket path, JSON response output, safe diagnostics and nonzero exit
  codes. Launch Services recovery remains pending until the app target exists.
- Real socket tests cover typed server errors, wrong response ID, disconnect,
  stalled response, absence of an automatic second connection, missing service,
  and invalid timeout. Full sequential suite passed: 53 deterministic declarations
  plus one live skip (54 discovered), 8.33 seconds.
- Built executable smoke checks: `--help` exited 0; status against an intentionally
  absent temporary socket exited 69 with a clear service-unavailable message.
  README now describes the implemented CLI and remaining app/live gates.

### M4 running command service — 2026-09-30

- Added CommandService.run: detached socket accept loop, at most eight retained
  connection tasks, three-second read/write budgets, one request/response per
  connection, validated handler responses, and cancellation that awaits workers
  before releasing the listener. The app handler must propagate cancellation;
  existing controller/source operations already do so with bounded preparation.
- Invalid requests get correlated safe errors when their ID is recoverable.
  Handler failures or mismatched handler responses close the connection, preserving
  the client's unknown-outcome classification instead of claiming nonexecution.
- Real socket integration tests connect CommandClient through the service to
  MaroController for favorite/status commands and verify durable shutdown. Additional
  checks cover unsupported versions, a stalled peer alongside responsive clients,
  cancellation/socket cleanup, and an invalid post-execution response.
- Full sequential suite before the final handler-boundary refinement passed 55
  deterministic declarations plus one live skip (56 discovered), 8.46 seconds.
  After refinement, all three service tests passed, including the new invalid-handler
  regression. There are now 56 deterministic declarations plus the opt-in live test.

### M4 native companion lifecycle — 2026-09-30

- Added the real AppKit `Maro` accessory executable. It owns the controller/service,
  restores metadata paused, accepts CLI commands, and handles SIGTERM/SIGINT and
  normal app termination. Explicit absolute development overrides isolate data and
  extractor/runtime locations; packaged resource paths remain the default.
- Service lifecycle callbacks initialize state only after acquiring the exclusive
  listener lock and flush shutdown before releasing it. Duplicate instances cannot
  read/rewrite state while the original owns the service. The listener lifetime is
  explicitly extended across final flushing.
- Native smoke testing caught an AppKit deferred-termination hang: the main-actor
  cleanup task was not running in that loop. Shutdown now cancels that termination
  attempt, leaves the normal event loop running for async cleanup, then terminates
  immediately on a second request once stopped. Diagnostic probes were removed.
- `scripts/check-app-lifecycle.py` passed against built executables with temporary
  state: paused status at position 5, favorite add, duplicate-instance exit while
  original remains responsive, explicit unavailable search window, SIGTERM save and
  socket cleanup, relaunch paused with favorites intact, and final cleanup. No live
  source requests, real favorites, or SketchyBar configuration were involved.
- Full sequential Swift suite passed before the final app termination adjustment:
  56 deterministic declarations plus one live skip, 57 discovered, 8.54 seconds.
  Final app/core build and the native lifecycle smoke check passed afterward.
- Search UI and Launch Services recovery are still pending; the app responds with
  an explicit service_unavailable error for search instead of pretending to open it.

### M5 initial native search window — 2026-09-30

- Added SearchWindow with focused query input, explicit search submission, five-row
  result batches and local Load 5 more, title/creator/duration rows, keyboard Down/
  Return selection, Escape dismissal, accessibility labels, and progress/empty/
  source-update/failure messages. Search browsing uses the existing controller and
  does not issue transport commands. Failed selections mark the row unavailable.
- Selection prepares via the controller and waits for its actual playing state
  before hiding the window; a paused or failed selection leaves it open. Selection
  generation checks prevent obsolete completion from closing a newer operation.
- The app now routes search commands to this window and renders controller changes.
  Native build and the updated isolated lifecycle smoke script passed, including
  successful search command, duplicate-instance safety, shutdown and paused restore.
- Started a separate temporary fixture-only app for UI inspection. Computer-use
  get_app_state("Maro") returned Invalid app, and list_apps contained no Maro entry:
  the raw executable lacks a registered bundle identity. No keyboard/visual result
  is claimed. The exact fixture process was terminated afterward; no live source
  requests or user state were touched. Prepare a development app bundle for the
  next UI inspection rather than working around computer-use access.
- Thumbnail slots currently use a native placeholder; bounded artwork/cache work
  and real visual/keyboard acceptance remain. M5 is not complete.

### M5 development bundle and UI inspection — 2026-10-01

- Added bundle-development-app.py: creates a fresh .app with a development bundle
  identity, native app and CLI, ad-hoc signing and strict signature verification.
  Existing outputs are never replaced. This is not a self-contained release;
  extractor/runtime bundling, hardened signing and distribution are still M7 gates.
- Computer-use now identifies the bundled app. Native accessibility and screenshot
  checks with seven local fixture videos verified initial search focus, Return
  submission, first five results, Load 5 more revealing seven, keyboard selection,
  unavailable row state with the panel remaining open, and Escape dismissal.
- Inspection caught a real UI defect: reloading the failed row cleared selection,
  hiding the error and disabling Play selection. Preserve the selected video ID
  across that reload. Rebuilt/rebundled; observed error text and selected failed
  row afterward. The preview received user input during inspection; it remained
  fixture-only, which was explained, and the exact test process was stopped.
- Development builds and signature checks passed. Thumbnail placeholders remain;
  no successful remote selection or live playback is claimed by these UI checks.

### M5 bounded artwork cache — 2026-10-01

- Added ArtworkCache using an ephemeral, cookie-free session, four connections per
  host, 10/15-second request/resource limits, and a streaming 2 MiB byte ceiling.
  Initial and redirected URLs must remain HTTPS on the two approved thumbnail
  hosts, with no credentials or nonstandard port. Failed/rejected streams cancel.
- ImageIO accepts one image up to 4096×4096, downsamples to 320 pixels, and writes
  a fresh JPEG without source metadata. Cache writes are atomic and user-only;
  pruning keeps at most 100 owned JPEGs and 20 MiB while preserving unrelated files.
  Cached corruption, missing artwork, network errors, and storage failures return
  no image and never alter player state or favorites.
- SearchWindow requests artwork for visible results, cancels work for removed rows,
  retains at most the visible result images, and refreshes only completed image
  rows. Placeholder remains on failure. Cache lives under the isolated app data
  directory's Artwork folder, so development tests do not touch user cache/state.
- Three ImageIO/filesystem tests cover normalized dimensions/type, offline cache
  hits, corruption repair, unsafe URLs, oversized/invalid images, 100-file eviction,
  unrelated-file preservation, and unwritable cache destinations. Full sequential
  suite passed: 59 deterministic declarations plus one live skip, 60 discovered,
  8.74 seconds. Real thumbnail networking and visual artwork inspection remain open.

### First bundled live playback success — 2026-10-01

- Built/signed a fresh development app using pinned yt-dlp 2026.08.19 and Node
  26.7.0 with disposable state. Computer-use inspection repeatedly timed out, so
  verification continued through maroctl. The initial UI probe was stopped.
- Added opt-in check-live-playback.py: anonymous public Bach search, stable favorite
  metadata seeded into temporary state, selection through the real app/socket/
  controller/source/AVFoundation path, playback polling, pause, and app cleanup.
  Raw source diagnostics and signed media URLs are never printed or persisted.
- PASS: selection returned ok after 24.48 seconds; app reported playing with position
  advancing beyond two seconds. This establishes short live native feasibility,
  not audible quality, sustained reliability, UI close-on-start, or 30-minute
  listening acceptance. Earlier isolated AVAsset failures remain historical evidence;
  do not repeat them without a changed hypothesis. Startup latency needs measurement.
- Preparation messages now distinguish unsupported codec, failed native check,
  timeout, stream opening, and no audio-only source. A focused controller test
  passed three error cases while preserving paused metadata. Artwork visual
  verification remains open; passing cache tests do not satisfy that gate.

### M4 bounded Launch Services recovery — 2026-10-01

- CommandClient now recovers only missing/refused connections: one launch, a
  four-second readiness window with command-free probes, and one post-launch
  command attempt. Ambiguous replies never enter recovery. Cancellation and peer
  checks remain active. Tests verify single launch/delivery, deadline, and no replay.
- maroctl uses /usr/bin/open -g (Launch Services) under a three-second process
  budget. Default recovery targets the development bundle ID; MARO_APP_BUNDLE can
  select an explicit bundle and isolate its data through an explicit maro.sock path.
  A custom socket without an explicit app remains connect-only. Release bundle
  identity/runtime packaging are still pending M7 work.
- The first integration run found a real listener bug: a disconnected readiness
  probe could make accepted-peer credential checking fail and stop the service.
  Accepted-peer setup failures now close just that peer and continue within the
  original accept deadline. This preserves authorization checks and live listeners.
- Corrected recovery tests passed. Real Launch Services smoke check launched the
  signed development app in the background and returned an idle status response
  successfully in about 0.70 seconds. The exact test process was terminated after
  verification. No actual user data or bar configuration was touched.
- Final full sequential suite passed: 63 deterministic declarations and one live
  skip, 64 discovered, 8.97 seconds.

### M6 repository-owned bar renderer — 2026-10-01

- Read the existing item/plugin boundaries and queried registered SketchyBar events
  without mutations. Added separate integrations/sketchybar item/plugin files;
  existing Spotify and all active configuration remain unchanged.
- Renderer pulls one authoritative snapshot and builds one SketchyBar update batch
  for idle/search, Now Playing/Favorites, transport/replay, add/remove favorite,
  source/persistence errors, and 20 bounded saved-video rows. Clicking a saved row
  selects it; documented right-click removes it even if playback is unavailable.
  Popup view is bar presentation state; playback/favorites remain controller-owned.
- Registration is idempotent for the Maro event/root and refreshes on initial load,
  custom state event, and wake. Idle click opens search; loaded click toggles popup.
  Remote text is normalized and passed as subprocess arguments, never evaluated.
  Click scripts use quoted paths/options and strictly validated video IDs.
- Pure Python renderer checks passed for hostile shell-like titles, one-batch
  properties, both popup views, 20/21 favorites, replay, and source-error states.
  Shell syntax passed. No active bar registration or rendering is claimed yet.
- Next: connect app state changes to the custom event, provide artwork to popup
  rendering, then verify an isolated/live Maro item and hot reload. Installation
  must remain additive/reversible and preserve unrelated configuration.

### M6 controller refresh notifications — 2026-10-01

- Added a controller-owned notifier for `maro_state_changed`. It projects only
  visible snapshot fields, coalesces changes for 150 ms, and ignores position-only
  ticks. The app sends no metadata in the event; the bar pulls authoritative state.
- Uses the existing bounded subprocess runner with a two-second timeout and small
  output limits. Missing/unavailable SketchyBar is nonfatal. Shutdown cancels and
  awaits the pending notification before flushing controller state.
- Added a deterministic check covering coalescing, position filtering, visible
  error refresh, and cancellation on shutdown. Full sequential Swift suite passed:
  64 deterministic declarations plus one skipped live test, 65 discovered, 9.99 s.
- Native lifecycle smoke passed with isolated state and `/usr/bin/true` as the
  SketchyBar stand-in: status, favorites, duplicate instance, clean shutdown, and
  paused relaunch. This verifies app integration without modifying the active bar;
  actual SketchyBar event delivery and layout remain acceptance work.
- Next: popup artwork, live event/layout and hot-reload checks, followed by
  reversible installation. Sustained listening and release packaging remain open.

### M6 popup artwork pipeline — 2026-10-01

- Reused ArtworkCache for loaded/favorite thumbnails. Controller snapshots expose
  existing local JPEG paths, keyed by video ID, without adding derived paths to
  persisted state. Cache loss removes stale paths immediately and the next refresh
  rebuilds them. Artwork completion triggers the existing coalesced bar event;
  cancelled/superseded work cannot publish after shutdown or replace newer work.
- Default app cache now matches the TDD's `Library/Caches/Maro/thumbnails` location;
  development data overrides retain isolated caches. Search and popup use the same
  directory and normalized image format.
- Popup renderer now sets cover/favorite image properties in the same snapshot
  batch and falls back to music symbols. It rejects absent, symlinked, non-owned,
  incorrectly named, and oversized paths. Registration adds missing children on
  reload, including the newly introduced cover item, without replacing the root.
- Full sequential Swift suite passed: 65 deterministic declarations plus one live
  skip, 66 discovered, 9.97 seconds. New controller check verifies paused restore,
  path publication, cache-loss repair, wire validation, and no paths in state.json.
  Renderer checks passed for existing/deleted/symlinked artwork alongside prior
  hostile metadata and bounded-favorites checks. Image properties checked against
  official SketchyBar documentation; live layout remains unverified.
- Next: real bar event/artwork and hot-reload acceptance, then reversible packaging
  and installation. No active bar configuration changed in this slice.

### M6 real bar integration check and event fix — 2026-10-01

- Added an opt-in live-bar check using isolated paused fixture state and generated
  local artwork. It refuses to replace pre-existing Maro items, adds only Maro
  runtime items, and removes them in a finally block. Saved configuration is never
  edited. Cleanup asserts the complete original item inventory is restored.
- First corrected the probe's item-query shape (`geometry.background.image`).
  The next run exposed an actual event failure: SketchyBar exits with
  `env USER not set` under the subprocess runner's minimal environment. Added the
  platform-derived username (NSUserName), without inheriting arbitrary environment
  variables. Explicit `updates=on` also keeps the anchor subscribed while hidden.
- Real SketchyBar check then passed: cover path/drawing, favorite icon path, native
  app event delivery after a CLI favorite mutation (no manual refresh), missing
  child re-registration, and preservation of paused position/favorites. All
  temporary Maro items and the test app were removed; unrelated items were intact.
  The unused custom event remains registered until normal bar reload because
  SketchyBar exposes no event-removal command.
- Full sequential Swift suite passed after the runner fix: 65 deterministic
  declarations plus one skipped live test, 66 discovered, 9.99 seconds.
- Limits: this proves real bar property/event integration, not visual layout or
  hot reload during audible playback. Those checks and sustained listening remain
  open. Next: package resources/reversible installation, then full live workflow.

### M7 self-contained acceptance bundle — 2026-10-01

- Confirmed the installed Homebrew Node links many Homebrew libraries; copying it
  alone would not produce a self-contained app. Pinned official Node 26.7.0 arm64
  against nodejs.org's SHA-256 manifest. Added bounded build-time archive fetching
  that extracts only the regular-file executable and license, never tar paths.
  Verified archive and executable hashes; official binary links only system libs.
- Extended the existing development bundler with `--standalone`. It verifies both
  executable pins before copying, includes runtime/license/manifests, signs nested
  executables first, and enables Hardened Runtime for app/CLI. The runtime and
  extractor children currently retain ordinary ad-hoc signatures. No broad
  entitlement was introduced; Developer ID/notarization are not claimed.
- Built `/private/tmp/maro-standalone-20261001/Maro.app`; strict deep signature
  verification passed. With minimal PATH and no source/runtime overrides, native
  lifecycle checks passed: status, favorites, duplicate instance, shutdown, paused
  relaunch. Bundled Node executed JavaScript and the extractor reported its pinned
  version. Extractor's local semaphore requires normal tool escalation outside the
  restricted sandbox; the escalated check succeeded.
- This is an arm64 debug acceptance bundle, not a release build. Packaged live
  source/playback, third-party distribution notices, release-mode build, reversible
  installer and actual installation remain. Reuse the bundler for the release
  artifact rather than adding another packaging path.

### M7 packaged live probe and optimized build — 2026-10-01

- Extended the existing live probe: app-only invocation resolves bundled resources,
  drops development overrides, uses minimal system PATH, suppresses optional bar
  events, and cleans up disposable state/processes. Explicit paired tool arguments
  remain available for development. Probe output now includes only public video ID,
  safe command error and elapsed time; no signed media URLs or raw source output.
- Self-contained debug bundle passed short live playback: preparation 23.77 s,
  playing state and position beyond two seconds. This confirms packaged resource
  discovery without Homebrew PATH. It is not sustained listening acceptance.
- Optimized Swift build passed in 6.79 s, and its standalone bundle passed strict
  deep signature verification and isolated native lifecycle checks. Its live probe
  FAILED after 8.26 s with video_unavailable / native playback incompatibility.
  Do not infer an optimization regression or transient source failure yet: the
  search-based probe did not record the selected ID before this failure, so the
  two runs cannot be confirmed to have used the same source. No repeated retries.
- Inspected Mach-O minimum versions: official Node needs macOS 13.5. Corrected
  standalone Info.plist minimum from 13.0 to 13.5, pinned it in runtime.json, and
  rebuilt/signature-verified `/private/tmp/maro-release-verified-20261001/Maro.app`.
  This final metadata-corrected bundle has not yet passed live playback.
- Next: reproduce the release playback failure with a fixed public video across
  debug/release before drawing conclusions; reversible installer work is independent
  and ready. Release playback, full UI/hot-reload and listening acceptance stay open.

### M7 fixed-video debug/release comparison — 2026-10-01

- Added validated `--video-id` to the existing live probe, allowing the same public
  video to be resolved fresh by each app without search-result variability. The
  selected public ID is printed before preparation so failed runs remain traceable.
  No new diagnostic path exposes signed URLs or extractor stderr.
- Sequential comparison on `mGQLXRTl3Z0`: standalone debug prepared in 23.82 s;
  metadata-corrected optimized bundle prepared in 23.84 s. Both reported playing
  and advanced beyond two seconds, then paused and terminated cleanly. Both used
  their own bundled extractor/runtime with a minimal PATH and isolated state.
- The optimized bundle now has short live playback evidence. The earlier failure
  was not reproduced by this controlled comparison; its cause remains unknown,
  so do not claim source reliability or that a playback bug was fixed. Preparation
  latency remains approximately 24 seconds and warrants investigation separately.
- Next ready slice: reversible installer with explicit temporary destinations and
  round-trip preservation checks. Visual layout, playback during bar reload, and
  30-minute listening acceptance remain open. No user configuration changed.

### M7 reversible installer — 2026-10-01

- Added explicit-prefix installer for a dedicated app/CLI/SketchyBar folder. It
  verifies standalone resources and the deep app signature, quotes generated
  launcher paths, and stages copies before renaming them into place. It prints a
  source line rather than editing or reloading existing SketchyBar configuration.
- Receipts inventory file contents/permissions and directory membership. Repeated
  identical installs are unchanged; unmanaged destinations and altered installs
  are preserved with a clear error. Upgrades retain the verified prior generation
  in a sibling backup. Rollback validates that backup before restoring it;
  uninstall preserves state, unrelated configuration, and historical backups.
- Runnable temporary round-trip passed using real signed release/debug bundles:
  install, repeat-install idempotence, launcher execution through an apostrophe/
  space-containing path, user-edit refusal, upgrade backup, rollback, repeat
  uninstall, and preservation of unrelated/unmanaged files. No actual user install
  or saved bar configuration was modified.
- Added docs/INSTALLATION.md covering explicit destinations, stopping the app for
  replacement, source-line integration/removal, backup behavior, and single-operation
  use. Installer operations are intentionally not concurrent.
- Next: missing packaged-dependency acceptance and third-party notices, then
  approved local installation and remaining visual/live workflow checks. Full
  bar reload during playback and 30-minute listening remain unverified.

### M7 missing packaged dependencies — 2026-10-01

- Added an offline app-level check using a disposable copy of the optimized bundle.
  It removes each packaged helper in turn, re-signs only that temporary app, and
  verifies startup, clear missing-dependency failure, unchanged paused track and
  favorites, local favorite editing, durable shutdown, and no source-update latch.
- Initial probe failed startup because its newly created state subdirectory had
  default 0755 permissions. Diagnostics confirmed the app rejected that unsafe
  directory. Corrected the fixture to 0700; production permission checks unchanged.
- Final probe passed for both missing Node and missing yt-dlp. Source bundle and
  user data/configuration were untouched; temporary processes/files cleaned up.
- Next: include verified third-party notices in the package, then actual local
  installation and remaining visual/live acceptance. No new external blocker.

### M7 pinned package notices — 2026-10-01

- Retrieved the exact yt-dlp 2026.08.19 project license and its upstream aggregate
  for components in PyInstaller executables. Recorded sizes and SHA-256 hashes in
  extractor.json. Reused the bounded atomic fetcher for both notices; existing
  verified executable is not downloaded again. Node's archive-provided license
  now has its own pinned hash checked by packaging.
- Standalone packaging refuses missing/modified notices, includes complete
  upstream texts plus a provenance overview, and signs after resources are copied.
  No publication or distribution was performed; signing remains local ad-hoc.
- Rebuilt optimized acceptance app at `.build/acceptance-20261001/Maro.app`.
  Strict deep signature verification passed. Installer round-trip against the
  preceding bundle passed, including receipt coverage of the new notice files,
  upgrade backup, rollback, unchanged installs and unrelated-file preservation.
- Next: install this concrete artifact into an explicit local prefix through
  normal tool approval, add only a Maro source line to active SketchyBar config
  with a backup, and inspect native UI/live playback plus bar reload. Sustained
  listening remains pending; no need to repeat the short source probe unchanged.

### M7 local installation and additive bar activation — 2026-10-01

- Installed the verified acceptance artifact through normal tool approval into
  `/Users/devinhasler/Applications/Maro Local`. Installed launcher started the app
  via Launch Services and returned an idle empty library using the normal user
  data location. No test favorites or fixture playback were copied into user state.
- Added enable-bar.py with exact backup, quoted module path, syntax preflight,
  idempotence and conflicting-block refusal. Its temporary check passed before use.
  Approved activation appended only the Maro block to the existing sketchybarrc.
  Backup: `~/.config/sketchybar/sketchybarrc.maro-backup-06adb319910c4c82ac8f8997c7beb962`.
- Approved registration loaded the installed item module without a full bar reload.
  Live queries confirmed 31 Maro items, idle Search music label, and retained
  Spotify anchor. Existing saved configuration bytes precede the appended block;
  unrelated bar definitions were not replaced.
- Maro is now installed and idle on the active bar. Next: native search/artwork and
  popup visual inspection, playback while bar reloads, then measured sustained
  listening. Short query/property checks are not visual or 30-minute acceptance.

### M8 installed search/artwork and playback reload — 2026-10-01

- Inspected the installed native panel through computer-use: focused search field,
  empty prompt and disabled play control were correct. Submitted a public Bach
  query via keyboard; five real results displayed recognizable thumbnails, titles,
  creators and durations. Load 5 more revealed ten rows. Keyboard selection showed
  Preparing audio before the installed app reached playing state.
- Live CLI confirmed `mGQLXRTl3Z0` playing with position beyond 19 seconds. Full
  SketchyBar reload through normal approval preserved that track and playing state;
  position advanced from 47.00 to 50.00 seconds. Paused the test track afterward.
- Computer-use timed out when inspecting the app after playback started, both by
  bundle ID and exact installed path. Do not treat this timeout as proof the panel
  closed. Successful-close and popup visual inspection remain open.
- Found a cache-location inconsistency in the real launcher path: explicit bundle
  recovery always supplies MARO_DATA_DIRECTORY, even for the default directory, so
  app setup mistakenly treats normal launches as isolated and caches under state/
  Artwork. Next fix the default-directory comparison instead of testing only whether
  the environment override is present. State/favorites are unaffected; existing
  cache is derived and may remain until normal cleanup.
- Still pending: visual close/popup acceptance and a measured 30-minute session.
  Short playback/reload checks do not establish audible continuity or full listening.

### Default cache location fix and installed upgrade — 2026-10-01

- App setup now compares the resolved data-directory URL with the default data
  directory instead of treating any MARO_DATA_DIRECTORY environment value as an
  isolated test. Normal explicit-bundle launches therefore use Library/Caches;
  non-default development directories retain their isolated Artwork subfolder.
- Optimized build passed in 1.74 s. Rebuilt `.build/acceptance-cache-fix/Maro.app`
  and passed strict deep signature verification. Stopped only the identified
  paused installed process through normal approval, confirmed socket cleanup, and
  upgraded via the installer. The previous install remains in its rollback backup.
- Installed launch/status checks passed: same public video, same paused position
  (91.606433621 seconds), no favorites lost, and existing artwork path under
  `~/Library/Caches/Maro/thumbnails/`. Old derived cache files were not deleted.
- Next: popup visual inspection and successful search-window dismissal, then the
  measured sustained playback session. The installed app remains paused.

### M8 sustained playback monitor started — 2026-10-01

- Computer-use could not identify SketchyBar by name; its app listing returned no
  SketchyBar/Maro match. Popup visual acceptance remains unavailable through that
  tool. Do not repeatedly retry it without a changed condition.
- Added an opt-in real playback monitor with safe JSONL samples, fixed-track
  identity checks, progress accounting that excludes seek jumps/replay resets,
  failure/stall detection, and respect for user pauses. The probe explicitly replays
  the loaded track at its end when requested; this is test orchestration, not app
  autoplay. It pauses its own playback when finished. Arithmetic checks passed.
- Started the 1800-second run through normal tool approval, using the installed
  app and its existing loaded public track. Active exec session: **20299**.
  Evidence: `.build/acceptance-evidence/listening-20261001T0820.jsonl`.
  **Do not launch another monitor, replace the app, toggle playback, or select a
  different track while this run is active.** Read the log and poll that session
  on subsequent heartbeats; continue independent documentation/review work.
- No sustained pass is claimed yet. A pass requires 1800 seconds of observed media
  progress, not elapsed time alone. Audible quality still needs human confirmation;
  this monitor cannot hear the output. Final popup/close visual checks remain open.

### Acceptance reconciliation during listening run — 2026-10-01

- Re-read final PRD success criteria and check coverage. Added docs/ACCEPTANCE.md
  mapping requirements to evidence and remaining manual checks. The PRD calls for
  a manual user session; status advancement cannot verify audible quality.
- Persisted runnable offline progress-accounting checks; forward movement, stalls,
  backwards movement, seek jumps and replay resets pass.
- At 08:26:09 UTC the listening log showed 165.395 seconds media advancement,
  playing state and no reported error. Session 20299 remains active; this slice
  changed no playback, installed files, or user configuration.

## Evidence and limitations

- HumanLayer latest TDD ends at `Patterns to Follow`; no prior implementation.
- Swift 6.2, native macOS SDK, SketchyBar and Node 26.7.0 are installed; the
  checksum-verified yt-dlp 2026.08.19 is under `.build/tools/` (not PATH).
- Short live native playback, installed optimized build, real bar reload, and ad-hoc
  signing are verified. Sustained source reliability, final visual checks, Developer
  ID/notarization, and the 30-minute listening gate remain unverified.
- Existing `.gitignore` was untracked when this work began; preserve its entries.

### User-reported pause failure — 2026-10-01

- User reported inability to pause. Stopped listening probe PID 14422 (session
  20299), then directly paused the installed app. Response confirmed paused at
  564.337418156 seconds. The interrupted run is not a completed listening pass.
- Installed bar transport has a valid `action toggle` click script and now shows
  Play, confirming state refresh. Investigating popup/control interaction with
  user clarification pending. **Do not restart the listening probe or resume audio
  automatically.** The prior active-monitor instructions are superseded.

### Interrupted monitor cleanup correction — 2026-10-01

- SIGTERM previously ended the test process without entering its pause cleanup;
  that is why stopping the probe required a separate direct pause. The probe now
  routes termination through its interruption handler, records failure/interruption,
  and performs bounded cleanup for playback it started. Also handles a cleared
  loaded-video value safely during cleanup.
- Offline fake-CLI check passed: terminate after a sample, observe paused simulated
  state, interruption record, cleanup record, and no success record. No real app,
  audio, socket, installed files or user state was touched by this check.
- Interrupted live evidence has 92 samples and 456.896 seconds media advancement
  (last sample 08:31:00 UTC), no sampled error, and no completion record. This is
  approximately 7.6 minutes, not a 30-minute acceptance pass.
- Updated acceptance/next-action notes to remove stale active-monitor instructions.
  User-facing pause interaction is still unresolved; the runner cleanup fix is
  separate. Keep real playback paused pending clarification.

## Next action

### MARO-002 installed — 2026-10-01

- User requested continuing after playback finished. Verified paused and not
  selecting immediately before stopping the exact Maro process; installed
  `.build/acceptance-navigation/Maro.app` using the reversible installer.
- Registered updated plugin. Verified identical loaded video/position/favorites,
  paused playback, disabled Previous/Next with no restored search session, and
  safe invalid_request responses for both commands without a list. Opened popup.
- User can search and select a result to enable navigation within that search's
  fetched list. No real audio was started and live navigation has not been claimed
  from fixture tests. Physical controls/listening acceptance remain outstanding.
- Removed stale pending-install handoff and paused the Maro heartbeat through the
  app API, confirmed PAUSED; no independent implementation slice remains queued.

### MARO-002 current-search navigation ready — 2026-10-01

**Latest handoff:** user explicitly chose “Wait until I pause.” Resumed only the
Maro heartbeat with a priority handoff to wait quietly while playing/buffering or
selecting, then recheck paused/non-selecting state and install the prepared bundle.
No need to ask again when that condition is met. Notify once installed, preserve
paused playback, then pause the loop if only manual acceptance remains.

- User chose current search results. Implemented Previous/Next across all fetched
  results (up to 20), including unrevealed rows, no wrap; disable when current video
  is outside that list, during preparation, or source-update gate. New search clears
  the prior list. No autoplay at end and no separate persistent queue.
- Reused controller loading with explicit playback intent: paused navigation stays
  paused; playing navigation continues. Failed neighbor preparation preserves the
  current track. CLI commands, optional snapshot capability flags and bar events
  expose state; renderer provides disabled/enabled navigation actions.
- Full suite: 67 discovered, 66 deterministic tests passed, one opt-in live test
  skipped (10.112 s). Added targeted boundary/playing-intent assertions passed in
  a subsequent 0.202 s navigation test. Renderer checks pass. Release build and
  signed standalone `.build/acceptance-navigation/Maro.app` packaging succeeded.
- **Installation pending:** guarded install found playback now playing/selecting
  and exited before stopping any process or changing files. User asked whether to
  wait until they pause or pause/install now. Do not interrupt playback without that
  response. Installed version is still the previous header-fix bundle.
- Next: install this exact prepared bundle once paused/authorized, register its
  plugin, verify paused restore and search-list capability state. Live navigation
  interaction remains separate from silent-fixture proof. AFK remains paused.

### Header clipping fix — 2026-10-01

- User screenshot confirmed the title vanished after moving the star right. The
  negative label padding used to reverse native text slots clips scrolling text.
- Corrected the shared header to use native left-to-right slots: title in the icon
  text slot (bold 14pt, full metadata, scrolling), star in the label slot (24pt
  width). All text padding is nonnegative; no overlapping text surfaces.
- Updated renderer regression assertions and ran them successfully. Reversibly
  installed and checked the live full title, slot padding and scrolling settings;
  playback remains paused. Await visible confirmation; property checks alone do
  not establish animation rendering. AFK remains paused.

### Header, artwork and compact transport refinements — 2026-10-01

- User requested larger bold looping title, a top-right star without its own row,
  vertically centered artwork, explicit channel labeling and compact icon transport.
- Installed 14-point bold scrolling header with outlined/filled star on the right;
  the old favorite row is hidden. SketchyBar uses one header item for text and icon,
  so its existing click handler toggles Favorite across the header hit area.
- Artwork offset now derives from actual cached JPEG height and displayed row
  count, centering it rather than pinning it below the controls. Aspect ratio stays
  unchanged. Added `▣ Channel ·` to clarify uploader metadata; the unusual phrase
  in the screenshot is the real source channel name, not Maro messaging.
- Play/Pause/Replay now use ▶/Ⅱ/↻ in a centered 40-point control. Search and
  Favorites remain below it. Renderer checks pass; installed queries confirm the
  header star, channel marker, 40-point transport and hidden old favorite row.
  Playback stayed paused through reversible installation; visible confirmation
  of the new composition remains pending.
- User also asked for Next/Previous. Created MARO-002 and asked which list should
  drive navigation (search results, favorites or history). Await that answer before
  choosing behavior. The AFK heartbeat remains paused; no audio restarted.

### Installed star acceptance and AFK pause — 2026-10-01 11:17 Europe/Zurich

- Executed the actual installed favorite click handler for the currently unsaved
  paused track: saved it, observed filled star, removed it, observed outlined star.
  Verified original favorites restored exactly and playback stayed paused. This
  verifies handler/state integration, not a physical click or audible playback.
- Current requested refinements are installed and checked. Remaining next work
  depends on user feedback on visible title looping/button layout and deliberate
  manual transport/listening acceptance. No new playback session is authorized.
- Paused only `maro-afk-implementation` using the app automation API; response
  confirmed PAUSED, preserving its prompt, schedule and target chat. Do not keep
  polling the same manual gates. Resume after user feedback supplies actionable
  work or authorization for a deliberate listening session.
- MARO-001 remains open: shared-strip/reference fidelity has not been established;
  the latest requested row/button refinements are not a claim of full acceptance.

### User screenshot refinements installed — 2026-10-01

- User supplied a scoped popup screenshot and requested a filled/outlined favorite
  star, clearer Search/Favorites buttons and continuously scrolling full title.
  Implemented these directly in the existing native SketchyBar renderer. A brief
  unconnected AppKit card experiment was removed; no new window architecture ships.
- Screenshot also exposed Play's green background intruding into the artwork.
  Moved right-column spacing to item padding instead of text padding; installed
  queries now show every title/control window at x=1069, width=200, disjoint from
  the artwork column. Explicit button backgrounds/borders/radii are enabled.
- Preserve the full title up to the source's 4096-character limit, with native
  `scroll_texts=on`, 28-character viewport and 180-frame scroll duration. The live
  item reports the full title and scrolling enabled; visual looping remains a
  human check, not proven from property queries.
- Renderer regression checks pass for star states, long-title retention, button
  styling and previous safety checks. Reversible install completed; real handlers
  close/reopen successfully. Playback stayed paused throughout.
- **Next:** obtain feedback on the updated visible animation/layout and continue
  remaining MARO-001/manual acceptance. Do not resume audio or listening probe.

### MARO-001 installed geometry corrections — 2026-10-01

- Installed the card foundation through the existing verified/backup installer.
  Stopped only the exact paused Maro process before each installation; restored
  paused state at 565.916028549 seconds. No listening probe or audio was started.
- Live queries exposed long-title overflow (450-point item outside a 368-point
  card) and stale popup child ordering despite `--move`. Fixed text widths and
  added a known-child-only popup order migration; unrelated items are preserved.
- Renderer check passes including migration coverage. Installed queries confirm
  title/creator/transport widths 368, progress width 200, progress/time before
  transport, real cached YouTube image enabled, and close/reopen handlers passing.
- Latest rollback copy: `/Users/devinhasler/Applications/Maro Local.backup-32011a49b60943518467cc0ff17bc5c0`.
- Visual inspection remains unverified: automatic approval review rejected a
  Finder/desktop screenshot because it could expose unrelated private content.
  No bypass attempted. The safer SketchyBar-specific capture returns Invalid app;
  app discovery supplies no Maro/SketchyBar target. Need a popup-only screenshot
  from the user for visual feedback; queries do not establish fidelity.
- **Next:** refine shared control-strip layout without overlapping click targets;
  inspect the installed composition when scoped visual evidence becomes available.
  The installed version is an intermediate card, not completed MARO-001 acceptance.

### MARO-001 native card foundation — 2026-10-01

- Added a dark rounded popup with a light outline, left-hand cached YouTube preview,
  right-hand metadata/progress and a green rounded transport button. Favorites
  switches back to full-width rows without the large image. No controller change.
- Native layout investigation: SketchyBar horizontal popups allocate the same
  height to every item window (upstream `src/popup.c`, `popup_calculate_bounds`).
  Overlaying zero-width text items and controls risks overlapping click windows.
  The initial safe composition therefore uses vertical right-column action rows
  and renders artwork on the popup background, spanning those rows.
- This is a foundation, not reference fidelity: Favorite/Search/Favorites remain
  separate rows rather than a shared horizontal capsule. Actual geometry, image
  offsets/proportions and click behavior still require live visual inspection.
- Existing renderer check passes with new assertions for artwork/view switching,
  right-column spacing, green transport, and missing-image fallback. Installed
  working popup and paused playback were left unchanged.
- **Next:** inspect the native card on the live bar through reversible installation;
  resolve remaining layout fidelity from observed geometry. Do not claim the ticket
  complete or change app architecture without exhausting the native composition.

### MARO-001 progress indicator slice — 2026-10-01

- Read the plan, acceptance ledger, current renderer and thumbnail flow. Existing
  source metadata/cache already supplies YouTube preview images; reuse that path.
- Implemented progress/time items in the repository renderer using native item and
  label backgrounds, without a draggable seek control. Clamp position to duration,
  handle invalid/unknown durations, and format long videos with hours.
- Progress routine updates only the two indicators every two seconds while shown
  and playing/buffering. Rechecks popup/view before reading status, and disables
  the timer while paused; it does not change audio or controller notification rate.
- Expanded the existing renderer check: passed all cases including invalid numeric
  inputs, elapsed-time formatting, hidden/Favorites no-poll, two-item redraw and
  existing click reopening, artwork-path safety and favorite bounds.
- Not installed yet: keep the working popup until the complete horizontal layout
  is ready. No real visual fidelity or new playback acceptance claimed.
- **Next slice:** horizontal card/artwork/control layout and real visual inspection;
  use the existing cache for YouTube previews, then reversible installation.

The Maro heartbeat was successfully resumed to ACTIVE on 2026-10-01, preserving
its five-minute schedule and this coordinator chat. Its updated instructions
prioritize MARO-001 and the user's additional YouTube preview-image request,
reusing the existing thumbnail cache. No audio or listening probe was restarted.

**Latest user direction:** user confirmed the popup works, then explicitly requested
resuming AFK work and a redesign ticket based on the attached reference. Ticket
`docs/tickets/MARO-001-player-redesign.md` is ready; the image is preserved under
`docs/tickets/assets/`. Implement that ticket next. Earlier paused-loop notes below
are historical. Continue without automatically restarting audio or the interrupted
listening probe; visual implementation can proceed with the current paused track.

**Current priority:** the user clarified the popup appears when invoked directly
but does not reopen after closing. Corrected and installed event dispatch: explicit
clicks/actions take priority over a stale mouse-exit sender; pointer exit no longer
dismisses controls. Offline regression and real installed handler open/close/reopen
checks passed, including the stale sender; playback stayed paused. The user has now
confirmed: “the pop works now.” Session **20299 is stopped**; do not restart a monitor
or resume audio automatically. No listening pass has been earned.

### AFK paused awaiting manual confirmation — 2026-10-01 10:42 Europe/Zurich

- Reconciled remaining acceptance gates: physical popup/transport interaction,
  final visual workflow, and human listening confirmation. Existing computer-use
  limitations prevent independently verifying those UI actions. No further change
  is justified solely by the unconfirmed physical click outcome.
- Paused only `maro-afk-implementation` through the automation tool; result
  confirmed PAUSED. All other saved fields and other project automations preserved.
  This follows the user's instruction to pause when remaining work needs external
  input rather than repeatedly retrying. Implementation is not marked complete.
- Installed app remains the acceptance build in `~/Applications/Maro Local`.
  User can confirm whether the updated popup now opens, closes, and reopens. Then
  continue the relevant remaining checks deliberately; never automatically resume
  audio or the interrupted listening probe on receiving confirmation alone.
