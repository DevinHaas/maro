# Tidal styling checkpoint

4 October 2026. The user approved application review v1 and then requested:
“it looks good already lets stop here and commit what we have.” Further work
stopped, and the current styling was committed on `codex/tidal-integration`.

The checkpoint includes the shared theme (#10), playlist headers/rows/actions/
dialogs (#11), and search/preview/results/player/timeline styling (#12). It
preserves native layout constants, symbols, artwork and existing behavior.
JetBrains Mono assets are bundled; displayed text retains the existing SF roles
under the exact geometry rule. The shared report distinguishes measured font
failures from conservative retained roles.

Before stopping, 30 scoped playlist regressions and 33 scoped search/player
regressions passed. Playlist native candidate probes observed header SF54 bounds
373×63, first baseline52, versus Mono54 bounds486×71, baseline55; row SF14 bounds
371×17 versus Mono14 bounds496×18, both baseline14. Creator SF11 bounds77.5×14
versus Mono11 bounds99×14, both baseline11. These failures retain SF. Playlist
captures and strict/normalized comparisons are saved under
`assets/tidal/playlists/`; normalized application geometry matches after only
arithmetic ULP normalization and the documented native scrollbar estimate
exception. A scrollbar thumb estimate also varied119.5→121pt in this run;
that is recorded in strict evidence, not accepted as application-layout drift.

The search worker removed a decorative outline that expanded an opaque AX group;
its final recapture/font report was interrupted by the stop request. These scoped
checks do not establish full merged acceptance. #13, composited contrast/focus/
keyboard coverage, final standards/spec review and PR readiness remain pending.
Shared focus helpers currently draw1pt strokes; the requested2pt focus treatment
still needs correction and native validation. Pointer-drop/edge-autoscroll
verification remains unclaimed. The PR stays a draft and issues stay open.
