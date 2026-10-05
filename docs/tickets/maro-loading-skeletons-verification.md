# Loading skeletons

Implemented by the requested new subagent on 5 October 2026.

Audio preparation now uses a restrained animated skeleton in the timeline and time-label slots, replacing “Preparing audio…” without changing the compact player's height. Known track artwork and metadata stay visible; a first track with unavailable metadata gets artwork and text placeholders. Buffering uses the same treatment when its timeline is unavailable.

Shared row/card skeletons also cover initial search results, further search pages, global search suggestions, Home recommendations, and initial playlist track reads. Loaded content and existing transport, error, retry, save, and reorder behavior remain. Playlist skeletons are tied to a scoped track-read state rather than generic mutations.

The shimmer sweeps over 1.8 seconds at up to 30 frames per second. Reduce Motion uses stationary placeholders. Placeholder groups expose accessible loading labels and progress values without adding focus targets.

## Final verification

- Full Swift suite: **146 tests passed** in 24.207 seconds after integration.
- Release build, offline extractor pagination/protocol checks, and whitespace checks passed.
- Native compact-player fixture: **17 states passed**, including preparation, first-track preparation, buffering, errors, shared save controls, and long durations.
- Two frames 400 milliseconds apart differ during shimmer and match exactly with Reduce Motion. Preparation and paused player dimensions match.
- Seven native surface captures passed: initial search, additional search pages, playlist tracks, Home suggestions, global preview, and both known/unknown main-player loading states. Completing a delayed playlist read cleared its scoped loading state.
- Fixtures used local delayed responses and performed no audio preparation or live playlist writes.

## Captures

- [Preparing known track](/private/tmp/maro-loading-card-verification/preparing.png)
- [Preparing first track](/private/tmp/maro-loading-card-verification/preparing-first-track.png)
- [Reduced Motion](/private/tmp/maro-loading-card-verification/preparing-reduced-motion.png)
- [Search fetching](/private/tmp/maro-loading-surface-verification/search.png)
- [Playlist fetching](/private/tmp/maro-loading-surface-verification/playlist.png)
- [Home suggestions](/private/tmp/maro-loading-surface-verification/home.png)
- [Global search suggestions](/private/tmp/maro-loading-surface-verification/preview.png)

Verified app bundle: `/private/tmp/Maro-Loading-Skeletons-20261005.app`.

Installed at `/Users/devinhasler/Applications/Maro Local/Maro.app` after playback was paused. The updated app reopened with the saved video and position intact. Installation preserves a rollback copy and leaves SketchyBar configuration unchanged.
