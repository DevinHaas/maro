# Determine the fastest suitable YouTube search and retrieval approach

ID: 03
Parent: [Responsive SketchyBar player with reference-aligned controls](../map.md)
Type: research
Labels: wayfinder:research
Mode: AFK
Status: resolved
Assignee: retrieval_research
Blocked by: none

## Question

How does Maro currently fetch search results and resolve audio, and could the official YouTube Data API or an improved existing extractor path reduce latency without conflating metadata search with playable-audio access?

## Goal

Produce an evidence-backed source decision for the faster-search implementation, with current official documentation, a trace of the existing path, authentication/quota/operational tradeoffs, and an explicit distinction between documented capabilities and latency hypotheses requiring measurement.

## Required research

- Read `YouTubeSource.swift`, `YouTubeClient.swift`, `ExtractorProcess.swift`, and the search UI/controller callers. Identify process startup, result limits, caching, debouncing/cancellation, metadata enrichment, and load-more behavior.
- Verify official YouTube API search/metadata capabilities, playable audio limitations, key/authentication requirements, and current quota/caching requirements using primary documentation. Do not assume an official metadata API prepares or serves native audio.
- Compare keeping and optimizing the current provider, staged first-five metadata retrieval, and an optional official metadata provider. Preserve Previous/Next's full bounded fetched-list contract; identify any behavior change explicitly.
- Recommend the smallest useful route that works with available configuration. If an optional API requires credentials, leave a working no-key default and define when measured evidence would justify the integration.
- Save a concise research artifact on a throwaway `research/maro-search-retrieval` branch/worktree, link the artifact and branch context in `## Answer`, and distinguish local observations from proposals. Do not mutate runtime code or the installed app.

## Completion

Append findings as a resolution, resolve this ticket, and add a one-line context pointer to the map. Do not claim measured API speed without comparative measurements. Surface new questions only when the research makes them concrete.

## Answer

Resolved 2026-10-01 by retrieval_research. Keep the current no-key provider; measure separate stages, then prioritize bounded metadata reuse and identical-query work sharing. Benchmark extractor caching separately. Do not reduce the full 20-result navigation contract to the five visible rows.

The official YouTube Data API supplies search/video metadata, not playable native audio. Its documented background/audio-only restrictions also make it unsuitable as a drop-in upgrade. Current official quota, credentials, metadata-retention requirements, local source trace, and tradeoffs are documented in [Search and audio retrieval source decision](../assets/search-retrieval-research.md). No latency advantage is claimed without measurement.

Research context: branch `research/maro-search-retrieval`, commit `60b4fa6`; isolated worktree `/Users/devinhasler/worktrees/maro/search-retrieval-research`, artifact `.scratch/maro-player-polish/assets/search-retrieval-research.md`. Only the research artifact was staged/committed; main application sources and installed playback were untouched. The branch preserves the note, not the untracked application snapshot. Scoped sandbox approval allowed the worktree/commit; nothing remains blocked.
