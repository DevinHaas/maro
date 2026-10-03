# Reuse prepared audio and reduce playback preparation time

ID: 02
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: task
Labels: wayfinder:task
Mode: AFK
Status: resolved
Assignee: root / 01a0f702-d970-7c31-8e5c-44de0c743491
Blocked by: none

## Question

Where is playback-start time spent, why might a previously prepared track be prepared again, and which bounded reuse/prefetch policy provides the largest measured improvement without delaying the selected track?

## Goal

Measure and reduce Maro's audio preparation latency, guarantee that repeatedly pausing and resuming a valid loaded track performs no new source resolution or audio preparation, and reuse prepared audio safely across repeat selections. Evaluate preparing the first five visible search results; implement bounded prefetch only when evidence supports it, otherwise document and implement the measured lower-cost improvement.

## Context and investigation

- `docs/ACCEPTANCE.md` records roughly 24 seconds for one preparation, not a reproducible baseline or an identified root cause.
- Trace all selection, pause/resume, replay, Favorite, Previous/Next, restore, and retry callers through `MaroController`, `YouTubeClient`, `AudioAssetLoader`, and `PlaybackEngine`, plus `SearchWindow`. Distinguish metadata search, extractor launch/resolution, audio fetch/materialization, engine readiness, and UI delay.
- Inventory existing caches and item ownership first. Preserve working pause/resume paths; do not add a cache merely because the symptom sounds like a cache miss.
- Current facts: playback uses a remote `AVURLAsset`, not a downloaded file. Healthy resume already reuses its player item; reselection, restored state without an item, and failure recovery prepare again. There is no explicit search/descriptor/audio cache; the existing bounded cache is for artwork. `--no-cache-dir` controls extractor caching, not audio reuse. `PreparedPlayback` is single-use and cannot simply be cached and recommitted; preserve the whole-player handoff that avoids previous item-migration failures.
- Cache identity must reflect video and relevant media variant. Choose the smallest useful reuse layer from measurements; disk downloads are not required. If local assets are chosen, reuse valid files independently of expired remote URLs. Define handling of stale descriptors, partial/corrupt entries, cancellation, active/paused asset eviction, bounded disk/memory usage, and cleanup. Cross-relaunch persistence is a measured tradeoff, not mandatory indefinite retention.
- For speculative preparation, compare no prefetch with the first five visible results. Start only after results display; use bounded concurrency/storage, deduplicate in-flight work, prioritize explicit selection, and cancel obsolete-query work. Do not prefetch all 20 fetched results or start audible playback.

## Acceptance

1. Record before/after stage timings on fixed representative IDs or a controlled local equivalent. Separate cold startup, warm reselection, loaded resume, and prefetched selection; record environment, repetitions, failures, byte/disk costs, and upstream variance. Do not present one unusually fast upstream response as an optimization.
2. A runnable regression check executes at least 20 pause/resume cycles after initial preparation and asserts zero additional resolve/download/prepare calls, continuous retained position, and correct playback intent. No wall-clock flakiness is needed for this invariant.
3. Reselecting the currently loaded healthy video reuses it instead of needlessly resolving/preparing it again, while retaining the intended selection/replay position semantics. For any additional retained cache entry, prove it skips the expensive stage it is intended to replace. Prove concurrent requests for the same media do not duplicate expensive work; stale/failed work cannot replace a newer selection or poison the cache.
4. Validate cache bounds, cleanup, corrupt/missing entries, active or paused asset retention, expiry recovery, and safe preservation of the current track on failed replacement. Restoration and replay retain their existing behavior.
5. If prefetch is chosen, prove that search remains responsive, the current selection gets priority, and an obsolete search cannot hijack playback. If rejected, link the measurements/reason and deliver the alternative latency improvement; prefetch is explicitly optional in the user's request.
6. Report a repeatable reduction in the affected cold-start stage and/or elimination of that stage on valid cache hits, with no material foreground regression. Choose realistic timing targets from the baseline and record them before optimizing; do not promise instant cold playback over an uncontrolled network.
7. Run focused source/loader/controller/playback tests plus the existing project checks required for touched paths. Record evidence and remaining live/manual gates honestly.

## AFK execution

Follow the map's claim/create_goal/verify/complete contract using the Goal above. This ticket is independently takeable; coordinate shared source/client files with the search ticket rather than reverting another agent's work.

## Answer

Implemented and verified on 2026-10-01; see [measurements and prefetch decision](../assets/audio-preparation-findings.md) for the baseline, rejected hypothesis, exact timings, cache scope, and limits.

- Twenty repeated resume/pause cycles plus same-track reselection reuse one prepared player. Explicit reselection still restarts at zero; a later pause wins. Missing/unready items and failed reuse trigger fresh preparation, and access recovery retains its bounded refresh behavior.
- Duplicate same-video selection requests share one operation. The search UI no longer cancels/restarts that preparation for a repeated identical click.
- A stalled preferred candidate no longer blocks an already usable fallback for fifteen seconds: after a one-second preference window, at most two muted candidate preparations compete. Losing work is canceled, and failed replacement preserves current playback.
- The reproduced public-video case improved from 23.4–24.8 seconds to 9.4–10.1 seconds total; native preparation itself fell to 1.7–1.8 seconds. Source resolution remains roughly eight seconds. Network availability is still variable and has not been claimed fixed.
- Full suite: 70 tests passed, including new reuse, duplicate-request and bounded-fallback checks, plus existing cancellation, shutdown, navigation, replay, restoration and access-recovery tests. Silent probes used two fixed public IDs twice each and never committed audio. No audible listening acceptance is claimed.
- First-five speculative audio preparation was rejected in favor of the measured foreground improvement, as permitted by the user. No new media files, persistent signed URLs, or unselected players are retained. Search metadata reuse is the separate next goal.

This resolution preceded final packaging. Audio reuse and search improvements are now installed together with [the long-video fix](06-progressive-long-video.md); that ticket records final verification and rollback.
