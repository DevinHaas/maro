# Larger icon-only account menu

Research checkpoint: `32ccc9a57d3faf5d947a5087a46c21d027dd484e`, `/Users/devinhasler/projects/maro`. Read-only production research; implementation and visual acceptance remain for a subsequent session after review. Existing unrelated working-tree changes were left alone.

## Intended result

Make the top-right account control visibly larger, show only its account icon, and retain the native menu and every existing action. Proposed starting dimensions for review: **36-point account symbol, 44 × 44-point interactive target**, vertically centered in the existing 64-point bar. These are design proposals, not measured current dimensions or a claim about a mandatory macOS standard.

## Source findings

- `Sources/MaroApp/AppShellView.swift:41`: the control is a SwiftUI `Menu`, not a button that navigates to a profile screen.
- `Sources/MaroApp/AppShellView.swift:48`: its label is already image-only (`person.crop.circle.fill`), at a 28-point font size in `AppDesign.muted`. There is no explicit arrow image or text label to remove.
- `Sources/MaroApp/AppShellView.swift:49`: it uses `.menuStyle(.borderlessButton).fixedSize().frame(width: 40).padding(.trailing, 12)` and accessibility label `YouTube account`. It declares no explicit height, content shape, help text, custom keyboard handler, or hover state. The observed arrow is attributable to native menu styling; source alone does not measure the actual clickable area.
- `Sources/MaroApp/AppShellView.swift:11` fixes the top bar at 64 points; `:33` sets HStack spacing to 12; `:39` caps search width at 520; `:26` adds 8-point horizontal shell padding. Enlarging this control must fit the bar and avoid crowding search at narrow widths.
- `Sources/MaroApp/AppDesign.swift:78` defines neighboring `AppIconButton` controls. They have 38 × 38-point labels (`:88`), circular content shapes (`:89`), and help/accessibility labels (`:91`). Their hover/pressed treatments use existing design colors (`:66`). The account menu is a separate control, so changing the shared icon-button component is unnecessary.
- `Package.swift:6` targets macOS 13 or newer. The installed Apple SwiftUI SDK interface declares `menuIndicator(_:)` available from macOS 12 (`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface:20692`). No deployment-target increase is needed for `.menuIndicator(.hidden)`.
- `Sources/MaroApp/SearchWindow.swift:12` starts at 1440 × 900; `:20` sets a 760 × 560 minimum window size, further constrained to available screen size at `:36`. Minimum window dimensions are not equivalent to content dimensions because of window chrome.

Apple documents `.menuIndicator(.hidden)` as the supported way to hide menu indicators: [menuIndicator(_:)](https://developer.apple.com/documentation/swiftui/view/menuindicator(_:)). The older `BorderlessButtonMenuStyle(showsMenuIndicator:)` initializer is deprecated in favor of that modifier: [Apple initializer documentation](https://developer.apple.com/documentation/swiftui/borderlessbuttonmenustyle/init(showsmenuindicator:)).

## Existing menu contract

Source: `Sources/MaroApp/AppShellView.swift:42` through `:47`. Preserve order, labels, closures, and disabled conditions.

| Item | Visibility | Enabled condition | Existing callback |
| --- | --- | --- | --- |
| Create private playlist… | Always | connected and not busy | `library.create()` |
| Import Google credentials… | Always | not busy | `library.importCredentials()` |
| Connect YouTube | Disconnected only | configured and not busy | `library.connect()` |
| Reconnect YouTube | Connected only | no explicit menu-item disable condition | `library.connect()` |
| Disconnect on this Mac | Connected only | no explicit menu-item disable condition | `library.disconnect()` |

The entire top-right menu is not disabled while busy. Reconnect currently remains visually enabled while busy but its operation is gated by `run` (`Sources/MaroApp/PlaylistLibrary.swift:459`); Disconnect remains callable (`:97`). Preserve these semantics for this cosmetic ticket instead of silently normalizing them to another account menu.

`PlaylistLibraryView` contains a different `Menu("Account")` with whole-menu busy disabling (`Sources/MaroApp/PlaylistLibrary.swift:538`); it is not the requested top-bar control and should not be used as the behavior template.

State details: `PlaylistLibrary` publishes `busy`, `connected`, and `configured` (`:11`–`:13`), loads them from Keychain-backed account state (`:53`–`:57`), makes credentials import configured-but-disconnected (`:74`), and tracks browser sign-in (`:85`). Account connection means a stored refresh token, not an independently verified live session (`Sources/MaroCore/YouTubeAccount.swift:19`). A generic account icon is therefore sufficient for this request; do not invent an avatar, new status badge, or account identity data dependency. Sign-in cancellation, progress, and retry are already in the sidebar (`Sources/MaroApp/AppShellView.swift:99`–`:103`).

## Proposed implementation boundary

Limit production changes to the top-bar Menu label/modifiers in `Sources/MaroApp/AppShellView.swift`. Keep the native `Menu` and its existing content. Add `.menuIndicator(.hidden)`, increase the symbol to 36 points, and establish a real 44 × 44-point hit target through the menu label/style. Retain its existing placement, muted token, and accessibility name. Adding `.help("YouTube account")` would match neighboring icon controls and improve discoverability.

Do not assume an outer `.frame` enlarges native interaction: the current fixed-size menu plus outer width illustrates why label size, AX frame, and click area must be checked separately. Verify the exact modifier arrangement in the native fixture before accepting it. Prefer a full rectangular 44 × 44 target around the circular glyph. Retain native focus/pressed behavior; if custom visual feedback becomes necessary, use existing design tokens and keep menu semantics.

## Acceptance criteria

1. The top-right control visibly uses the larger approved icon size and shows no arrow, visible text, extra control, or leftover arrow spacing.
2. The icon stays vertically centered, unclipped, and comfortably inset in the 64-point bar at normal, 1024-wide, and minimum supported window sizes; search and other controls remain usable with library both shown and hidden.
3. Clicking the icon or its surrounding target opens the same native menu. Validate the full proposed 44 × 44-point target, including near-edge points; do not count trailing layout padding as interactive area.
4. Unconfigured/disconnected, configured/disconnected, connected, and busy/signing-in states expose exactly the labels and disabled conditions in the table. Opening and dismissing the menu alone performs no account action.
5. The control retains the accessible name `YouTube account`, native menu-button semantics, keyboard focusability under the user's normal macOS keyboard-navigation setting, and visible focus. Keyboard activation opens the menu; arrow keys navigate, Return activates the highlighted enabled item, and Escape dismisses without triggering an action. Verify Escape does not inadvertently hide the application window, whose panel implements `cancelOperation` (`Sources/MaroApp/SearchWindow.swift:55`).
6. Existing menu actions still call their existing handlers exactly once. No OAuth, Keychain, playlist mutation, or menu availability changes are introduced by the visual patch.

## Validation seam and known limits

- Use `scripts/check-redesign-ui.swift`, which builds `PlaylistLibrary` with an injected local API (`:74`–`:76`) and hosts the real `AppShellView` (`:84`–`:85`). It captures 1440 × 900 and 1024 × 768 plus responsive boundaries (`:121`–`:125`), and records AX role/name/frame (`:203`–`:232`). Extend fixture state setup temporarily or in a narrow fixture change to cover disconnected/configured/busy cases without using the real account. Use the injected API path so initialization skips Keychain (`Sources/MaroApp/PlaylistLibrary.swift:48`).
- Build/reproduction command is documented at `docs/specs/tidal-frame-review.md:50`. Write new captures to a temporary output directory rather than overwriting approved design baselines.
- Historical capture `docs/specs/assets/tidal/shared/home-1440x900.json:87` records an `AXMenuButton` named `YouTube account` with a 34 × 15-point frame. This is archived evidence, not a current runtime measurement or proof of hit-area dimensions. Its `enabled: false` field must not be treated as a confirmed disabled control: the recorder defaults missing/non-Boolean AX values to false (`scripts/check-redesign-ui.swift:221`).
- Use actual mouse/keyboard/VoiceOver inspection for menu activation, click edges, focus, and dismissal. Screenshots and static source assertions cannot establish those properties. For handler integration, use disposable fixture data; the existing injected playlist API does not inject a fake OAuth account, so merely toggling `connected/configured` can validate presentation but cannot prove real reconnect/import behavior.
- A normal app build plus the focused native checks is proportionate. Do not add broad source-shape tests or run real Google account mutations for this styling change.

Research did not run or alter the application, build tests, or measure a current screenshot. The size and exact modifier arrangement remain proposals to review and validate during implementation.
