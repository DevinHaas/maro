# Tidal application frames — preparation checkpoint

Date: 4 October 2026. Parent spec #8; prerequisite #9. Application paint has not changed.

**Status:** the native screenshot and HTML mockup package is prepared, inspected and approved. On 4 October 2026, the user changed #9 to accept screenshots plus an HTML mockup and then approved application review v1: “I approve the style.” #10's shared styling work is unblocked. Editable Figma frames are not required.

## Review artifact

Open [the HTML mockup](../../design/terminal-style/frames/index.html) through a static server rooted at the repository (for example `python3 -m http.server 8767 --bind 127.0.0.1`, then `/design/terminal-style/frames/index.html`). The state and viewport selectors expose Home, playlist, search preview/player, active duplicate row and search results/player. The composition has semantic text, artwork, vector icons and panel nodes; it contains no flattened application screenshot. [scene.mjs](../../design/terminal-style/frames/scene.mjs) is the semantic composition source. The native screenshots in the baseline directory and this HTML mockup satisfy the revised artifact-format requirement.

The HTML mockup is a styling proposal, not native font/layout acceptance. AX-exposed coordinates anchor controls and headings; artwork, decorative panels and unexposed row content use the pinned production source. Preview content and SVG icon equivalents are representative approximations; native implementation must be reconciled with the baseline evidence. Production will retain SF Symbols. Browser font baselines do not prove SwiftUI baseline parity.

Tidal defaults: Abyss canvas, opaque Ocean panels, Lagoon raised surfaces, Foam text, muted blue metadata, Mint primary controls and Cyan secondary accents. Original generated artwork remains full color and keeps its native source asset, bounds and crop. No wallpaper or terminal effects are proposed.

## Fresh native evidence

Production views and Package.swift are byte-identical to ce978cf (`git diff ce978cf -- Sources/MaroApp Package.swift` was empty). The integration branch started at 9233c63. Capture uses actual SearchWindow/AppShellView production views with the existing disposable local API/artwork fixture and zero-volume local audio. It uses no authenticated API or installed-app data.

The [baseline directory](assets/tidal/baseline/) contains 18 PNG captures and 18 matching JSON observations, plus the original discrete fixture-artwork.png. All captures use backing scale 2, dark appearance and explicit logical hosting bounds:

| States | Logical viewports |
| --- | --- |
| Home, playlist, search preview/player | 1440×900, 1024×768, 1199×900, 1200×900 |
| Active duplicate rows, search results/player | 1440×900, 1024×768 |
| Home-title threshold | 1001×900, 1002×900 |

The JSON coordinate system is logical content points, origin top-left. Each observation records role, full native label/value, enabled state and AX frame. SwiftUI virtual AX objects implement accessibility selectors without consistently declaring the full AppKit protocol, so the fixture uses guarded KVC to observe those selectors; protocol-only casting missed virtual controls. Zero-frame scroll controls and offscreen lazy children are retained as reported, not treated as visible hit regions.

| Viewport | Source-resolved sidebar / main x | Native Home-title x,y,w,h | Native Home-button x,y,w,h |
| --- | --- | --- | --- |
| 1440×900 | 320 / 336 | 834.64,147,228,40 | 495,13,38,38 |
| 1024×768 | 280 / 296 | 632.96,147,228,40 | 287,13,38,38 |
| 1199×900 | 280 / 296 | 708.21,147,228,40 | 374.5,13,38,38 |
| 1200×900 | 320 / 336 | 731.44,147,228,40 | 375,13,38,38 |
| 1001×900 | 280 / 296 | 623.07,147,175,30 | 275.5,13,38,38 |
| 1002×900 | 280 / 296 | 623.5,147,228,40 | 276,13,38,38 |

`HomeView.feature` selects 26pt below an inner feature width of 650pt and 34pt otherwise. With expanded library below 1200pt, feature width is window width minus 352pt. The 1001/1002 pair therefore exercises 649/650pt exactly. Native title height changes 30→40pt at the existing threshold; this behavior is preserved. Sidebar width changes 280→320pt at 1200; the main content origin changes 296→336pt.

At 1440×900, Back is (92,13,38,38), Hide library is (142,13,38,38), Open playlist is (834.5,294,121,38), native global text field is (597.5,23.5,449.5,17), and playback volume is (1330.5,844,90,16). Playlist play is (360,416,62,62); first drag handle is (368,545,16,44), first row action is (1362,548,38,38). These are observations, not tolerated-drift thresholds. Future themed comparisons require identical corresponding native frames.

The fixture follows the existing sequential capture state machine: after active rows, subsequent viewport Home/player captures retain the paused duplicate-occurrence queue and library status. Each JSON includes the actual full player metadata. Future themed comparison must follow this same sequence rather than resetting only one side.

## Typography and exceptions

The [CoreText audit](tidal-font-metrics.md) records candidate JetBrains Mono and native font advances, ascents and descents with process-only registration and ligatures disabled. It establishes intrinsic metric differences, not resolved SwiftUI geometry failure. Fixed container candidates remain viable pending measurement; the local frame proposal keeps native fonts in intrinsic headings, navigation, fields and primary labels, with provisional JetBrains row/card title and metadata treatments. No role is approved as a final exception yet.

Native AX provides heading/text rectangles and combined row labels, but does not expose every glyph baseline or private SwiftUI text-container dimension. Individual glyph baselines remain unverified. Future font work must record them at the same native fixture seam (a fixture-only alignment observation can return the unchanged firstTextBaseline value), and record any final SF retention as an explicit exception. No native metric compensation or point-size reduction is authorized by this checkpoint.

## Reproduction and checks

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/maro-tidal-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/maro-tidal-module-cache swift build --disable-sandbox --build-tests
swiftc -suppress-warnings -module-cache-path /private/tmp/maro-tidal-module-cache -parse-as-library -I .build/arm64-apple-macosx/debug/Modules scripts/check-redesign-ui.swift $(rg --files Sources/MaroApp -g '*.swift' | rg -v '/MaroApp.swift$') .build/arm64-apple-macosx/debug/MaroCore.build/*.o -o /private/tmp/maro-tidal-native-fixture
/private/tmp/maro-tidal-native-fixture --capture docs/specs/assets/tidal/baseline --tidal-baseline
```

Native fixture execution requires access to macOS GUI services; sandboxed launch could not connect, so the isolated fixture was run through approved escalation. Build and fixture compilation passed. JSON/image count, logical/pixel size and both responsive thresholds were checked. HTML Home, playlist and preview mockups were inspected in a browser. A preview/recommendation AX-label collision was corrected by selecting the native 176pt card frame. Unavailable state/viewport selections clear the canvas and explain the supported capture combinations; returning to Home restores the mockup. Browser-native font approximations can truncate an intrinsic heading differently; this is a mockup limit, not native acceptance or an authorized layout/font exception. The screenshot/HTML package is complete for review; themed native acceptance remains work for #10–#13.

## Approval record

Tidal foundations were approved previously. On 4 October 2026, the user approved the screenshot/HTML artifact format and then approved application review v1 with “I approve the style” while the HTML mockup was open. This approval covers the Home, playlist and search/player styling proposal, its measured layout, and the recorded provisional font limitations. Application paint implementation may now start. Native geometry, font exceptions and behavior still require validation during #10–#13. Editable Figma creation and sign-in are not required.
