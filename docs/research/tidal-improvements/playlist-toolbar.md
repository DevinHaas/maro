# Playlist search and per-track saving — research brief

Read-only review at `32ccc9a57d3faf5d947a5087a46c21d027dd484e`. Source paths below are repository-relative. Inspected the supplied `docs/tickets/assets/tidal-improvements/playlist-toolbar-reference.png` and shared `home-save.md`. No implementation/configuration/user-data changes; tests not run.

## Current facts

- `Sources/MaroApp/PlaylistDetailView.swift:31`: toolbar contains a 62-point circular Play button, playlist-actions ellipsis, spacer, busy indicator, and static “Saved order”/list icon. There is no playlist search field, sort menu, row selection, or toolbar save subject. Ellipsis opens rename/delete (`PlaylistActionsSheet.swift:84`); preserve that entry point. Screenshot’s extra controls do not establish shuffle, download, collaboration, or device features for Maro.
- `PlaylistDetailView.swift:56`: rows enumerate the complete `library.items`; displayed position, drag insertion, and row identity are respectively full-array index + 1, full-array index, and occurrence ID. Rows already have independent play, drag, and actions hit regions. `PlaylistTrackRow` at `:198` exposes occurrence-specific labels and hover/focus visuals. Sheet dismissal restores the invoking control’s focus at `:109`.
- `Sources/MaroApp/PlaylistLibrary.swift:264` resolves row playback by occurrence ID to its index in the full array; `:306` captures that full queue. Toolbar Play starts index zero. Filtering must not replace `items` or silently change the queue contract.
- `Sources/MaroCore/YouTubePlaylists.swift:77,168` loads all pages before returning, with 50 items per API page and repeat-token protection. Detail `items` is complete after successful loading; `PlaylistLibrary.swift:413` separately caps the recommendation cache to 50 items/12 playlists. Never search the truncated cache. Failed refresh can retain stale detail data, already labeled in the UI.
- `YouTubePlaylists.swift:20` models repeated videos as distinct occurrence IDs. API add (`:128`) rejects a matching resource video ID across all destination pages, including unavailable entries. Existing duplicates must remain distinct during search/play/reorder.
- Existing save operations are **single-video**: `PlaylistActionsSheet.swift:41` offers local Favorites and another playlist for its explicit item. Destinations exclude the source playlist (`:14`), and unavailable items have no save action. Favorites hold at most 20 videos. No favorite-playlist model or bulk-copy operation exists.

## Proposed interaction and dependencies

Use the screenshot’s hierarchy: existing round Play left, retained ellipsis, flexible space, search at right, existing saved-order indicator. The user clarified that there must be no playlist-level plus/save button. Keep Maro’s styling and supported actions. At narrow widths, expand search within available toolbar space without squeezing Play or dropping ellipsis. Native keyboard/VoiceOver labels and visible focus apply to every icon.

Share anchored destination-popover content, save result state, and eligibility with the Home save work (`home-save.md`), using an individual track's plus/save control. Each invocation binds directly to that row's video; no separate selection mode is needed. Current own playlists are discovered via `mine=true`; broader collaborative/writable discovery is separate scope. Respect busy/unconfirmed-write guards and report outcomes explicitly instead of parsing `library.status` or silently losing a click.

**Confirmed save scope:** individual tracks only. Keep the target explicit through the row's video and accessible label. Unavailable tracks cannot be saved; changed/deleted rows or an account switch invalidate stale presentation state. Retain existing source-playlist exclusion and single-video duplicate/Favorites-capacity behavior. Playlist-level saving, batch operations, bookmarks and a new selection model are excluded.

For search, recommend local case/diacritic-insensitive title-or-creator matching, trimmed whitespace, empty query restores all occurrences, and a clear button. Derive `(originalIndex, item)` from the full array, retaining original numbering and duplicate occurrences. Distinguish “No matches” from an empty playlist. Reset query when changing playlists. Filtering should not alter header total, playback queue, or saved order.

Recommend disabling native drag sources and drop targets while a nonempty query is active, canceling an existing drag when query changes. `PlaylistLibrary.swift:217,442` and `PlaylistDragHandle.swift:175` require full-order indices; filtered indices would move the wrong location. Keep the sheet’s explicit “Move to position” usable against the complete array, labeled as saved-order position. Product review may instead choose to disable all reorder while filtering.

## Acceptance / verification seams

- Search finds title/creator matches beyond page one; duplicates retain distinct IDs/original positions; clearing restores exact order. Cover empty, no-match, unavailable, busy, stale, playlist-switch and account-switch states.
- Filtered row playback starts the requested occurrence in the existing full queue. Toolbar Play keeps its current whole-playlist contract.
- No filtered drag/write is possible; keyboard move uses full-array positions. Existing rename/delete and action-sheet focus return remain reachable.
- Toolbar has no plus/save button. Each individual track save control follows shared Home save rules, targets that exact video, and never triggers playback or changes queue/order.
- Extend injected API/library fixtures in `Tests/MaroAppTests/PlaylistLibraryTests.swift:19`, reorder coverage in `PlaylistReorderTests.swift:149`, and pagination/duplicate fixtures in `Tests/MaroCoreTests/PlaylistTests.swift:50`. Extract a small pure filter projection for meaningful matching/index tests. Manually verify native popover anchoring, keyboard/Escape/focus return, VoiceOver, and 1024/1440-width layouts.

Review sequence remains user review → approved specification → implementation in a new session. Track-only saving is confirmed; filtered-reorder policy remains for review. Shared save UI is a dependency for individual track controls, not for playlist search itself.
