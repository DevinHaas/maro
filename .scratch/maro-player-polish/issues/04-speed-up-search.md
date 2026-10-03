# Reduce time to the first useful YouTube search results

ID: 04
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: resolved
Assignee: root / 01a0f702-d970-7c31-8e5c-44de0c743491
Blocked by: 03

## Question

Which measured changes to the chosen retrieval path make the first five useful search results arrive sooner while retaining current search and navigation behavior?

## Goal

Implement and verify the evidence-backed YouTube retrieval improvements chosen in the provider research, reducing time to the first five usable results and avoiding redundant repeated-query work without regressing metadata, Load 5 more, selection, or Previous/Next behavior.

## Scope and acceptance

1. Read the provider research resolution before implementation. Trace UI-to-provider-to-display timing and record the current stage breakdown; do not assume the extractor or network alone causes the reported delay.
2. Compare the same representative queries under cold/warm conditions over multiple runs, recording first-five and full-bounded-list timing, upstream errors, and result completeness. Set a measurable improvement target from that baseline before making the change, then report whether it passed.
3. Reuse existing process/cache/cancellation mechanisms. Implement only measured improvements such as bounded metadata caching, deduplication, or reducing avoidable extraction/enrichment work. Avoid a new dependency/provider abstraction without evidence it is necessary.
4. Keep the first five results useful with title, creator, duration/unknown-duration handling, thumbnail/fallback, and stable video IDs. Retain Load 5 more and navigation through the complete bounded fetched list; no silent reduction from 20 navigable results to five.
5. Repeated equivalent queries reuse valid results under a documented freshness policy. A late response from an obsolete query never replaces a newer search. Failure/retry/cancellation and a background search do not interrupt existing playback.
6. Add the smallest focused regression checks for changed cache/cancellation/result-reveal behavior, run existing affected tests, and record reproducible before/after measurements. Do not count audio-preparation improvements as search improvements.
7. Official API integration is conditional on research, available credentials, and measured benefit. Keep a functioning no-key path; do not make completion depend on an unprovisioned service. Record any conditional integration as follow-up rather than inventing credentials or assuming availability.

## AFK execution

Follow the map's claim/create_goal/verify/complete contract using the Goal above. Coordinate edits to shared client/controller/search files with the audio ticket. Resolve only when the chosen performance target and functional checks pass.

## Answer

Implemented and verified on 2026-10-01. [Measurements and policy](../assets/search-performance-findings.md) record repeated searches falling from 7.66–7.69 seconds to under 0.05 ms at the controller boundary. Cold searches remain approximately eight seconds. Eight metadata batches are cached for sixty seconds, retaining twenty results and resetting reveal to five. Duplicate in-flight queries share completion. Regression checks pass for reuse, expiry/eviction, errors, stale responses, and navigation. Package with the long-video follow-up before final delivery.
