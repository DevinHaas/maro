# Redesign acceptance

Date: 2026-10-03. Application baseline: `253cb9a`.
Final production integration: `ff3abee`.

## Automated verification

- The integrated nonparallel Swift suite passes 135 tests, including shared
  request ownership, preview/submission, discovery budgets and account isolation,
  duplicate occurrence identity, queue snapshots, optimistic reorder rejection,
  ambiguous-save recovery, bounded receipt reconciliation, and stale drag expiry
  on navigation.
- The native app and CLI lifecycle check passes startup/status, favorite
  persistence, duplicate-instance handling, orderly shutdown, and paused relaunch.
  The harness isolates data, socket, SketchyBar effects, and Keychain service.
- All integrated production view corrections compile successfully.

## Native interactions

The disposable fixture uses the actual production SearchWindow/AppShellView,
local fake API responses, generated PNG artwork, and muted five-minute PCM audio.
It uses no real credentials and sends no account writes to YouTube.

Verified through native accessibility and pointer/keyboard controls:

- Library filter `CAFE` matches `Café classics`; clearing restores the library.
- Typing `jazz` opens a preview. Down focuses an actual suggestion; Escape
  dismisses it and restores the field; Return submits the query to full results.
- Reveal-more adds the next five results. Playing a result continues during
  playlist navigation; the bottom player retains the loaded video and advances.
- Playing the second occurrence of a duplicated video highlights only that
  occurrence. Pause updates its row label/icon and the bottom player together.
- A row action sheet offers Favorites, playlist destinations, occurrence removal,
  and Move to position. Moving the active duplicate updates saved order while
  retaining the captured playback occurrence and queue.
- Closing row actions restores keyboard focus to the invoking row action button.
  Playlist name editing receives focus. Delete requires a separate explicit
  confirmation; Keep playlist and Escape return safely to the detail view.
- The main playlist scroll reaches later occurrences while the library and
  player remain fixed. Unavailable rows retain actions and disable playback.
- Accessibility labels expose full titles, occurrence positions, drag guidance,
  player controls, and unavailable state despite visual truncation.

The native handle receives input in its 16-point region and starts an AppKit
dragging session. Escape cancels without a write. The automation tool posts
window events while the global system pointer stays stationary; AppKit therefore
does not deliver a native destination drop. End-to-end pointer drops and edge
autoscroll remain unverified. Keyboard moves and the reorder state machine pass
the checks above. The source uses the original mouse-down event, and its input
bridge accepts only the handle's own ancestor container to avoid intercepting
overlapping search previews.

## Visual verification

The fixture captures 1440×900 and 1024×768 logical content viewports at Retina
resolution. Screenshots preserve the reference hierarchy: near-black chrome,
separate library/content panels, small gaps, rounded corners, green playback
controls, a centered global search preview, and fixed bottom playback controls.
Playlist titles and owner/count metadata remain visible over valid artwork at
both sizes. A failed primary cover falls back to first-video artwork; a long
playlist name wraps within the header. Empty results, source failure, empty
library filtering, and Favorites have dedicated states.

The supplied four reference images remain in `assets/spotify-redesign/`.
Final acceptance screenshots are saved under `assets/spotify-redesign/acceptance/`.
There are 20 captures: Home, preview, playlist, active duplicate rows, cover
fallback, Favorites, results, empty results, source failure, and library filtering
at each size.

Representative captures: [Home](assets/spotify-redesign/acceptance/home-1440x900.png),
[preview](assets/spotify-redesign/acceptance/preview-1024x768.png),
[playlist](assets/spotify-redesign/acceptance/playlist-1440x900.png), and
[active rows](assets/spotify-redesign/acceptance/rows-1024x768.png).

## Reproducing the fixture

Build the debug Swift package, then compile `scripts/check-redesign-ui.swift`
alongside the production `Sources/MaroApp` Swift files except `MaroApp.swift`,
passing the debug `Modules` directory to `-I` and linking the `MaroCore.build/*.o`
objects. The fixture requires macOS AppKit, SwiftUI, and AVFoundation. Launch its
binary with `--capture <output-directory>` for the 20 screenshots, with
`--trace-input` to observe native event/handle/pointer coordinates, or without
arguments for disposable manual acceptance. It uses a fresh temporary state
directory on each launch.

## Scope of evidence

The test suite exercises injected source/API failures and recorded request
budgets; native interactions exercise real AppKit/SwiftUI and local playback.
Live authenticated Google playlist changes were not exercised. Accessibility
labels were inspected through the native tree; spoken VoiceOver announcements
were not listened to. Reorder announcements use AppKit's accessibility
announcement API.
