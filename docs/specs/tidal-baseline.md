# Tidal native baseline

Production revision: `ce978cf6738a92583770931238b0492ed1acbe42` (PR #7).
Captured on 4 October 2026 using the production `SearchWindow`/`AppShellView`,
the existing generated artwork, local API fixture, temporary state and muted
local audio. No `Sources/MaroApp` files changed for this baseline.

## Reproduce

```sh
bash scripts/build-redesign-fixture.sh
bash scripts/capture-native-baseline.sh /tmp/maro-native-captures
python3 scripts/check-ui-geometry.py /tmp/maro-native-captures
python3 scripts/check-ui-geometry.py /tmp/maro-native-captures --compare docs/specs/assets/tidal/baseline
```

The fixture targets 1440×900, 1024×768, 1199×900, 1200×900, 1001×900 and
1002×900 logical content viewports. The last pair brackets the Home feature's
650-point title adaptation threshold. Ten planned states per viewport: Home, preview,
playlist, active duplicate rows, failed cover fallback, Favorites, results,
empty, source error and library filter. `.png` and `.geometry.json` files share
a basename under [assets/tidal/baseline](assets/tidal/baseline). The interrupted
run preserved 46 paired image/geometry records and 59 PNG files, not complete
60-state acceptance. Images without corresponding geometry are not numerical
baseline evidence.

[tidal-layout-manifest.json](tidal-layout-manifest.json) gives a compact shell,
Home, playlist, preview/results and player handoff for both primary sizes.
It labels source constraints separately from observed native geometry. Exact
placements are in each route's observations; player centers can vary by content
state and should not be copied between routes.

## Observation contract

Coordinates use the content's top-left origin in logical points, excluding
window chrome. Each run records backing scale, AX role/label/text rectangles,
control centers and enabled state, plus NSView bounds and visibility. Native
text fields include baseline offsets and font descriptors. Native playlist drag
bridge bounds, timeline and volume views and search-preview bridge bounds are
retained. Offscreen AX children may extend beyond the viewport; their rectangles
are not clipped or mislabeled as visible pixels.

The guard requires all states, images, matching viewport metadata and nonempty
Home/library/filter/volume controls. Comparison checks exact AX rectangles,
roles and labels, and native view geometry/baseline offsets; it has no tolerance.
Text content and font descriptors are recorded but excluded from geometry
comparison because font appearance is intentionally changing. A mismatch is
reported with its route/viewport. Passing this check verifies the exposed native
boundary only, not every SwiftUI layout detail.

## Capture orchestration

The driver starts a fresh process and temporary state per route/viewport, with
the original production callbacks and fake services. Output must be empty, so
stale files cannot satisfy completeness checks. Only `--capture` requests a
user-initiated, latency-critical ProcessInfo activity and activates its window
to prevent background App Nap/timer throttling; the activity is ended on return.
A 15-second independent search timeout and a 20-second external deadline per
native process stop incomplete attempts. The external launcher redirects native
stdout/stderr to per-state logs and terminates only its own fixture process on
timeout. This is fixture orchestration, not new application interaction
verification. Progress instrumentation confirmed empty searches complete; the
unresolved stall occurs after paint settling and, for several states, after PNG
output but before geometry completion. Its exact cause remains unverified.
A queue reentrancy cause was not demonstrated and callback changes
were discarded.

## Limits

- SwiftUI AX text rectangles are exposed text bounds, not glyph ink bounds or
  typographic baselines. SwiftUI Text font descriptors/baselines remain unexposed.
- AX control bounds/centers do not prove custom `contentShape` hit regions.
  Drag bridge bounds are actual native view observations.
- SwiftUI-only spacing, playlist column dividers and painted overlay boundaries
  require capture review and supplemental source constraints. No private layout
  probes or production testing API were added.
- These baseline captures do not verify the new theme, VoiceOver speech,
  accessibility contrast, hover/pressed/modal states, pointer drop/autoscroll or
  interaction regression. Those remain later acceptance work under #8.

## Validation

The external capture guard was written first and failed on missing geometry
(red). The current run's first 31 available paired states passed the guard in
explicit partial mode. A deliberate 0.25-point AX rectangle change was rejected;
missing capture coverage was also rejected by the default complete gate. The
fixture built successfully; shell/Python command syntax checks passed.

The user requested capture/testing stop on 4 October 2026. The run was stopped
and its fresh outputs preserved; no additional acceptance checks were run on
the final 46 paired states. This is preparatory evidence for editable mockups,
not completed visual acceptance or approval for application paint changes.

| Viewport | Paired states preserved | Missing geometry |
| --- | ---: | --- |
| 1440×900 | 8 | empty, error |
| 1024×768 | 8 | empty, error |
| 1199×900 | 8 | empty, error |
| 1200×900 | 7 | empty, error, filter |
| 1001×900 | 8 | empty, error |
| 1002×900 | 7 | empty, error, filter |

Home, preview, playlist, active duplicate rows, cover fallback, Favorites and
results have paired records at all six viewports. The Home title AX rectangle
is `[623.07,147,175,30]` at 1001×900 and `[623.5,147,228,40]` at 1002×900;
the exposed content scroll widths are 697 and 698 points respectively,
corroborating the existing title threshold with rendered native observations.
The primary Home images were visually inspected. Per-state logs and
`capture-run.log` preserve progress and timeout evidence.
