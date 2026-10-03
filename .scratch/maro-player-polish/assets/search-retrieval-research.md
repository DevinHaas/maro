# Search and audio retrieval source decision

Research date: 2026-10-01. Scope: provider decision, not implementation or a latency benchmark.

## Decision

Keep the existing no-key yt-dlp provider for this performance effort. Measure search and audio readiness separately, then remove redundant metadata work before considering a provider migration. The official Data API can replace metadata search; it cannot replace native audio resolution, and its documented client restrictions make it unsuitable as a drop-in addition to this background/audio-only player.

## Observed local path

- SearchWindow submits whole queries through Search/Return, not per-keystroke live search. It cancels its prior task. MaroController also cancels prior searches and rejects stale completions by search ID; there is no explicit debounce to optimize. Each accepted request clears the session and calls searchSource. [Search UI](../../../Sources/MaroApp/SearchWindow.swift), [controller](../../../Sources/MaroCore/MaroController.swift).
- YouTubeClient starts a fresh extractor process for each search. YouTubeSource requests flat `ytsearch20`, caps results at 20, waits for one JSON document, and deduplicates IDs. Search therefore already avoids resolving every result. Flags include `--no-cache-dir`, `--skip-download`, 15-second socket timeout, and no retries; the outer process deadline is 45 seconds. These are ceilings, not measured latency. [source arguments](../../../Sources/MaroCore/YouTubeSource.swift), [client](../../../Sources/MaroCore/YouTubeClient.swift), [process](../../../Sources/MaroCore/ExtractorProcess.swift).
- Five results are visible initially; “more” reveals another five already fetched. Previous/Next navigate the full fetched set. Selection separately resolves a watch URL into compatible HTTPS audio candidates, then AVURLAsset prepares remote streaming. No prepared audio file is produced by search. Application metadata/source caching is absent; artwork has its own cache. [session](../../../Sources/MaroCore/PlayerState.swift), [asset preparation](../../../Sources/MaroCore/AudioAssetLoader.swift), [artwork](../../../Sources/MaroCore/ArtworkCache.swift).

These observations describe the current working tree, whose app sources are untracked; the research commit does not snapshot application source.

## Current primary-source findings

1. Official `search.list` returns resource IDs and snippets. Use `type=video`; `maxResults` accepts up to 50, with pagination tokens. A 20-result page can preserve the existing bounded list. Duration requires video metadata rather than a playable stream: `videos.list(part=contentDetails,id=...)` supplies ISO 8601 duration. The published resource schemas expose metadata and embedded-player information, not native audio URLs. [search.list](https://developers.google.com/youtube/v3/docs/search/list), [videos.list](https://developers.google.com/youtube/v3/docs/videos/list), [video resource](https://developers.google.com/youtube/v3/docs/videos).
2. A Google project, enabled API, and credentials are required; the official public-search example uses an API key. User-authorized operations require OAuth. Current docs list defaults of **100 search.list calls/day**, **100 videos.insert calls/day**, and **10,000 units/day shared by other endpoints**. Check the actual project's quota before sizing usage; do not carry forward the older 100-units-per-search assumption. Partial responses and ETags reduce payload/revalidation work; they do not prove faster Maro startup. [setup and efficiency](https://developers.google.com/youtube/v3/getting-started), [search example](https://developers.google.com/youtube/v3/docs/search/list), [quota table](https://developers.google.com/youtube/v3/determine_quota_cost).
3. API policy permits temporary limited non-authorized metadata storage for at most 30 calendar days before refresh/deletion. Metadata caching does not authorize media caching: audiovisual storage needs prior written approval; separating audio and background playback are prohibited API-client features. These are direct provider-fit constraints, not reasons to stop unrelated local optimization. [Developer Policies, III.E.1, III.E.4, III.G](https://developers.google.com/youtube/terms/developer-policies).
4. yt-dlp's filesystem cache stores extractor information such as client IDs/signatures; it is not an audio-file cache. Flat extraction can omit metadata and avoids fully extracting each entry. Simply removing `--no-cache-dir` therefore cannot guarantee reusable audio or faster search. [yt-dlp options](https://github.com/yt-dlp/yt-dlp#usage-and-options).

## Smallest implementation route

| Option | Expected opportunity, still unmeasured | Decision |
| --- | --- | --- |
| Keep provider; bounded metadata cache and identical-query work sharing | Avoid repeat subprocess/network work on a valid cache hit; preserve cancellation ownership and explicit refresh | First candidate; short TTL and small entry cap, no failure caching |
| Enable a dedicated extractor cache | May avoid repeated extractor setup; separate from metadata and prepared media | Benchmark with identical extractor/version; retain only if useful |
| Fetch five first, then remaining results | Might improve first paint, but repeats startup/search work and can change ranking/order | Defer unless measurements show a net benefit; never silently reduce navigation to five |
| Official metadata API | Removes search subprocess, adds credential/quota/metadata-enrichment work; still needs a playback path | Defer; requires a compatible product playback model and comparative evidence |

Measure subprocess startup, metadata fetch/decode, first-five display, source resolution, asset readiness, and repeat-query hits separately with the same query set and cold/warm runs. Record error rates alongside median/tail latency; do not claim one API is faster without data. Preserve the full 20-result contract, stale-response suppression, and no-key operation. Repeat pause/resume and speculative preparation belong to the audio lifecycle goal and should not be credited to faster metadata search.

No API key was provisioned, no app runtime changed, and no audible playback or provider latency benchmark ran. Research branch: `research/maro-search-retrieval`; its isolated worktree contains only this artifact atop the existing initial commit.

