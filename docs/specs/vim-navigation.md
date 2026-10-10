# Vim navigation

## Problem Statement

Maro is intended primarily for developers who want to browse and control music without repeatedly reaching for the mouse. Its existing keyboard behavior covers search and individual controls, but it does not provide consistent directional navigation across the application. Sequential tabbing alone is cumbersome when moving among the sidebar, track lists, album rows, and bottom player.

Users need a predictable way to reach the next control in a chosen direction without inadvertently starting playback, losing their place in a list, or interrupting text entry.

## Solution

Add optional Vim navigation using `h` for left, `j` for down, `k` for up, and `l` for right. Each movement places keyboard focus on an eligible navigation target and displays a visible highlight. Return activates the focused control through its normal action.

Movement favors alignment within rows and columns over pure proximity. A navigation region continues scrolling to reveal further targets before movement crosses its actual boundary. An active modal contains navigation, and text editing retains normal letter input. Users can switch Vim navigation on or off.

## User Stories

1. As a developer using Maro, I want to enable Vim navigation, so that I can browse music using familiar keys.
2. As a developer using Maro, I want to disable Vim navigation, so that I can choose the keyboard behavior that suits me.
3. As a keyboard user, I want `h` to move focus left, so that movement matches the visible arrangement of controls.
4. As a keyboard user, I want `j` to move focus down, so that I can progress through vertical track lists.
5. As a keyboard user, I want `k` to move focus up, so that I can return to preceding tracks or controls.
6. As a keyboard user, I want `l` to move focus right, so that I can navigate horizontal album rows and groups of actions.
7. As a keyboard user, I want a visible highlight on the focused navigation target, so that I always know which control will receive activation.
8. As a music listener, I want movement to change focus without activating the destination, so that browsing does not unexpectedly start or interrupt playback.
9. As a keyboard user, I want Return to activate the focused control, so that I can use the application without clicking.
10. As a keyboard user, I want vertical movement to favor the corresponding control on the next row, so that a nearby diagonal action does not unexpectedly divert me.
11. As a keyboard user, I want horizontal movement to favor controls aligned with the current row, so that navigation follows the visible layout.
12. As a keyboard user, I want movement to select a sensible nearby target when exact alignment is unavailable, so that irregular layouts remain navigable.
13. As a listener browsing a track list, I want downward movement to reveal additional tracks, so that I can continue beyond the current viewport.
14. As a listener browsing a track list, I want upward movement to reveal earlier tracks, so that I can retrace my navigation.
15. As a listener browsing an album row, I want horizontal movement to reveal further albums, so that clipping does not make them unreachable.
16. As a keyboard user, I want navigation to stay within the current scrollable region while more targets exist in that direction, so that focus does not prematurely jump to unrelated controls.
17. As a keyboard user, I want movement to reach another eligible region at the current region's actual end, so that I can navigate between the sidebar, content, and player.
18. As a user entering a search query, I want `h`, `j`, `k`, and `l` to remain ordinary letters while editing, so that navigation does not corrupt my query.
19. As a user editing any text field, I want Vim navigation to yield to editing, so that names and other text can be entered normally.
20. As a search user, I want existing arrow, Return, and Escape behavior to keep working, so that search remains familiar.
21. As a listener adjusting the timeline, I want its existing arrow-key seeking to keep working, so that directional navigation does not replace playback controls.
22. As a user of a modal dialog, I want navigation to remain inside the active modal, so that background actions cannot receive focus or activation.
23. As a keyboard user, I want inactive pages and disabled controls to be excluded, so that every navigation target is available in the current interface.
24. As a keyboard user, I want navigation to account for clipping and overlapping presentations, so that focus does not land on a control I cannot see or operate.
25. As a user resizing the window, I want movement to follow the current layout, so that targets remain predictable after the interface changes.
26. As a user browsing changing search results or playlists, I want navigation to use the current controls, so that removed or rearranged content does not leave stale destinations.
27. As a keyboard user, I want normal Tab navigation and existing application shortcuts to remain usable, so that Vim navigation complements the application's keyboard support.
28. As a user with multiple windows or an inactive Maro window, I want navigation keys to affect only the active applicable window, so that unrelated input is not intercepted.

## Implementation Decisions

- Use the glossary meanings of Vim navigation, navigation target, and navigation region. Target eligibility is broader than finding click handlers: controls must participate in keyboard focus and expose their normal activation behavior.
- Integrate with the native SwiftUI/AppKit application and its existing focus system. Keep the macOS 13 deployment target and existing dependency set.
- Extend the application shell, navigable content, and existing keyboard routing only as needed to provide shared directional navigation. The sidebar, content lists and album rows, persistent player, and active dialogs are relevant navigation regions.
- Represent each participating target with a stable identity and its current bounding rectangle. Compare rectangles in a shared coordinate space and account for scroll clipping and presentation visibility.
- For each movement, determine the active window and presentation, restrict candidates to the applicable region, filter by direction, and rank by row/column alignment followed by rectangle distance. The score depends on the current target, candidate, and direction; it is not a fixed value attached to a target.
- Begin with a linear candidate scan per navigation request. A persistent adjacency graph is unnecessary for the first implementation and would require invalidation after layout and content changes. Introduce caching only if measured performance warrants it.
- Explicitly exclude inactive routes: Home and Search remain mounted when hidden, so view existence and measured geometry do not establish eligibility.
- Handle scrolling as part of navigation. At the visible edge, reveal further targets in the requested direction before considering another region. Support targets that have not yet been materialized by lazy content; an empty visible candidate set does not establish the region's actual end.
- Confine navigation to an active modal. Apply presentation eligibility to popovers as well, so covered background controls cannot be chosen merely because their rectangles are nearby.
- Use real keyboard focus and a visible indicator. Movement never dispatches a click or starts playback; Return invokes the focused control's existing action.
- Provide an accessible way to switch Vim navigation on or off. Letter routing must yield to active text editing and must not consume existing modified application shortcuts.
- Integrate with the search field's existing AppKit keyboard handling and preserve its established navigation and submission semantics. Preserve the timeline's arrow-key seeking and standard control behavior.
- No backend, playback protocol, or data-schema change is required by this feature.

## Testing Decisions

- Confirmed primary seam: one hosted application-window integration seam. Deliver keyboard input through the application's actual event routing and observe focus, activation outcomes, text entry, and scrolling through the rendered interface and existing accessibility observations.
- Prefer this seam because target selection alone cannot demonstrate correct first-responder routing, exclusion of hidden pages, clipping, modal containment, or scroll behavior. Avoid exposing internal adjacency data or scoring weights solely for tests.
- Use deterministic music and playlist data. The existing hosted SwiftUI window checks provide prior art for rendering the shell and player and collecting accessibility geometry. They are a starting point for a new keyboard integration check, not evidence that full keyboard injection coverage already exists.
- Existing application tests for search preview focus, Return activation, query submission, and dialog behavior provide regression coverage and fixture patterns. Reuse that coverage instead of duplicating every existing assertion.
- Verify movement in all four directions, visible focus, and separate Return activation. Assert that movement does not call the playback action, then assert that activation performs the focused control's normal action.
- Verify alignment with an adversarial layout containing a closer diagonal target and the corresponding action in the next row. Assert the observable destination rather than a numerical score.
- Verify repeated movement through a vertically clipped list and a horizontal album row. Include content beyond the viewport and lazily realized targets; assert that scrolling reveals further targets before focus leaves the region.
- Verify cross-region navigation at a genuine region end. Do not use the last currently rendered item as a substitute for the actual content boundary.
- Verify text entry using each of the four navigation letters, disabled Vim navigation, normal Tab operation, search Return/Escape/arrows, and timeline arrow-key seeking.
- Verify active-modal containment and exclusion of inactive mounted pages, disabled controls, and controls covered by the active presentation.
- Verify navigation after window resizing, scrolling, and changing content. Assert that focus reaches a current eligible target rather than a stale or hidden one.
- Verify that events in another window or while Maro is inactive do not move focus in the application window under test.
- Run existing application tests and the focused integration check when implemented. This specification itself adds no implementation or executable tests.

## Out of Scope

- A complete catalogue of application shortcuts beyond directional navigation and activation.
- Vim editing modes, command syntax, macros, key sequences, or user-defined key mappings.
- Automatically activating a target as a side effect of movement.
- A persistent navigation graph, spatial indexing dependency, or speculative performance infrastructure.
- Replacing existing search interaction, playback commands, or standard keyboard accessibility behavior.
- Changing playback services, music storage, or the application's minimum supported macOS version.

## Further Notes

The user agreed to focus-only movement with Return activation, switchable letter navigation that yields to typing, alignment-biased target selection, scrolling before region transitions, and modal containment on 2026-10-05.

Exact scoring weights and tie-breaking, initial focus when no eligible target is focused, focus recovery when a target disappears, behavior when no directional destination exists, and the toggle's location/default/persistence were not settled in the discussion. Choose minimal predictable behavior during implementation and document it with the observable acceptance scenarios; do not present these details as prior user decisions. Do not add wraparound navigation implicitly.

The graph-free scan is inexpensive to reverse and adds no architectural lock-in, so a separate ADR is unnecessary at this stage.

The user confirmed the hosted application-window testing seam. Publish this specification to GitHub Issues in DevinHaas/maro with the existing ready-for-agent label.

## Implementation Choices

These fill the gaps listed above. They are implementation defaults, not prior user decisions.

- **Toggle:** a keyboard icon button in the top bar, beside the account button ("Turn on/off Vim navigation", value On/Off). It is on by default and persists in user defaults (`MaroVimNavigation`). When it is off, targets drop out of the Tab order they gained and letters pass through.
- **Visible focus:** like CSS `:focus-visible`, the highlight shows after h/j/k/l, Tab or Return focus changes and hides after a click. Return activates only a visibly focused target.
- **Initial focus:** when nothing is visibly focused (first use, after a click, or after the focused target disappeared), the first h/j/k/l focuses the first visible content target in reading order. Hidden focus, such as SwiftUI's automatic focus when the window opens, is ignored.
- **Scoring:** a candidate must lie beyond the origin's edge in the requested direction. Candidates overlapping the origin across the movement axis win. Among those, the nearest row or column wins (8-point tolerance), then the closest centre. Unaligned candidates are used inside the origin's own region before it scrolls, and anywhere visible as a last resort. Ties break by position, so the result is deterministic.
- **Regions:** top bar, sidebar (header and scrolling list), content (per route; Home album rows are nested horizontal regions), player and each sheet or popover. Movement widens from the innermost region outwards, scrolling each scroll region by half a viewport until it reaches the region's actual end.
- **Recovery and dead ends:** if the focused target disappears (content change, route change, lazy row reuse), the next key starts from the initial target. With no destination, focus stays put; there is no wraparound.
- **Presentations:** an open sheet or popover owns navigation. Closing it resumes the focus held before it opened.
- **Search preview:** while the global search preview is open, its own arrow/Return/Escape handling owns the keyboard.

Acceptance scenarios live in `scripts/check-vim-navigation.swift` (hosted window, real key events, accessibility focus and rendered highlight).
