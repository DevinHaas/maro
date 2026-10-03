# Breakdown of the remaining lookup delay

Measured 2026-10-01 in response to the user's question about the remaining eight seconds. No media download/playback, app changes, or installation changes. All successful probes used the same minimal environment as the app and ran outside the restricted execution sandbox. The initial sandbox-only attempts exited with failure and are excluded.

| Probe | Seconds |
| --- | ---: |
| Development extractor, version only, run 1 / 2 | 6.690 / 6.460 |
| Installed extractor, version only, run 1 / 2 | 6.628 / 6.498 |
| Fresh search: Python/debug initialization reached | 6.499 |
| Fresh search: batch complete / process exit | 7.879 / 7.945 |
| Exact long-video resolve: initialization reached | 6.490 |
| Resolve: webpage request begins | 6.634 |
| Resolve: visionOS player metadata request begins | 8.012 |
| Resolve: HLS manifest request begins | 8.189 |
| Resolve: player JavaScript request begins | 8.373 |
| Resolve: JS challenge / Node starts | 8.439 / 8.448 |
| Resolve: process exit | 8.980 |

Stage timestamps mark log emission/request starts, not isolated request durations. Raw verbose lines, signed stream URLs, and response data were not emitted. Search used the existing 20-result flat search and fixed query `Bach cello suite no 1`; resolution used `c3suauAz0zQ`.

Conclusion: roughly 6.5 seconds of each invocation is local executable startup, even for `--version` with no YouTube lookup. The earlier roughly eight-second extraction figure combined that startup with actual source work. It should not be described as eight seconds of YouTube network latency. The current app starts a fresh process for each uncached search and fresh resolution.

The [pinned release build](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/.github/workflows/build.yml) produces standalone and directory-based macOS artifacts. [PyInstaller documents](https://pyinstaller.org/en/stable/operating-mode.html) that single-file packages unpack support files at startup. Packaging is therefore the first optimization candidate; these probes do not separate unpacking, OS validation and runtime initialization within the measured 6.5 seconds.

Next experiment: benchmark the verified, pre-unpacked directory distribution before changing the app's packaging. This may improve both search and stream resolution without an API integration. No resulting speedup is claimed until tested, and no packaging change was made in this explanation-only turn.
