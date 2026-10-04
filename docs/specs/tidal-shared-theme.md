# Tidal shared native styling (#10)

Approved application review: v1, 4 October 2026. Integration ancestor: e34ac05;
production geometry baseline: ce978cf. The shared theme introduces immutable
semantic surface, text, accent, border and status roles. Legacy AppDesign names
resolve to those same roles. AppShell, library, Home and Favorites now consume
Tidal paint; shared artwork retains its source, crop and dimensions. The generated
Favorites artwork uses Lagoon/Cyan. There is no customization or wallpaper UI.

Inset panel/card borders do not intercept input or enter layout. Library rows
outline only hover/selection. The existing library filter receives an inset focus
edge. The native wordmark, SF Symbols and all layout constants remain unchanged.

## Native seam: red → green

The saved 1440×900 production Home capture fails the approved Abyss canvas
expectation: its top-left canvas pixel is black. The rendered shared theme changes
that canvas to Abyss and panels to Ocean, with Foam primary text, muted metadata,
Mint primary controls and Cyan secondary/generated artwork. Native screenshots
carry an ICC display profile; raw RGB bytes must not be interpreted as sRGB token
values. A color-managed conversion gives approximately (11,21,25) for the native
Abyss canvas, with the final channel quantized one byte below the (11,21,26)
reference. This is paint evidence, not a private-token test.

The unchanged production acceptance fixture captured 18 states at the six pinned
sizes (1440×900,1024×768,1199×900,1200×900,1001×900,1002×900), preserving its original
Home/preview/playlist/active-rows/results sequence and retained queue. Exact
named-control/text measurements remain fixed. An initial decorative shortcut
overlay extended an opaque AX group by 8pt; the shortcut overlay was removed
rather than allowing drift. Native panel/card borders remain.

The fixture currently writes a hardcoded productionRevision ce978cf. In these
themed JSON observations that field identifies the pinned layout baseline, not
the themed source revision. The source is this #10 commit; #13 owns fixture
metadata correction and complete acceptance.

The original #9 ce978cf binary was replayed once as a repeatability control. Its
playlist1440 native scrollbar AXValueIndicator thumb changes 178.5→179pt and its
unlabelled trailing AXButton changes height543→542.5/y254→254.5pt; rows1024 trailing
AXButton changes height472→471.5/y193→193.5pt. These variable LazyVStack scroll
estimates are present without styling. Their 6pt width/x and full scrollbar track
stay fixed. Shared-theme captures show the same specific thumb/trailing-page
estimates. They are recorded as a native repeatability limit, not a tolerance for
application controls. The baseline replay also reproduces 1ulp coordinate
subtraction differences (834.6399999999999 vs834.64; 356.16666666666674 vs
356.1666666666667). Normalize only eight relative machine epsilons when assessing
these numbers; no point-level layout allowance is introduced.

## Native fonts and explicit retention

Official unmodified JetBrains Mono Regular400/Medium500/SemiBold600 TTFs and OFL
are copied into the SwiftPM resource bundle. AppTypography registers them for
the application process at startup and resolves packaged .app resources before
the conditional SwiftPM build-tree fallback. Development and standalone bundle
paths both include the font resource bundle. Native candidates disable common
and contextual programming ligatures, offer tabular numerals and use AppKit's
script/emoji cascade; missing-font candidates fall back to system monospaced text.

The raw AppKit/CoreText pre-audit identifies risk for intrinsic roles, not a
resolved frame failure. A temporary production HomeVideoCard probe therefore
compares actual SwiftUI Text dimensions at the existing 14pt semibold role, inside
its unchanged 36pt title container. The probe observes .leading alignment
dimensions and returns the original leading value; it changes no alignment.

| Actual fixture text | Font | Resolved text width | Resolved text height | First baseline |
| --- | --- | ---: | ---: | ---: |
| Quiet sessions 10 | SF semibold14 | 118.5 | 17 | 14 |
| Quiet sessions 10 | JetBrains Mono SemiBold14 | 143 | 18 | 14 |

The fixed outer title frame stays36pt and the first baseline stays14pt, but the
resolved text bounds change. This candidate fails the exact text-bounds contract;
the card title retains SF. It is not rescued by resizing, tracking, extra hidden
text, duplicate overlays or custom layout machinery.

Specific retained shared roles: rounded24pt heavy wordmark; library15pt bold
heading,14pt medium titles,11pt metadata/default filter and connection/status
text; Home10pt tracked eyebrow,26/34pt adaptive hero heading,12pt description,
13pt bold intrinsic action/shortcut labels,23pt bold section headings,12pt reasons,
14pt semibold card titles,12pt card metadata/save actions; Favorites caption,
44pt heavy heading and default count/help text. Intrinsic roles retain their
original font after the documented CoreText width/ascent/descent audit because
changing them would require separate resolved text/layout proof; they are not
claimed as measured candidate failures. This conservative retention is explicit.
Shared symbols remain native SF Symbols. Existing duration/date/time roles keep
their current SF tabular/monospaced declarations pending the owning ticket's
native validation.

A separate cold native process from the packaged .app resolves Resources and
registers JetBrainsMono-SemiBold at14pt with tabular features; it does not use the
worktree's .build resource path. This verifies packaged lookup, not font adoption
in an unmeasured text role.

## Verification and limits

Swift native application/tests build succeeds. The existing nonparallel suite
passes all135 tests after running with local-socket/macOS service access. The
sandboxed suite failed socket access; the unrestricted rerun passes. Development
bundle creation and codesign verification pass. No behavioral source logic or
structural dimensions changed. Final merged-surface accessibility, interaction,
modal and complete acceptance remain #13; native AX enabled flags from the old
fixture are unverified and are not used as behavior proof here.

Reproduction uses the existing check-redesign-ui.swift compile command in
tidal-frame-review.md with the production Sources. Temporary font probes add
`-D SWIFT_PACKAGE` and its generated resource_bundle_accessor.swift only to load
the same bundled candidates. Raw temporary observations live under
`/private/tmp/maro-tidal-shared-{sf,jetbrains,current}` and
`/private/tmp/maro-tidal-baseline-replay`; representative captures and comparison
observations are saved alongside this report under assets/tidal/shared.
