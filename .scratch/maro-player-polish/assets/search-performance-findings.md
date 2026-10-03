# Search measurements and cache policy

2026-10-01, same pinned extractor/runtime, same controller path, disposable state. `scripts/measure-search.swift` measures submitting the query through receiving the first five normalized results, then revealing the complete batch. No audio is prepared. Thumbnail downloads/rendering are outside these timings; full-list reveal adds only microseconds. This small sample is not a universal network benchmark.

| Query | Baseline cold | Baseline repeated | Updated cold | Updated repeated |
| --- | ---: | ---: | ---: | ---: |
| Bach cello suite no 1 | 7.806 s | 7.656 s | 7.808 s | 0.000022 s |
| ambience nordic vikings | 7.508 s | 7.691 s | 7.470 s | 0.000019 s |

All searches returned five initially visible results and twenty complete results without error. The target is eliminating extraction for fresh repeated queries, with warm controller completion below 50 ms and unchanged result completeness. Both warm measurements pass. Cold lookup is essentially unchanged; no cold speedup is claimed.

The controller retains eight validated 20-result metadata batches in memory for 60 seconds from fetch completion. Outer whitespace is normalized; case and internal text are preserved. Hits reset visibility to five. Load 5 more and Previous/Next retain the full batch. Least recently used entries are evicted. Expiry, source disable, and shutdown clear eligibility. Errors, canceled and obsolete responses are never cached. Concurrent identical requests share one complete operation. No signed URLs or media enter this cache.

Regression checks cover reuse, resetting visibility, full-batch retention, exact expiry, eviction, failed retries, same-query concurrency, stale completion and navigation. The reuse test failed before the change with two source calls, then passed with one. Keep the no-key provider for the reasons in [provider research](search-retrieval-research.md). New searches remain a separate possible optimization target.
