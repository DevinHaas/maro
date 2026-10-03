# Acceptance evidence

## Current handoff — 2026-10-03

Styling v2 is installed and verified as recorded below. Required card/SketchyBar
renderer checks pass. No outstanding implementation task is safely actionable
without new feedback. The AFK heartbeat is paused, not project-complete.

- User visual review of installed styling is pending. Strict original before/after
  evidence remains incomplete: isolated rollback app stayed idle/empty, but
  supported UI lookup timed out; it was stopped without touching installed state.
- Physical timeline drag/release on a prepared paused track, followed by reopening
  and confirming retained position/pause, needs user confirmation.
- The deliberately held 30-minute audible listening/playlist-navigation session
  and real playlist follow-up checks below remain open. No fixture substitutes.

Everything below records historical evidence; newer handoff entries supersede
older pending-install and unavailable-tool notes. Do not reinstall older bundles.

Final renderer checks (2026-10-03): current card renders eleven states and passes
toggle/hide/reopen/Escape without preparing audio; offline SketchyBar checks pass
metadata/routing, events, display placement and long titles. No installed changes.
Remaining styling evidence audit: usable original before baseline from isolated
rollback copy if feasible. No further test reruns are required without source changes.

Styling v2 installed 2026-10-03 from `/private/tmp/maro-styling-v2/Maro.app`.
All four isolated dependency checks, release/signature and recorded regressions
pass. Exact fresh track/position/favorites/volume preserved paused with rollback.
Installed initial Search screenshot inspected; field focus retained. Representative
add/detail/disconnected/loading fixture screenshots also inspected without real
playlist edits. Remaining: required renderer checks, baseline evidence reconciliation
and precise final acceptance audit. Physical timeline dragging/listening remain open.

Issue 09 inactive/failure/rename (2026-10-03): supported screenshots now verify
readable inactive button labels after activation-aware native styling, readable
error state with disabled actions, and focused/preselected rename dialog. Fixture
cancelled and quit. Rebuild uses fresh `maro-styling-v2`; older candidates are
superseded even though their signature/dependency checks passed.

Issue 09 unavailable timeline (2026-10-03): metadata fraction now renders correctly
without enabling seeking. Supported screenshot/AX confirm muted 90/3600 progress
and disabled control. Seven app tests pass. Earlier styling candidate predates
this fix and must not be installed; rebuild/delivery remain pending.

Issue 09 compact/transitions (2026-10-03): supported UI revealed 10 results,
scrolled at compact 560×450, and traversed card/Favorites/search with state and
focus retained. Compact/card/empty-Favorites screenshots inspected. Fixture exposed
an unavailable-timeline full-fill discrepancy; fix before delivery. Candidate
packaging underway, not installed.

Issue 09 native controls (2026-10-03): fixed title color replaced by per-button
native appearance. Active contrast verified in supported screenshot; inactive
screenshot remains pending. Settled Down selects a result; Escape/Show Search
reopens with field focused and result retained. No playback action performed.

Issue 09 contrast slice (2026-10-03): supported screenshots confirm dark dialog
surface and dark-on-green active primary titles. Fixture search typing/Return
shows correct empty/results and disabled actions without playback. Inactive
primary-title contrast needs refinement; settled-result keyboard and reopen
verification remain pending after a hidden-window lookup timeout.

Issue 09 supported UI (2026-10-03): normal fixture lifecycle resolved CUA lookup.
Search/library/create/delete screenshots inspected. Typed a disposable name;
Escape cancelled. Delete confirmation Return cancelled back to unchanged fixture
detail. Real playlists/audio untouched. White labels on green AppKit actions and
gray dialog surfaces need refinement; remaining input/resize/delivery gates open.

Issue 09 regression (2026-10-03): full suite passes, 94 tests in 21.963 s.
Persistent isolated UI fixture inspection failed at application registration/CUA
lookup; no on-screen or physical interaction gate passed. Fixture stopped;
installed player and paused state untouched.

Issue 09 search (2026-10-03): six app tests pass, including visible-frame bounds
on multiple display geometries. Isolated initial/results/empty/error fixture
checks text-editor focus and cancel/reopen programmatically. Offscreen chrome
rendering is corrupted; supported on-screen inspection and physical input checks
are still required. No new build installed.

Issue 09 dialogs (2026-10-03): native name/delete factories retain focus and safe
Cancel defaults; five app tests pass. Disposable create/rename/delete renders
complete without actions, but offscreen native vibrancy corrupts the images;
on-screen visual/input acceptance remains pending. Nothing installed this slice.

Issue 09 library slice (2026-10-03): seven isolated states rendered; detail,
empty, add and disconnected inspected at 620×500 with readable controls. Before
captures have offscreen vibrancy artifacts and cannot establish the baseline.
Four app regressions pass; final modifier adjustment compiles/renders. Interactive
focus/selection/accent, search/dialogs and final delivery are still pending.

Issue 09 foundation (2026-10-03): shared card/search palette and native search
styling compile; four app regression tests pass. Not installed or visually
accepted. Full surface fixtures, remaining presentation work, interaction checks,
full suite/release/package and safe delivery remain pending. Issue 08's physical
drag confirmation is separate and remains open.

Final timeline source with 92 passing tests is installed (2026-10-03). Release,
signature and four isolated dependency gates pass; exact latest track/position,
favorites and volume retained paused. Installed UI observed with Play and
Seeking unavailable after metadata-only restoration. Physical drag/release and
installed ready-track seeking remain unverified; user confirmation requested.

All 92 tests pass (21.967 s), including explicit seek timeout/supersession and
component drag-preview/release/cancellation checks. These latest verification
refactors await rebuild/delivery; physical drag confirmation remains pending.

Latest timeline regression: 90 tests pass (21.990 s), including three added
failure/replacement/shutdown cancellation cases. Physical drag remains unverified
because CUA coordinate actions did not reach the window reliably; user check
requested. No audio resumed for verification.

Timeline delivered 2026-10-03: signed v2 package passed all four isolated dependency
checks. Exact latest track/position/favorites/volume restored paused after install.
Supported UI click and two five-second arrow steps observed on silent real-card
fixture. Drag, mid-drag cancellation and remaining race/failure/installed seeking
gates remain open; delivery does not mark issue 08 complete.

As of 2026-10-02 Europe/Zurich. The final original PRD defines a **manual user
acceptance session**. Automated media progress cannot establish audible quality
or replace that session. This checklist separates observed behavior from gaps.

## Current playlist acceptance

User confirmation, 2026-10-02: playlist creation and whole-playlist deletion work
well. This is user-reported evidence, not a new coordinator UI inspection. The
reported video-removal refresh bug and requested duplicate-video prevention are
fixed in the installed package. Live
confirmation of these two follow-ups remains pending.

The later authorized scope adds YouTube-owned playlists for one personal account.
The project now lives at `/Users/devinhasler/projects/maro`. The AFK automation
resumed on 2026-10-02 for acceptance reconciliation; it is **ACTIVE** for the queued timeline and styling tickets.
The user subsequently confirmed playlist operation works; the refresh/deletion
follow-up was installed and regression-tested. Specific live gates below still
require their own evidence. Successful credential setup was
reported by the user; it is not evidence of completed two-way playlist verification.

| Requirement | Evidence | Remaining check |
| --- | --- | --- |
| Only owned playlists | API fixture verifies `mine=true` and pagination; Oct 2 native UI showed a connected library, Ambience with one Silent Fjord entry, and “Up to date with YouTube” | Cross-check ownership in YouTube during test-playlist verification |
| Private creation, add, reorder, occurrence removal | API fixture validates outgoing requests and duplicate item identities | Create a dedicated private test playlist; compare each edit in Maro and YouTube |
| YouTube-side changes refresh into Maro | Refresh implementation exists; no live observation | Edit only the test playlist on YouTube, then Refresh in Maro |
| Playlist previous/next and duplicate occurrences | Silent native controller fixture covers navigation | Installed UI interaction pending |
| Automatic advance, unavailable-item skip, stop at end | Silent native controller fixture covers these transitions | Deliberately user-started live playlist playback pending |
| Pause and replacement win over preparation | Controller fixture exercises cancellation and transport intent | Live interaction pending |

No audible playback or listening probe may be started automatically. The original
manual gates below remain open where indicated.

Focused automated result, 2026-10-02: all four playlist/OAuth checks passed in
3.164 seconds using `swift test --scratch-path /private/tmp/maro-relocation-build
--cache-path /private/tmp/maro-swift-cache --disable-sandbox --no-parallel --filter
'playlist|oauthLoopback'` with temporary module caches. The queue test now explicitly
checks Previous returning from the second occurrence to the first while paused,
then Next restoring that occurrence. These tests use fixtures and silent local
audio; they neither edit Google playlists nor establish live listening quality.

Live attempt, 2026-10-02: the coordinator opened Maro's “Create private playlist”
dialog, entered `Maro verification 2026-10-02`, and selected Save. The dialog closed,
but the new playlist was not visible in the returned list; a subsequent inspection
reported `noWindowsAvailable`. **Creation outcome is unknown.** Refresh and inspect
the owned list for that exact title before retrying, to avoid duplicate creation.
A retry targeting the installed app's full path recovered the same owned list and
“Up to date with YouTube” status, but scrolling again returned `noWindowsAvailable`.
No second creation was submitted; this inspection does not resolve the save outcome.
No add/reorder/remove operation or YouTube-side refresh was verified. Browser
navigation to YouTube was blocked because the administrator policy check was
unavailable. No bypass was attempted. Cross-app acceptance must wait until the
supported browser can verify that policy and access YouTube.

## Earlier installed-player evidence

| Requirement | Evidence | Remaining check |
| --- | --- | --- |
| Native search without a YouTube page | Installed panel inspected; public query returned five results | Passed observed interaction |
| Five more results | Installed panel showed ten after Load 5 more; unit coverage verifies local reveal | Passed observed interaction |
| Thumbnail, title, creator, duration | Resolved native-card ticket: eleven rendered states plus scoped installed layout inspection; search thumbnails inspected | New playlist follow-up UI still needs observation |
| Select by keyboard | Installed panel showed preparation; app then reported advancing live playback | Confirm panel disappears after playback starts; computer-use timed out |
| Failed selection preserves current track | Controller tests and fixture panel failure checks | Final installed error presentation remains a manual check |
| Pause/resume one loaded track | Direct pause works; user confirmed popup works after the installed fix | Confirm Play/Pause interaction in the working popup |
| Save and replay favorite | Installed star handler saved/removed current paused video; filled/outlined star observed, original favorites restored | Physical click/reselect playback workflow pending |
| Maximum 20 favorites, no eviction | State/controller capacity checks; renderer boundary checks | No capacity gap found in automated checks |
| End retains video; Replay restarts it | Native end/replay tests; interrupted live monitor did not reach the end | Live Ended/Replay interaction still pending |
| Relaunch restores paused position | Installed update restored same video and 91.606433621-second position | Passed observed installed behavior |
| Bar reload does not interrupt controller | Actual full reload retained playing track; position advanced 47→50 seconds | Audible continuity not independently heard |
| Corruption and source errors preserve state | Corruption/source-gate tests; packaged missing-helper checks | Upstream variability remains a known limitation |
| Reversible install preserving user config | Temporary round-trip and real backed-up additive installation | Passed installation checks; not notarized |
| 30-minute listening without unrecoverable failure | Run interrupted after user reported inability to pause; app paused directly | Not passed; diagnose pause interaction before any new user-authorized run |

The interrupted monitor's evidence is
`.build/acceptance-evidence/listening-20261001T0820.jsonl`; session **20299 is stopped**.
Do not resume audio or restart the probe automatically. The user's reported pause
problem remains open despite successful direct CLI pause. The test runner now
handles termination by pausing playback it started, verified using an offline fake
CLI. That runner fix does not establish that the popup control is fixed.

The subsequent installed popup fix prioritizes explicit clicks over stale mouse-exit
events and removes hover dismissal. Regression checks and installed handler calls
pass open → close → reopen while playback stays paused. The user subsequently
confirmed that the popup works. This confirms popup opening, not yet transport
interaction or sustained listening. The user authorized resuming the Maro AFK
heartbeat for the redesign. The artwork/card and requested star/button/title-scroll
refinements are now installed. The heartbeat is **paused** again as of 11:17
Europe/Zurich pending visual feedback and deliberate manual playback acceptance.
Audio will not restart automatically. The later resolved native-card ticket establishes the layout evidence; physical and audible gates remain separate.

Historical observation (superseded performance baseline): preparation took about 24 seconds on the tested public video. Resolved preparation/HLS/worker tickets record the later installed improvements; this is not the current expected latency.
One earlier optimized-bundle preparation failure was not reproduced by the later
fixed-video comparison; its cause remains unknown. Do not erase that failure or
describe one successful session as guaranteed source reliability.

Historical SketchyBar capture limitations were superseded by scoped native-card inspection in the resolved transport ticket. This reconciliation run has no callable computer-use/browser tools; it performed no new visual interaction. Earlier browser policy-check failure remains unresolved and was not bypassed.

## Reconciliation and exact remaining checks — 2026-10-02

All seven polish-map implementation issues are resolved; older MARO-001/MARO-002
handoffs now link their completion evidence. No runtime change, installation,
playlist mutation or audible playback was performed in this reconciliation run.
The user's report that playlist operation works is retained as user confirmation.
Immediate create/delete list handling and failure preservation have regression
coverage; the following are not independently observed live passes:

1. Refresh the owned list and inspect for `Maro verification 2026-10-02` before any
   new creation attempt; its earlier creation outcome is unknown. Do not duplicate it.
2. On a dedicated disposable private playlist, confirm creation appears immediately.
   Open Delete playlist, verify the confirmation text, choose Cancel, and confirm
   the playlist remains. Never delete an existing user playlist for testing.
3. Only with a confirmed disposable test playlist and action-time authorization,
   verify deletion and disappearance. Compare add/reorder/occurrence-removal in
   Maro and YouTube; make a test-only YouTube edit and refresh Maro. Browser policy
   checks must succeed before that browser interaction; do not bypass them.
4. The user deliberately starts playlist playback and checks pause/resume,
   Previous/Next, automatic advance/stop-at-end, and the 30-minute listening gate.
   Fixtures, muted probes and user-reported general success do not satisfy this gate.

The coordinator has no callable computer-use/browser tools in this run. A future
run with supported tools or specific user observations can resume these checks.
The heartbeat is paused rather than repeatedly retrying unchanged blockers.
# Timeline follow-up evidence — 2026-10-02

After occurrence-identity and pending-keyboard-target fixes, all 89 tests pass
(21.504 s), release build succeeds, and a short progressive video reaches forward
and backward targets within 0.002 s, paused/muted. HLS results remain recorded
below. Native physical input and safe delivery remain outstanding.

Superseding retry evidence: after the user reopened the laptop, all 89 regression
tests passed (21.379 s). Corrected probe executable path; real HLS seek to 1260 s
and back to 30 s reached both targets exactly (0.555 s / 0.183 s), paused and
muted. Physical interaction, remaining media evidence and delivery remain open.

Latest broader run: 88 tests with 3 issues (new seek target/persistence assertions
and an existing navigation preparation timeout); rapid-resume test excluded for
isolation. Full regression gate is failing, not accepted. Long HLS disposable
probe failed at extraction, so remote seeking remains unverified. No installation.

Five focused timeline tests pass, including backward-from-ended/resume and
paused/playing playlist end behavior. Eleven native card fixtures render; paused
render visually inspected and popup lifecycle fixture passes. Full regression
is incomplete: an approved run stalled inside AVPlayerItem.currentTime during
rapid pause/resume (stack sample retained in PROGRESS). Physical input, muted
remote-media probes and delivery remain open.

The native timeline is connected to the controller. A focused AppKit test checks
its label, five-second keyboard/accessibility actions and disabled state. Physical
mouse tracking, popup reopening, visual fit and VoiceOver operation are not yet
verified; no new build has been installed.

Controller silent-audio checks now pass for latest queued target, Pause, item
reuse, stale playback identity rejection and saved position. Existing replay and
reuse checks pass. UI, full race/failure/playlist coverage, external media probes
and installed acceptance are still outstanding; the feature is not delivered.

Issue 08 range foundation compiles and its focused finite-range/gap/clamping
test passes. This is unit evidence only: interactive timeline, transport races,
muted progressive/HLS seeks, packaging and installed interaction remain pending.
