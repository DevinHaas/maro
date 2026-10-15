# Prefetch and warm playback — before/after

Date: 2026-10-15. Measured with `Tests/MaroCoreTests/PlaybackLatencyBenchmark.swift`
through the real controller, bundled yt-dlp worker and AVPlayer, muted. Metric:
click → controller reports `playing` (AVPlayer `timeControlStatus == .playing`).
Six public tracks (`dQw4w9WgXcQ, kJQP7kiw5Fk, mGQLXRTl3Z0, fJ9rUzIMcZQ, 7rlIwnDh7dE,
c3suauAz0zQ`), two rounds, same machine and network. Network samples, not guarantees.

```sh
MARO_BENCH_TOOLS=$PWD/.build/tools swift test --filter playbackLatencyBenchmark
```

| Scenario | Before (median) | After (median) | After min–max |
| --- | ---: | ---: | ---: |
| Cold click, nothing cached | 1.981 s | 1.906 s | 1.616–3.164 s |
| Resolution cached, no warmed player | n/a (always re-resolved) | 0.421 s | 0.220–1.492 s |
| Hover ≥3 s, then click | 1.981 s (= cold) | **0.029 s** | 0.020–0.427 s |
| Hover 0.5 s, then click (joins in-flight warm) | 1.981 s (= cold) | 1.444 s | 1.198–2.087 s |
| Playlist Next after 4 s of playback | 1.981 s (= cold) | **0.053 s** | 0.051–0.062 s |
| Extractor resolve alone | 1.556 s | 1.620 s | 1.401–3.633 s |

Cold-click and resolve-only are unchanged, as expected: speculative work never
touches the foreground worker. The single 0.427 s hover outlier is `dQw4w9WgXcQ`,
whose resolve regularly takes 2.5–3 s, so its warm was still in flight at the click.

## What changed

- `YouTubeClient` keeps resolved sources in memory (`ResolutionCache`, 50 entries)
  until 10 minutes before the earliest signed `expire` (capped at 2 h, 15 min when
  unsigned). Never persisted: URLs are IP-bound. A cached source that fails native
  preparation, or that AVFoundation rejects mid-playback, is forgotten and resolved again.
- Speculative resolves use a second worker interpreter, so they never queue ahead
  of a selection or search, and are never cancelled (cancelling kills the interpreter).
- The controller warms (resolve + muted, ready `AVPlayer`) in two latest-wins lanes:
  *upcoming* (next playable playlist item, or search neighbor, on each start) and
  *hover* (200 ms dwell on Home, search results, playlist rows and search preview,
  plus arrow focus in the preview). At most two warmed players are retained, for
  at most 30 minutes. A click on a warmed track commits it; a click on a warming
  track joins it. Restores at a saved position never use a warmed player.

## Rejected, measured

- yt-dlp disk cache (`cachedir`): resolve median 1.662 s vs 1.556 s — noise.
  The interpreter already keeps player JS warm.
- Reusing one `YoutubeDL` across resolves: same 3 HTTP requests per resolve, no gain.
- `player_client=web_safari` (with or without `player_skip=webpage`): 5 of 6 tracks
  failed with no audio formats. The defaults are already the fast, working path.
