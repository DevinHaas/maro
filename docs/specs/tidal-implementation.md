# Tidal implementation status

Spec: [#8](https://github.com/DevinHaas/maro/issues/8). Integration branch: `codex/tidal-integration`. Native layout baseline: `ce978cf6738a92583770931238b0492ed1acbe42` from open redesign PR #7.

The approved handoff is preserved in `design/terminal-style/` and `docs/specs/tidal-terminal-visual-style.md`. Existing local workflow and inspiration files remain separate from the implementation commits.

## Ticket graph

| Ticket | Depends on | Work |
| --- | --- | --- |
| [#9](https://github.com/DevinHaas/maro/issues/9) | Native baseline | Capture measured production fixture; prepare and inspect Home, playlist and search/player screenshots plus an HTML mockup; obtain explicit approval of the named version and scope |
| [#10](https://github.com/DevinHaas/maro/issues/10) | #9 screenshot/HTML approval | Shared semantic theme, native font measurements/exceptions, chrome, Home, library and Favorites |
| [#11](https://github.com/DevinHaas/maro/issues/11) | #9, #10 | Playlist header, occurrence rows, drag feedback and native action dialogs |
| [#12](https://github.com/DevinHaas/maro/issues/12) | #9, #10 | Global search, preview/results and fixed bottom player |
| [#13](https://github.com/DevinHaas/maro/issues/13) | #10, #11, #12 | Exact native geometry and behavior acceptance, code review and integration delivery |

#11 and #12 can run concurrently after #10. Implementer worktrees start from the integration branch and merge its current tip before delivery; a merger integrates each completed ticket. Issues remain open until the integration PR merges.

## Current frontier

#9's screenshot/HTML package was approved on 4 October 2026: “I approve the style.” #10 is implemented and merged; its [native shared-theme report](tidal-shared-theme.md) records the palette, bundled font loading, explicit SF retentions, 135 passing existing tests and 18 capture comparisons. Stable application frames match; the pinned original binary independently reproduces the documented native scrollbar estimate variability and arithmetic ULP differences.

The user stopped further redesign work on 4 October 2026: “it looks good already lets stop here and commit what we have.” Current #11 playlist/dialog styling and #12 search/player styling are committed as checkpoints. Their scoped existing regressions passed (30 playlist tests and 33 search/player tests). Playlist captures and strict numeric observations are saved under `assets/tidal/playlists/`; final search recapture and font-probe reporting were interrupted. Full merged #13 native acceptance, shared focus-stroke correction and standards/spec code review remain unfinished. The integration PR stays a draft; no ticket is claimed closed. Resume only at the user's request.

Figma team creation and browser sign-in are no longer prerequisites. The earlier Figma destination and sign-in questions are superseded by the user's screenshot/HTML requirement.

## Validation contract

Preserve native frames, anchors, text bounds and baselines, symbols, artwork, hit regions, dimensions, breakpoints and behavior exactly. Required viewports: 1440×900, 1024×768, 1199×900 and 1200×900, plus the Home-title threshold. Font substitutions that fail geometry retain their original native font with recorded evidence. Accessibility attributes that do not expose glyph baselines must not be reported as baseline measurements.

Use the existing isolated native acceptance fixture and meaningful existing behavior checks. Save representative visual and numeric evidence; report unsupported pointer-drop/edge-autoscroll checks explicitly. Scope excludes customization UI and backgrounds.
