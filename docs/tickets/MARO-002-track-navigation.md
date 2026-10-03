# MARO-002 — Next and Previous

Status: Implementation resolved and installed; remaining live interactions tracked in ACCEPTANCE.md
Requested: 2026-10-01

The user asked about Next/Previous controls. This extends the original single-track
PRD; do not add decorative inactive controls or silently introduce autoplay.

User confirmed current search results. Navigate the complete bounded fetched list
(up to 20), including results not yet revealed by Load more. No wrapping at either
end; a loaded video outside the current results has no neighbor. Starting a new
search replaces the list; relaunch does not restore an old search session.

Navigation preserves paused/playing intent. An unavailable immediate neighbor
reports an error while preserving current playback; no silent skipping. Existing
selection generation guards prevent stale replacement. Disable navigation while
preparing a selection or while the source requires an update.
Automatic advance at end is a separate behavior, not implied by manual buttons.

Controller/CLI previous/next commands, optional snapshot capability flags, bar
notification changes and visible disabled/enabled controls are implemented.
Tests cover protocol round trips, list boundaries, unrevealed rows, pause/playing
intent, failed resolution, previous navigation and replacing the search list.

## Reconciliation — 2026-10-02

The [resolved transport follow-up](../../.scratch/maro-player-polish/issues/01-align-transport-controls.md)
replaced stacked navigation rows with accessible native side-by-side controls and
verified disabled boundary states. The search navigation implementation is complete;
do not rebuild it merely because manual listening remains open.

Later authorized [playlist behavior](../YOUTUBE_PLAYLISTS.md) adds a session-only
playlist queue: Previous/Next follow that active queue even after a new search;
playlist playback automatically advances, skips unavailable entries and stops at
the end. Selecting a search result or favorite exits the playlist queue. The
no-autoplay/search-only statements above describe the original search context,
not a prohibition on this later playlist scope. User confirmation that playlists
work is distinct from independently verified live navigation and sync.
