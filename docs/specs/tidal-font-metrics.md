# Tidal pre-implementation font audit

Date: 2026-10-04. Baseline: ce978cf. Measurement tool: AppKit NSFont and CoreText CTLine; process-only font registration; programming ligatures disabled with `.ligature: 0`. No system font installation or application styling changes.

Official unmodified TTF sources: `https://github.com/JetBrains/JetBrainsMono/tree/master/fonts/ttf`. Temporary candidates downloaded from the official master branch, with SHA-256:

- Regular: `e6fd0d7e91550b3ed2b735d4312474362c4716edc4fc0577a0f61ed782d5aed1`
- Medium: `d16e6dc99672734698d629705f617c79f6eb6040f5113efe3a145204dc988109`
- SemiBold: `12d4b18fe6e1af528e4bea69cb0997aeff22f9e52fccffcf66342dd88aa32ab8`

Measurements are logical points, rounded here to four decimals. Text samples are representative audit strings; these are shaping metrics, not final SwiftUI frame or AX baseline acceptance. Bold/heavy map to the approved 600 candidate for comparison. Role declarations must still be checked before application integration.

| Role / sample / size | SF advance | JetBrains advance | SF ascent / descent | JetBrains ascent / descent |
| --- | ---: | ---: | --- | --- |
| Library title / Evening Sessions / 14 medium | 114.9640 | 134.4000 | 13.5352 / 2.9531 | 14.2801 / 4.2000 |
| Library subtitle / Playlist • Maro / 11 regular | 75.3511 | 99.0000 | 10.6348 / 2.3203 | 11.2200 / 3.3000 |
| Global search field / What do you want to listen to? / 14 regular | 195.0635 | 252.0000 | 13.5352 / 2.9531 | 14.2801 / 4.2000 |
| Playlist row title / Unhurried listening / 14 medium | 126.0704 | 159.6000 | 13.5352 / 2.9531 | 14.2801 / 4.2000 |
| Playlist duration / 3:42 / 11 regular (before monospaced-digit feature) | 24.1377 | 26.4000 | 10.6348 / 2.3203 | 11.2200 / 3.3000 |
| Home section / Made for you / 23 bold | 138.7349 | 165.6000 | 22.2363 / 4.8516 | 23.4601 / 6.9001 |
| Home feature / Your next favourite sound / 26 bold | 308.6527 | 390.0000 | 25.1367 / 5.4844 | 26.5201 / 7.8001 |
| Home feature / Your next favourite sound / 34 bold | 402.0317 | 510.0000 | 32.8711 / 7.1719 | 34.6801 / 10.2001 |
| Playlist title / Evening Sessions / 54 heavy | 452.0985 | 518.4000 | 52.2070 / 11.3906 | 55.0802 / 16.2002 |
| Player title / Unhurried listening / 12 medium | 110.5096 | 136.8000 | 11.6016 / 2.5313 | 12.2401 / 3.6000 |
| Rounded wordmark / maro / 24 heavy | 59.9858 | 57.6000 | 23.2031 / 5.0625 | 24.4801 / 7.2001 |
| Monospaced player time / 3:42 / 10 regular | 24.7266 | 24.0000 | 9.6680 / 2.1094 | 10.2000 / 3.0000 |

Every sampled text role, including the rounded wordmark and monospaced player time, changes intrinsic advance width and vertical metrics. This establishes a substitution risk, not a final SwiftUI geometry failure: #8 exempts intentional glyph shape and antialiasing changes, and some text already occupies fixed containers. Measure resolved text bounds, baselines and surrounding controls in the production fixture before deciding which roles retain SF. Do not compensate by changing point size, tracking, line height or frame. Editable Figma review frames may show JetBrains in fixed areas as a candidate, clearly marked pending native geometry acceptance; use provisional SF exceptions for intrinsic roles whose changed metrics would move neighboring controls. SF Symbols and emoji/script fallbacks remain unchanged. The native search field's `.systemFont(ofSize: 14)` declaration was confirmed in `GlobalSearchView.swift:94`.

Reproduction script: `scripts/audit-tidal-font-metrics.swift`; three temporary TTFs: `/private/tmp/JetBrainsMono-{Regular,Medium,SemiBold}.ttf`. Use a module cache under `/private/tmp`; registration lasts only for the audit process.

