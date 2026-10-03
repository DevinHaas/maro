# Bundled tools

Maro's local acceptance package includes pinned upstream executables and libraries:

- yt-dlp 2026.08.19, official macOS PyInstaller build. Its project license is in
  `yt-dlp-LICENSE`; the upstream aggregate for components in that executable is
  in `yt-dlp-THIRD_PARTY_LICENSES.txt`.
  Source: https://github.com/yt-dlp/yt-dlp/tree/2026.08.19
- Node.js 26.7.0, official Darwin arm64 build. Its project and bundled-component
  license notices are in `node-LICENSE`.
  Source: https://nodejs.org/dist/v26.7.0/
- CPython 3.13.15, Astral python-build-standalone 20260929 arm64 distribution.
  Its complete distribution (including licenses) is retained under `python/`;
  Python's license is `python/lib/python3.13/LICENSE.txt`.
  Native-library notices from the matching checksum-verified full build archive
  are in `python/licenses/`, with component/build provenance in `python/PYTHON.json`.
  Source: https://github.com/astral-sh/python-build-standalone/releases/tag/20260929
- Embedded yt-dlp 2026.8.19, yt-dlp-ejs 0.8.0, and certifi 2026.7.22.
  Their original wheel license notices are under
  `python/lib/python3.13/site-packages/<package>.dist-info/licenses/`.
  Source downloads and SHA-256 hashes are pinned in `worker.json`.

The session worker uses embedded yt-dlp; the older macOS executable is retained
for comparison/compatibility tooling and is not launched by the player.

The adjacent JSON manifests record upstream download locations and hashes before
local code signing. Packaging changes code signatures for local acceptance; it
does not patch these tools' implementation. Maro does not update them at runtime.

Complete upstream notices are copied verbatim from their pinned release and
checksum-verified before packaging. Refer to those notices for component-specific
copyright, license and source information. These local test builds are not a
published distribution or a claim of Developer ID signing/notarization.
