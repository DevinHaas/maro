# Search spacing and shared scrollbars — 2026-10-05

Search preview artwork is clipped to its 48-point frame, with a 16-point gap before text and more row padding. Full results use the same spacing and shared column dimensions for headings, rows, and loading skeletons. Long duration labels stay on one line.

The existing subtle native overlay scroller now covers search previews, results, Favorites, playlist destination lists, save feedback, and compact-player Favorites. Sidebar indicators remain hover-only. Frame observers reapply styling when SwiftUI recreates or retiles filtered content; selected scroll axes and intentionally hidden indicators are preserved.

Final verification:

- Release build passed; 12 focused search and playlist-save regression tests passed.
- Fifteen native search states at 760×720, 1024×768, and 1440×900 verify overlay styling, shared scroller classes, sidebar hover, and filtering. Captures: `/private/tmp/maro-search-spacing-verification`.
- Five native picker states verify opening, selection, filtering, saving, and overflow. Captures: `/private/tmp/maro-search-spacing-picker-final-queue-renders`. The fixture waits for queued AppKit layout work before inspecting scrollers.
- Compact-player Favorites verifies the shared scroller; native volume forwarding and window toggle/hide/reopen/Escape checks remain included. The fixture injects a local playlist API to avoid real account access. Captures: `/private/tmp/maro-search-scrollbar-card-verification`.

Standalone bundle: `/private/tmp/Maro-Search-Spacing-Scrollbars-Verified-20261005.app`. Installed after the user authorized installation into `/Users/devinhasler/Applications/Maro Local/Maro.app`. The installed executable matches the verified bundle and passes strict deep signature verification. The same track remains paused at 2300.325865408 seconds; volume was restored to approximately 39% (within one percentage point of its previous level).
