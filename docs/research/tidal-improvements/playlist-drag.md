# Investigate and restore native playlist drag/drop

Priority: high user-visible bug. Scope: diagnosis and future implementation ticket for review; no production fix made. Baseline: `32ccc9a57d3faf5d947a5087a46c21d027dd484e`, 2026-10-04.

## Finding and evidence limits

The user reports that drag/drop within a playlist does not work. Treat that as the defect to reproduce. This investigation establishes an outstanding native acceptance gap, **not a proven technical root cause**. No native pointer drop was performed during this read-only investigation, and no live YouTube playlist was modified.

The existing acceptance record (`docs/specs/redesign-acceptance.md`, Native interactions) says the 16-point handle received input and started an AppKit drag session, and Escape cancelled without a write. It explicitly says the previous automation posted window events while the global pointer remained stationary, preventing native destination delivery; pointer drop and edge autoscroll remained unverified. That historical automation limitation is not evidence that a physical user drag fails for the same reason. The record predates this checkpoint, so it is also not new validation of the current build.

Confirmed from source:

- `Sources/MaroApp/PlaylistDetailView.swift:59–76,219–220`: real playlist rows are in a `LazyVStack`; each row has a split-row SwiftUI `.onDrop` destination plus an 18-point end target. Only the 16×44-point native handle begins drag. Row/play/actions regions must remain distinct.
- `Sources/MaroApp/PlaylistDragHandle.swift:43–79,89–116`: the handle bridges real local mouse input only when SwiftUI's hit-tested ancestor covers the handle, then begins `NSDraggingSession` after four points using the original mouse-down event. Dismantling/moving out of a window clears timers and active payload; the drag-end callback always clears payload.
- `Sources/MaroApp/PlaylistDragHandle.swift:120–140`: autoscroll is driven by global `NSEvent.mouseLocation`, an enclosing `NSScrollView`, and a common-run-loop timer. Its edge band is 48 points; the timer scrolls 18 points per 40 ms.
- `Sources/MaroApp/PlaylistDragHandle.swift:175–204`: SwiftUI delegates require the custom pasteboard type and the library's active in-memory payload. They publish insertion feedback and call `library.drop`; they do not deserialize the pasteboard contents. The destination split is `info.location.y > 29`, matching the current nominal 58-point row.
- `Sources/MaroApp/PlaylistLibrary.swift:427–449`: payload checks bind playlist, occurrence, order revision, and account scope. The insertion boundary adjusts downward moves by one, then uses the shared `move` path. No-op and invalid drops return false without writes. Existing model tests bypass AppKit, pasteboard conversion, and SwiftUI drop delivery.
- `Sources/MaroApp/PlaylistLibrary.swift:218–260`: `move` optimistically changes occurrence order, serializes saves, preserves acknowledged order during lag/refresh failure, rolls back rejected writes, and blocks ambiguous writes until authoritative refresh. It calls `YouTubePlaylists.move` directly, not a controller reorder endpoint. Controller playback retains a captured queue independently.
- `Sources/MaroCore/YouTubePlaylists.swift:151–165`: one `PUT playlistItems?part=snippet` targets the playlist-item occurrence ID, playlist ID, resource video ID and final zero-based position. Changing this API path is not justified by the reported pointer symptom alone.
- `Sources/MaroApp/PlaylistActionsSheet.swift:61–70`: the keyboard/modal Move to position alternative uses that same `library.move` path.

No confirmed source defect was isolated that explains the reported physical drag failure. Do not label a hit-test, UTI, timer, or SwiftUI lifecycle change as the fix until the failing boundary is recorded.

## Focused hypotheses to discriminate

1. **Drag never starts:** record actual handle bounds, enabled state, content hit-test target, local down/drag events, four-point threshold, and the successful `beginDrag` payload. Check whether an overlay or current SwiftUI ancestor relationship prevents the input bridge from handling the sequence. The disabled state can also be correct: disconnected/loading/saving/unconfirmed or missing resource identity.
2. **Session starts but destination does not accept:** record advertised pasteboard types, destination validate/entered/updated/drop callbacks, proposal, native operation result and pointer coordinates. The type is the string `com.maro.playlist-occurrence`; repository search found no explicit exported/imported declaration. Whether this affects this AppKit-to-SwiftUI conversion must be observed, not presumed. Compare with a tiny native destination in a disposable harness only if callback evidence points here.
3. **Payload dies before release:** trace `viewDidMoveToWindow`, representable dismantle, drag-end, `cancelDrag`, order/account revision and selected playlist during the session. A source row in `LazyVStack` may be removed during long scrolling; cancellation is coded into teardown. Whether that happens during the reported gesture is unverified.
4. **Only long moves fail:** inspect `enclosingScrollView`, live global pointer, timer firing during drag tracking, clip/document conversion, scroll direction, end clamping and source view lifetime. Synthetic event coordinates alone do not test the implementation's global-pointer dependency.
5. **Valid drop happens but UI/save looks unsuccessful:** log insertion/final index, one recorded local PUT, optimistic order and recovery state. Separate this from source/destination failure. Verify no-op adjacent boundaries and the final end target before diagnosing index arithmetic.

Instrument a disposable fixture copy or use breakpoints first. Avoid architectural replacement of drag handling before the first missing transition is known.

## Minimal safe native reproduction

Reuse `scripts/check-redesign-ui.swift` rather than create a fake SwiftUI-only list. It already hosts the real `SearchWindow` / `AppShellView`, injects `YouTubePlaylists(token: { "disposable-local-fixture" }, send: ...)`, generates a fresh temporary state directory and muted local audio, and provides `--trace-input`.

`RedesignFixtureResponses` at lines 269–309 has 40 distinct occurrences, repeated resource video identities (`occurrence0` and `occurrence1` share one), an unavailable row, and an in-memory PUT reorder. It prints `Fixture API write`. Use only its `playlist0` / “Late night jazz” for this ticket: its other displayed playlists currently share one backing order, so it cannot prove independent cross-playlist persistence. API writes are injected and never sent to YouTube. Artwork is prefilled into cache but UI views still have HTTPS fallback loaders; describe the fixture as account-write isolated, not as a hard network-denial sandbox.

Build source from the target checkpoint into a fresh `/private/tmp` scratch directory; existing `.build` can contain relocated PCH paths. Compile the existing fixture alongside all `Sources/MaroApp/*.swift` except `MaroApp.swift`, using the scratch build's debug Modules and MaroCore object files (see `docs/specs/redesign-acceptance.md`, Reproducing the fixture). Launch with `--trace-input`. Do not launch the installed account-backed Maro app, import credentials, or create/reorder a real YouTube playlist for reproduction.

1. Show the disposable native window at 1440×900; open “Late night jazz” and wait for loading to finish. Record commit, macOS/build, window size and initial occurrence order.
2. Use a physical mouse/trackpad or a supported tool that demonstrably moves the actual system pointer. Press the six-dot handle for `occurrence1`, move beyond four points, hover the top half of a different visible row, then release.
3. Record drag image, insertion marker, source/destination callback chronology, final native operation, local PUT count/body and resulting occurrence order. Save a short recording/screenshots plus trace. One valid move must produce exactly one local PUT.
4. Repeat upward and downward middle moves, first position, last position, and long moves by dwelling at both viewport edges. Verify the source can leave the visible/lazy region and still complete.
5. Repeat at 1024×768 and with sidebar/player visible; only the playlist scroll should move. Reset by relaunching the disposable fixture when useful.
6. If the automation pointer remains fixed or no destination callback can be produced, stop claiming end-to-end verification. Leave native pointer/edge acceptance open for physical input, with the exact tool limitation recorded.

## Implementation targets after user review

Primary: `PlaylistDragHandle.swift`, `PlaylistDragPayload.swift`, and `PlaylistDetailView.swift` only as supported by the reproduced failing boundary. Preserve independent play/actions controls, occurrence identity, saved-order semantics and keyboard fallback. `PlaylistLibrary.swift` changes should be driven by a demonstrated state/lifecycle failure, preserving existing write/recovery guarantees. Touch the API layer only if a locally recorded request exposes a separate error.

Fixture/verification: extend the isolated native fixture with callback/write traces and deterministic save modes as needed; update `PlaylistReorderTests.swift` and `PlaylistReorderAPITests.swift` for behavior gaps. Do not replace physical native drop evidence with direct `library.drop` calls.

## Acceptance and regression matrix

| Area | Required observable outcome |
| --- | --- |
| Native pointer/drop | Handle drag reaches native destination and changes first/last/middle positions in both directions; correct image and insertion marker; one occurrence moved, one local PUT; visually confirmed after refresh and reopen. |
| Native edge scrolling | Both top and bottom edges scroll the playlist during a real session, remain bounded, allow dropping after the source leaves the viewport, and stop immediately after drop/cancel. Library/player stay fixed. |
| Duplicate identity | Move the second of two identical-video occurrences; only its occurrence ID changes position. If it was active, highlight and captured playback queue remain on the same occurrence. |
| Keyboard parity | Tab to Actions, reach Move to position, submit with keyboard, observe shared save/recovery behavior, Escape dismisses, focus returns to invoking Actions. Announce destination and outcome. |
| No-op/cancellation | Own upper and lower adjacent insertion boundaries, Escape, release outside list, invalid/cross-playlist data and invalid index produce zero writes; clear marker/payload/timer; a subsequent valid drag works. Play/actions do not start drag. |
| Stale/lifecycle | Navigation away/back, close window/source teardown, account switch/disconnect, external order/membership changes invalidate stale payload; no phantom save. |
| Serialization | Loading, pending save and unconfirmed outcome prevent a second move; handle feedback reflects disabled status. |
| Save recovery | Confirmed save + lagging refresh retains acknowledged order; failed refresh retains it with recovery action; definitive 4xx rolls back and only explicit retry writes; timeout/5xx/unreadable success marks unconfirmed and never automatically repeats; failed recovery remains blocked; successful authoritative refresh resolves it. |
| External changes | Membership/order changes reconcile by occurrence IDs without resurrecting removed duplicates; expired receipt accepts remote authoritative order. |
| API contract | One request carries moved occurrence ID, correct playlist/resource ID and zero-based position; metadata untouched; authentication/preflight failure transmits nothing. |

Dependency: user review of the investigation/ticket, then a new specification/implementation session. Native GUI execution and real pointer movement are required to close this bug; model tests and screenshots alone cannot satisfy that acceptance. The existing captured-queue/save semantics are dependencies to preserve, not redesign work.

## Verification in this investigation

Fresh scratch build and focused tests passed: **15 tests**, including four parameterized HTTP outcome cases. Coverage includes occurrence moves, insertion/no-op/cancelled/stale payloads, navigation/account invalidation, save/retry/refresh reconciliation and API request identity. Full output: `/private/tmp/maro-improvements-drag-tests.log`.

The initial `--skip-build` attempt found zero matching tests (not a pass); a rebuild in the repository's inherited `.build` failed because its PCH contained a different workspace path. Retrying with an isolated scratch directory and writable module caches succeeded, without cleaning or editing production source/config:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/maro-improvements-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/maro-improvements-swift-cache \
swift test --disable-sandbox --scratch-path /private/tmp/maro-improvements-drag-build \
  --no-parallel --filter 'dragUsesOccurrence|navigationAndDisconnectInvalidateCapturedDrag|applicationHomeAndBackRejectCapturedDrag|occurrenceMove|priorExternalOrder|ambiguousMove|rejectedMove|acknowledgedMove|failedExplicitRefresh|refreshFromHome|confirmedRemovalAfterMove|unreadableMoveResponse|unavailableOccurrenceMove|moveResponseDistinguishes|expiredTokenRejects'
```

Read-only source/doc inspection is complete. No native pointer, drop, edge-autoscroll or live account writes were exercised in this investigation. Passing these model/API checks narrows the next investigation; it does not establish that physical drag works.
