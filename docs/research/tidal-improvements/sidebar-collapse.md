# Library collapse control — research for review

**Requested outcome:** Remove the library toggle from the global header. Put collapse at the left of “Your Library,” visually revealed when the sidebar is hovered. Research only; implementation follows user review, an agreed spec, and a new implementation session.

## Evidence at checkpoint `32ccc9a`

- `Sources/MaroApp/AppShellView.swift:36`: global header currently owns the sole Show/Hide library toggle.
- `Sources/MaroApp/AppShellView.swift:13`: collapsed state removes `LibrarySidebar` completely; merely relocating the toggle would strand pointer users. Sidebar width is 280 points below 1200, otherwise 320 (`:14`).
- `Sources/MaroApp/AppShellView.swift:60`: current header contains a books icon/“Your Library” label, Create and Refresh. Adding a fourth standalone slot risks crowding at 280 points. The filter is independently keyboard focused (`:57`, `:68`).
- `Sources/MaroApp/AppDesign.swift:78`: shared icon buttons supply native Button semantics, 38×38 layout, circular content shape, hover styling, help text and accessible title. The style does not explicitly draw keyboard focus (`:66`).
- `Sources/MaroApp/ApplicationModel.swift:20`: collapse state is session state, initially expanded. `offerAdd` explicitly expands the library (`:215`).
- `Sources/MaroApp/SearchWindow.swift:20`: normal minimum window is 760×560; presentation can lower this on small screens (`:36`). Existing `Tests/MaroAppTests/SearchWindowTests.swift:5` covers window placement, not sidebar layout or focus.

## Recommended scope and interaction

1. Replace the leading books glyph with a reserved 38×38 slot. At rest it shows the decorative library glyph; hovering anywhere inside the sidebar replaces that glyph with the collapse button. Keep title/actions stationary. The button precedes the title and retains a full 38×38 target; explicitly verify the clickable area rather than assuming the existing circular shape fills it. Use `sidebar.left` with tooltip/accessibility label “Hide library.”
2. Keep a real button reachable by keyboard and assistive technology even while its visual chrome is hidden. Reveal it on button keyboard focus and accessibility focus, with an explicit visible focus indicator. Never hide/remove/disable it based only on hover. Decorative books glyph must not produce a duplicate accessibility element. Hover over filter, list, footer and empty sidebar space must all reveal it; leaving the sidebar hides it only when it is not focused.
3. When collapsed, replace the sidebar with a **46-point left rail** in the body HStack, using existing surface/radius/border. A permanently visible 38×38 “Show library” button sits at its top, aligned with the expanded header control; it must not require hover. Keep the global header free of this control in both states. This retains spatial continuity and avoids covering route content.
4. Move keyboard/accessibility focus to Show library after keyboard/AX collapse, and back to Hide library after reopening. Avoid forced focus changes for pointer use. Preserve route, filter and playback; preserve `offerAdd` expansion. Keep existing session-only state and width breakpoint. No new persistence, auto-collapse, navigation shortcut or generic icon-button redesign is needed.

## Acceptance and native verification

- In a native running build, verify collapse/reopen on Home, Search, Favorites and playlist routes; no navigation or playback changes, no filter loss, no header movement on hover.
- Expanded: pointer anywhere in sidebar reveals collapse; outside hides it. Keyboard Tab/Shift-Tab and VoiceOver can discover and activate it without pointer hover; focus remains visible and follows the replacement control. Space/Return behavior should follow native button conventions.
- Collapsed: reopen remains visible, enabled and accessible while disconnected, busy and signing in. Reopening restores the same library state. Add-to-playlist still expands.
- Inspect 1440×900, 1199/1200 width boundary, 760×560, and the smaller-screen presentation case. Title/Create/Refresh must fit without truncating actionable targets. Compact the redundant glyph rather than shrinking targets; review any remaining header crowding with the account workstream.
- Run existing app tests. Add only behavior tests if focus/state logic is extracted; hover/AX claims require native interaction checks, not source-string tests. Research did not execute these checks.

## Review decisions and dependencies

Approve the collapsed rail, books-to-collapse replacement, and the keyboard/AX visibility exception to “hover only.” Account/header and footer work share `AppShellView.swift`; agree one implementation owner or sequence patches. Preserve global header spacing after removing its toggle; make sidebar hover wrap the entire redesigned footer too. Footer removal must not remove the rail or change its availability. Broader save-destination work should retain or explicitly revise `offerAdd` expansion.
