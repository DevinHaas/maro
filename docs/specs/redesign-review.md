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

One correction implementer owns all four findings and their relevant regression
checks. Native visual and interaction acceptance is recorded separately after
the corrected integration is verified.

Review totals: Standards 1 (shared-search cancellation); Spec 3 (order authority,
drag invalidation, and artwork fallback).
