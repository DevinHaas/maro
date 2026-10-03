# Audio preparation measurements and reuse decision

Date: 2026-10-01. Probes ran in separate processes using pinned tools and muted staging players. They never committed media or changed the installed player's playback. Signed URLs and authentication context were not logged.

These measurements precede the user's long-video follow-up. The final build additionally prefers native segmented streams; see [long-video diagnosis and final verification](long-video-findings.md). The earlier timing table is retained as evidence of the first bottleneck, not as a claim about final stream selection.

## Reproduced causes

1. `repeatedResumeAndReselectionReuseTheLoadedPlayer` initially failed: selecting the same healthy loaded video prepared it twice and changed its playback identity. Twenty ordinary pause/resume cycles already reused the same player. After the fix, the twenty cycles plus explicit reselection perform one total preparation; reselection still seeks to the beginning, and a newer pause wins.
2. On the fixed public cello video, the preferred candidate consistently spent 15 seconds failing its native preparation check while a second compatible candidate became ready in under two seconds. Source resolution cost another approximately eight seconds. The sequential loop reproduced the earlier roughly 24-second symptom.
3. Bypassing `AVURLAsset.isPlayable` did not fix the first candidate: direct muted-player readiness still stalled for 15 seconds on both repeats. Keep native codec/playability validation.

## Measurements

Harness: `scripts/measure-audio-preparation.swift`, linked against debug MaroCore. `--bounded` exercises the final production preparation method; default mode times the previous sequential stages. The probes use the same IDs and tools but fresh source resolutions. These small network samples establish this bottleneck, not a universal latency guarantee.

| Public ID / run | Baseline resolve | Baseline first candidate | Baseline fallback | Updated resolve | Updated complete preparation | Updated total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| mGQLXRTl3Z0 / 1 | 8.134 s | 15.133 s, failed | 1.560 s, ready | 8.293 s | 1.817 s | 10.110 s |
| mGQLXRTl3Z0 / 2 | 8.143 s | 15.115 s, failed | 0.191 s, ready | 7.698 s | 1.677 s | 9.374 s |
| qmVaEn57EHY / 1 | 9.153 s | 0.121 s, failed; no fallback | — | 9.119 s | 0.319 s | 9.438 s |
| qmVaEn57EHY / 2 | 8.915 s | 1.059 s, ready; no fallback | — | 8.691 s | 0.417 s | 9.108 s |

For the reproducibly stalled cello track, total preparation fell from approximately 23.4–24.8 seconds to 9.4–10.1 seconds. Resolution still dominates the remaining delay. The other video sometimes failed in baseline and direct-readiness probes; the two successful updated probes do not prove upstream availability is fixed.

## Implementation and acceptance targets

- Keep the healthy loaded `AVPlayer` as the bounded one-track reuse cache. No extra resolve/prepare calls for repeated resume, replay, or same-track reselection. Explicit selection restarts at zero; resume retains position. Failed/unready or missing items trigger fresh preparation. Recovery still refreshes the source and retains the original single-retry limit.
- Coalesce simultaneous selection requests for the same video/position into the same operation and result. Repeated Search-window submissions do not cancel and restart that operation. Different selections retain generation checks and cancel obsolete work; shutdown still invalidates everything.
- Give the highest-bitrate candidate a one-second head start, then allow a second muted attempt. At most two candidate attempts run concurrently, and the first ready candidate wins. Cancel all losing attempts. A controlled six-second stall must yield to a ready fallback in under three seconds; a failing replacement must preserve the current player. Readiness, codec validation, cancellation, and the thirty-second overall budget remain enforced.
- No downloaded-file cache or persisted signed-source cache was introduced. The active player remains retained while paused; swapping/stopping releases it. Thus there are no new disk entries, expiry records, partial files, or disk-growth policy to maintain. System-managed streaming buffers/transfer bytes were not measured or claimed to be a durable offline cache.

## First-five prefetch decision

Do not automatically prepare all five visible results in this change. Each measured fresh resolution alone costs about 8–9 seconds, so five serialized resolutions would consume about 40–45 seconds of work before native preparation; parallelism trades that for additional concurrent processes and streams. This is an estimate from per-track timings, not a completed five-track benchmark. Four of five speculative preparations may never be selected, upstream failures remain possible, and `PreparedPlayback` is single-use rather than a reusable committed-player cache.

The user explicitly allowed a faster foreground preparation path instead. Bounded candidate fallback and loaded-item reuse deliver that without speculative network work, additional players retained for unselected tracks, or new media storage. Revisit prefetch only if measured interaction traces justify the bandwidth and a bounded prepared-item lifecycle. Search metadata caching is handled by the separate faster-search goal.
