# Tidal implementation status

Spec: [#8](https://github.com/DevinHaas/maro/issues/8). Integration branch: `codex/tidal-integration`. Native layout baseline: `ce978cf6738a92583770931238b0492ed1acbe42` from open redesign PR #7.

The approved handoff is preserved in `design/terminal-style/` and `docs/specs/tidal-terminal-visual-style.md`. Existing local workflow and inspiration files remain separate from the implementation commits.

## Ticket graph

| Ticket | Depends on | Work |
| --- | --- | --- |
| [#9](https://github.com/DevinHaas/maro/issues/9) | Native baseline | Capture measured production fixture; create and inspect editable Home, playlist and search/player designs; obtain explicit approval of the named version and scope |
| [#10](https://github.com/DevinHaas/maro/issues/10) | #9 frame approval | Shared semantic theme, native font measurements/exceptions, chrome, Home, library and Favorites |
| [#11](https://github.com/DevinHaas/maro/issues/11) | #9, #10 | Playlist header, occurrence rows, drag feedback and native action dialogs |
| [#12](https://github.com/DevinHaas/maro/issues/12) | #9, #10 | Global search, preview/results and fixed bottom player |
| [#13](https://github.com/DevinHaas/maro/issues/13) | #10, #11, #12 | Exact native geometry and behavior acceptance, code review and integration delivery |

#11 and #12 can run concurrently after #10. Implementer worktrees start from the integration branch and merge its current tip before delivery; a merger integrates each completed ticket. Issues remain open until the integration PR merges.

## Current frontier

#9 is in progress. Its [preparation checkpoint](tidal-frame-review.md) now includes 18 native captures, 18 AX frame reports, responsive threshold observations, a CoreText font metric audit, and an inspected local editable proposal with Figma-ready scene data. Native build/fixture compilation and size/report checks passed. Editable Figma composition and exact font inspection remain pending. Application paint changes require explicit approval of those application designs, as required by #8 and #9; approval of the foundation guide does not satisfy that gate.

The user requested a new destination, interpreted as a new Maro Figma team. The connector can create files in existing teams but does not expose team creation. Browser sign-in was blocked by automatic approval review pending explicit authorization for the identified account; that request remains pending. No existing team has been selected arbitrarily.

## Validation contract

Preserve native frames, anchors, text bounds and baselines, symbols, artwork, hit regions, dimensions, breakpoints and behavior exactly. Required viewports: 1440×900, 1024×768, 1199×900 and 1200×900, plus the Home-title threshold. Font substitutions that fail geometry retain their original native font with recorded evidence. Accessibility attributes that do not expose glyph baselines must not be reported as baseline measurements.

Use the existing isolated native acceptance fixture and meaningful existing behavior checks. Save representative visual and numeric evidence; report unsupported pointer-drop/edge-autoscroll checks explicitly. Scope excludes customization UI and backgrounds.
