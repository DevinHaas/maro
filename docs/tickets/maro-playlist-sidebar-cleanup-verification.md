# Playlist and sidebar cleanup

Implemented on 5 October 2026 with separate agents for the sidebar and playlist detail view.

## Changes

- Compact sidebar covers are centered within the full rail width.
- App scrollbars use thin, translucent overlay thumbs. The sidebar thumb appears only while the pointer is over the sidebar, in either width mode.
- Playlist artwork is clipped to its cell, with 18-point horizontal spacing. Shared column widths align table headings and row content. Optional date and duration columns disappear at narrow widths to preserve the title area.
- Reordering handles sit at the trailing edge of each track row.
- Healthy YouTube connection text is hidden. Stale or disconnected states retain a warning and reconnect action.
- Clicking the playlist name opens renaming. A round cross beside Play opens the confirmation “Do you really want to remove the playlist?” Cancel remains the default action.

## Final verification

The complete suite ran once after integration: **146 tests passed** in 23.124 seconds. The release build and `git diff --check` passed. Visual corrections discovered during that final verification were checked with focused native renders and compilation, without repeating the full test suite.

The final native fixture captured 18 states at 760×720, 1024×768, and 1440×900, plus the rename and remove dialogs. It used local fixture data and real cached artwork; it did not perform live YouTube mutations. Inspected captures confirmed centered compact covers, hover-only sidebar thumbs, aligned wide date columns, separated artwork and titles, trailing handles, and conditional reconnection UI.

- [Wide playlist capture](/private/tmp/maro-playlist-cleanup-verification-final/playlist-1440x900.png)
- [Narrow track rows](/private/tmp/maro-playlist-cleanup-verification-final/playlist-rows-760x720.png)
- [Hovered compact sidebar](/private/tmp/maro-playlist-cleanup-verification-final/playlist-rail-hovered-1024x768.png)
- [Compact sidebar without hover](/private/tmp/maro-playlist-cleanup-verification-final/playlist-rail-1024x768.png)
- [Stale connection](/private/tmp/maro-playlist-cleanup-verification-final/playlist-stale-1024x768.png)
- [Remove confirmation](/private/tmp/maro-playlist-cleanup-verification-final/remove-playlist-dialog.png)

The prepared app is `/private/tmp/Maro-Playlist-Cleanup-Verified-20261005.app`. Its deep, strict code-signature verification passed.

## Installation

**Installed:** after the user authorized installation and paused playback, the verified build replaced `/Users/devinhasler/Applications/Maro Local/Maro.app` and reopened successfully. The installed executable matches the verified build, and deep, strict code-signature verification passed.

The same video, saved position (16996.829 seconds), and Favorites survived the restart; playback remains paused. The runtime reset volume on launch, so it was restored through the UI to approximately the previous quiet level (17%, previously 18%). Live playlists were not mutated.

The previous installation is retained at `/Users/devinhasler/Applications/Maro Local.backup-7ab31f6521a94235aeaf4f1760aab8b6` for rollback. The existing SketchyBar configuration was preserved.
