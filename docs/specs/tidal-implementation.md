# Tidal implementation graph

Spec: [#8](https://github.com/DevinHaas/maro/issues/8).
Baseline: `ce978cf6738a92583770931238b0492ed1acbe42`.
Integration: `codex/tidal-style`.

PR #7 is still open on `codex/spotify-redesign`. The Tidal draft PR initially
targets that branch so its review diff contains only this styling work. Retarget
to `main` after PR #7 merges; do not duplicate or silently merge the prior work.

| Ticket | Responsibility | Blocked by |
| --- | --- | --- |
| [#9](https://github.com/DevinHaas/maro/issues/9) | Fresh production baseline, geometry observations, editable Home/playlist/search-player mockups and explicit approval | Figma destination and application-frame approval |
| [#10](https://github.com/DevinHaas/maro/issues/10) | Semantic Tidal theme, native fonts/OFL, shared components, Home/library/Favorites | #9 approval |
| [#11](https://github.com/DevinHaas/maro/issues/11) | Playlist headers/rows, occurrence and drag feedback, actions/dialogs | #9, #10 |
| [#12](https://github.com/DevinHaas/maro/issues/12) | Global search/preview/results, native field, fixed player and sliders | #9, #10 |
| [#13](https://github.com/DevinHaas/maro/issues/13) | Native exact parity, state/readability/behavior validation, code review and delivery | #10, #11, #12 |

Each implementer owns an isolated worktree and codex branch based on integration,
uses TDD at the user-confirmed rendered native acceptance seam, and merges the
latest integration tip before handing off. A merger agent integrates completed
work. The draft integration PR opens after the first merge. Final standards and
spec review runs on integration; one implementer fixes findings. Mark ready only
when #8 acceptance passes, then remove implementer worktrees. GitHub issues remain
open until the completed integration PR merges.

The approved guide/spec were copied from the original checkout without changing
its uncommitted files, inspiration assets or local Laufwerk package setup. No
design-inspo runner is claimed. Representative application-frame approval remains
pending; guide approval does not authorize unseen mockups. Application paint
implementation cannot start before that gate.

## Review setup

Figma is connected. Its authenticated account has multiple teams. A destination
question is pending, as required by `figma-create-new-file`; no file has been
created or mockup approval inferred. The requested representative editable
frames remain the next deliverable after fresh native baseline observations.
No application paint changes, theme acceptance or final #8 code review are
claimed by this preparatory work.
