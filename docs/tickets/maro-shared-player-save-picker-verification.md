# Shared player playlist picker

The compact player and main window footer now use `SaveDestinationButton`, the same plus action and multi-playlist picker as track rows. In the players, the plus uses `AppIconButton`, matching the adjacent heart's 15-point symbol styling and 38-point button height. The compact player shares the main application's model and library, and opens the picker directly without opening the older add flow in the main window.

Verification after the changes:

- Seven playlist-saving tests passed, covering duplicate prevention, multiple destinations, failures, stale accounts, and concurrent edits.
- The release build, native player render/window checks, and whitespace check passed.
- In the installed compact player, the plus button opened the shared picker with Favorites, playlist search, playlist creation, and destination checkboxes. Selecting two destinations enabled “Add track to 2 selected playlists”; Cancel closed the picker. No live playlist writes were performed.
- The installed app's executable matches the verified build and passes deep, strict signature verification. Playback remains paused with the same video, position, Favorites, and approximately 30% volume.
- After matching the heart's button styling, focused native renders and compilation passed; the installed plus was checked again opening and closing the same picker.

[Matched player buttons](/private/tmp/maro-shared-save-matched-card-verification/long-duration.png)

Installed app: `/Users/devinhasler/Applications/Maro Local/Maro.app`.
