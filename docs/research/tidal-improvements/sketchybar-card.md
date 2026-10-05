# Compact SketchyBar player: match the current Tidal app

Research baseline: `32ccc9a57d3faf5d947a5087a46c21d027dd484e` (verified). Proposal for user review; no implementation, app/config changes, live playback, or new test execution in this investigation.

## Finding and ownership

The visible compact card is native SwiftUI `PlayerCard`, hosted in AppKit `PlayerWindow`, not a SketchyBar popup (`Sources/MaroApp/PlayerWindow.swift:42`, `:65`, `:172`). SketchyBar owns two display-aware title anchors, native title scrolling, and click routing; it explicitly sets `popup.drawing=off` (`integrations/sketchybar/plugins/maro.py:63`, `:100`, `:137`). A loaded-track click requests `player`; idle requests `search`. Do not reintroduce popup rows or another controller. Both native surfaces receive the same controller updates (`Sources/MaroApp/MaroApp.swift:75`). Wrong installed-app routing is a separate investigation/dependency.

## Current mismatch

- Card uses hardcoded `MaroAppearance` near-black, pale green, pale border and dark ink (`PlayerWindow.swift:6`, `:183`, `:240`). Title and volume knob separately hardcode gray; creator/times use platform secondary color; errors use orange (`:219`, `:235`, `:325`, `:414`, `:437`). The shared timeline already uses Tidal tokens (`Sources/MaroApp/PlaybackTimelineSlider.swift:130`).
- Width is 430pt, content-driven height, 12pt inset plus extra 12pt top space, 12pt outer radius. Layout places a 28×128 vertical-volume capsule beside 128×128 proportional cached artwork, then a 224pt metadata/control column (`PlayerWindow.swift:194`, `:240`, `:265`). Artwork uses `scaledToFit`, 9pt corners, local cached files and music-note fallback (`:200`, `:336`).
- Transport has three 36pt targets separated by 22pt, laid over a 26pt green capsule. Central circle is dark with a white symbol (`:278`). Favorite/add targets are 24pt; hide has a 24pt target. Library/Favorites are bordered text buttons. Favorites is a separate card state with selection/removal (`:205`, `:244`, `:344`).
- Fonts remain SF: scrolling title 13 semibold, creator 11, times monospaced 10, utility buttons 10. The current Tidal app also intentionally retains SF; bundled JetBrains is not the displayed default (`Sources/MaroApp/AppTypography.swift:5`; `docs/specs/tidal-checkpoint.md:10`).

## Proposed implementation scope

1. Keep the compact two-column composition, 430pt width, adaptive error/Favorites height, local artwork source/proportions and existing actions. Apply `AppDesign.Surface.panel` (Ocean), raised volume/artwork/utility surfaces (Lagoon), primary Foam text, secondary muted metadata, decorative outline, and semantic warning/error colors (`Sources/MaroApp/AppDesign.swift:9`). Use `NSColor(AppDesign.… )` for native title/volume drawing.
2. Replace the connected green transport strip with the app's three separate icon controls: neutral Previous/Next and Mint prominent Play/Pause/Replay (`Sources/MaroApp/BottomPlayerView.swift:29`; `AppDesign.swift:66`). Reuse `AppIconButton` where practical, including its 38pt targets and hover/pressed/disabled treatment; retain existing AX identifiers. Apply equivalent Tidal feedback to favorite, add, hide and utility buttons. Do not silently remove Favorites navigation.
3. Keep current SF text hierarchy and full-title scrolling/tooltip/reduced-motion behavior. No font migration, artwork fetching, new playback features, background effects, or bar-wide theming. Do not globally replace/delete `MaroAppearance`: legacy playlist UI still references it (`Sources/MaroApp/PlaylistLibrary.swift:489`, `:567`, `:636`).

## Acceptance and verification

- Native side-by-side captures show the card and current main-app player using the same palette/control treatment, including Favorites, paused/playing/ended/preparing, empty, long Unicode title, missing artwork, unknown duration, unavailable transport and error states. No clipped text or overlapping targets; artwork remains proportional.
- Preserve controller command availability, seek identity, draft cancellation on hide/track change, keyboard/AX five-second seeking, native volume semantics, labels and focus. Preserve hide/Escape/reopen, pending-open cancellation, panel ownership/non-release, nonactivating key behavior and anchor/screen clamping (`PlayerWindow.swift:53`, `:64`, `:86`, `:134`, `:157`, `:306`). Opening/closing must not prepare audio or change position/volume.
- Reuse `scripts/check-player-card.swift:16` (11 render states, no-action/volume assertions, lifecycle/anchor checks), adding empty and explicit enabled/AX observations; compile it with `AppDesign.swift` now required by the shared timeline. Use `scripts/check-timeline-ui.swift:6` and `scripts/check-style-ui.swift:70` for silent native interaction/focus evidence; run existing `Tests/MaroAppTests/PlaybackTimelineSliderTests.swift:7` regressions and offline `scripts/check-sketchybar-renderer.py`.
- Historical card evidence exists (`docs/PROGRESS.md:31`); it is not current Tidal acceptance. Record exact revision, scale, screenshots and observed limits. Main-app captures do not validate this card.

## Dependencies / review decisions

Approve separate-control transport and whether compact favorites keeps its historical star or adopts the main app's heart. Coordinate shared save interaction separately. Shared 2pt focus correction remains unfinished (`docs/specs/tidal-checkpoint.md:25`); require visible native focus evidence before acceptance. Keep runtime routing/install verification separate; do not claim it from styling fixtures.
