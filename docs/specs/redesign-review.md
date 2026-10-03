# Integration review

Baseline: `253cb9a`. Reviewed integrated implementation: `5090d6e`.
Origin: GitHub spec #1 and `spotify-style-application-redesign.md`.

## Standards

No documented-standard breaches or additional meaningful baseline smells found.
One concrete regression: cancelling a preview or discovery waiter cancels the
shared provider task even when a submitted foreground search still awaits it.
Correct cancellation ownership and verify a held preview/submission request.

## Spec

Three findings:

1. A saved-order receipt protects old signatures indefinitely, so an external
   restoration to a previously observed order can remain hidden. Bound lag
   reconciliation and verify external restoration to the prior signature.
2. Application route changes do not invalidate library drag payloads. Invalidate
   drag state on actual navigation and verify Home/back cannot submit a stale drop.
3. Failed primary playlist artwork does not attempt an available first-video
   thumbnail. Apply the fallback chain without delaying detail or playback.

## Correction status

One correction implementer resolved all four findings in `22e689b`, integrated
as `7dc9701`. The nonparallel suite passes all 135 tests. Cancellation ownership
is per waiter; acknowledged reorder protection expires after 60 seconds; route
changes invalidate drag state; artwork attempts the first available video after
primary failure.

Native acceptance additionally found cover images expanding the header's layout
and the full panel hiding on deactivation. Corrections `f803a72` and `594022c`
constrain artwork to the existing 320-point header and keep the full window
visible. A focused independent standards review found zero additional findings
in these corrections. Native checks also verified action-sheet focus restoration
after `89afde0`.

The native handle needed a narrowly scoped input bridge because SwiftUI's row
container intercepts its events. Independent review found one additional P2:
the bridge could intercept an overlapping preview. Correction `541807a` requires
the actual hit target to be an ancestor of the handle and uses the original
mouse-down event for the AppKit session. A focused independent review confirmed
the P2 resolved with no new concrete findings. No temporary diagnostics remain
in production code.

Final production integration `ff3abee` builds and passes all 135 nonparallel
tests (22.233 seconds). Independent spec follow-up found the original corrections
resolved. Native evidence and the physical-pointer automation limit are recorded
in `redesign-acceptance.md`.

YouTube provides no order revision for distinguishing a lagging read from an
external restoration to an old signature. The 60-second receipt window is bounded
protection; after it expires, a successful read becomes authoritative. Failed
reads continue to preserve the acknowledged visible order.

Initial review totals: Standards 1 (shared-search cancellation); Spec 3 (order
authority, drag invalidation, and artwork fallback). Native follow-up: one P2
(overlay input interception), resolved. All reported code findings are resolved.
