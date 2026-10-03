# Long-video progressive playback

Test date: 2026-10-01. Exact user example: [two-hour recording](https://www.youtube.com/watch?v=c3suauAz0zQ), 7,308 seconds. Pinned tools; separate muted players; the installed player and state were untouched by probes.

## Diagnosis

Maro already used a remote AVURLAsset rather than deliberately downloading a complete file. However, it accepted only progressive M4A formats and discarded native HLS audio streams. Two progressive candidates failed their 15-second asset deadlines; even the bounded candidate race failed after 17.055 seconds of preparation (25.165 seconds including resolution).

A 1 KiB range returned HTTP 206 in 0.162/0.084 seconds, with full lengths of 118,277,354 and 44,565,444 bytes. A temporary, bounded localhost relay showed AVFoundation requesting `bytes=0-1`, then `bytes=0-118277353`, followed by requests for the entire remainder from later offsets. Only about 1.1 MB arrived in the 25-second readiness window; readiness timed out. No signed URLs were logged. The relay was removed after diagnosis.

The observed slow large response is consistent with the [upstream report of large Googlevideo responses being throttled](https://github.com/yt-dlp/yt-dlp/issues/17612), although we do not claim a universal server threshold from this sample. Small range support alone did not make the native progressive path fast.

## Fix and measurements

Prefer validated audio-only HLS (`m3u8_native`, MP4, no video/DRM) through AVFoundation. Keep progressive AAC/M4A candidates as fallback. HLS sometimes lacks declared codec metadata; native manifest playability and item readiness remain mandatory before replacement. Existing host/header validation and finite preparation deadlines remain. Prefer a 30-second native forward buffer; this is an AVFoundation preference, not a hard byte cap or a durable offline cache. No custom downloader, proxy, transcoder, or ten-minute initial download is needed.

| Production path | Resolve | Native preparation | Total | Result |
| --- | ---: | ---: | ---: | --- |
| Exact long video, run 1 | 8.128 s | 0.383 s | 8.511 s | ready |
| Exact long video, run 2 | 7.985 s | 0.427 s | 8.412 s | ready |
| Earlier cello example | 8.570 s | 0.506 s | 9.076 s | ready |
| Earlier short Jingle Bells example | 8.981 s | 0.094 s | 9.075 s | upstream/native source failed |

The short example exposed no HLS on that extraction and remains intermittently unavailable, as it was before this change. Existing fallback cannot guarantee YouTube availability. No universal availability fix is claimed.

Independent native probes of both HLS audio variants advanced silently for three seconds, fetching 212,798 / 561,398 bytes and buffering to approximately 34.4 seconds. A seek to 21 minutes succeeded on each: playback advanced to approximately 1,262.86 seconds, with buffered ends around 1,295.9 seconds and cumulative transfers of 545,688 / 1,442,523 bytes. Neither downloaded the full recording. This verifies on-demand fetching beyond the initial region, not hours of sustained listening.

Reproduction: compile `scripts/measure-audio-preparation.swift` against the debug MaroCore module/objects, then pass the pinned extractor and Node paths followed by `--bounded c3suauAz0zQ c3suauAz0zQ`. For the isolated muted progress/21-minute seek probe, use `--verify-hls c3suauAz0zQ`. `--ranges` checks progressive candidates with 1 KiB reads. Signed URLs are neither printed nor persisted.

Verification: 74 Swift tests passed (the separate opt-in source test is skipped); release build, standalone signature checks, installer upgrade/rollback, native lifecycle/paused restore, and bar routing/migration checks passed. Tests cover HLS priority and rejection of unsafe/video/DRM candidates, progressive fallback, two-attempt concurrency/cancellation, current-player preservation, twenty pause/resume cycles without re-preparation, duplicate requests, and search reuse/expiry/eviction/stale completion.
