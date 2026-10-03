# Redesign implementation graph

Parent: [#1](https://github.com/DevinHaas/maro/issues/1).
Integration branch: `codex/spotify-redesign`.
Reviewed application baseline: `253cb9a`.

The user authorized implementation on 2026-10-03, superseding the original
spec-writing phase's deferral. The specification's proposed app/library/controller
and injected source/API testing seams are accepted for this implementation.

| Ticket | Responsibility | Blocked by |
| --- | --- | --- |
| [#2](https://github.com/DevinHaas/maro/issues/2) | Shell and searchable library | — |
| [#3](https://github.com/DevinHaas/maro/issues/3) | Home and recommendations | #2 |
| [#4](https://github.com/DevinHaas/maro/issues/4) | Global search and results | #2 |
| [#5](https://github.com/DevinHaas/maro/issues/5) | Playlist detail and action modals | #2 |
| [#6](https://github.com/DevinHaas/maro/issues/6) | Persistent drag reordering | #5 |

Workers use separate worktrees based on the integration tip, commit their scoped
ticket, and merge the latest integration tip before reporting completion. A merger
integrates completed tickets. The pull request closes the parent and all completed
children when merged. Open tickets remain open until then.

Native reference assets are preserved in `assets/spotify-redesign/`. Final
acceptance includes the nonparallel Swift suite, native visual/interaction checks,
and independent standards/spec reviews against the application baseline.

## Baseline verification

`swift test --no-parallel --scratch-path /private/tmp/maro-redesign-baseline-build`
passed all 95 existing tests. A fresh scratch directory avoids the copied local
build cache's original checkout path; the original build/runtime assets remain
available locally.
