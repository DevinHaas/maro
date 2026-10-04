# Maro terminal styling direction

Mode: standalone shared foundations for a cosmetic redesign. Updated: 2026-10-04.
Stage: style and branding guide v1 approved; implementation specification published as issue #8.
No Figma mockup or application styling change has been made.

The user wants a terminal-looking, sophisticated, highly customizable music
application, with the exact layout and button positions of the current Maro.
The baseline is redesign PR #7, integration `ce978cf`, and its screenshots in
`docs/specs/assets/spotify-redesign/acceptance/`.

## Revised direction — user examples take precedence

The user rejected the initial dashboard direction and added three examples to
the canvas: a translucent PowerShell window with ASCII artwork, a blue illustrated
Linux desktop with terminal panes and audio bars, and a lavender desktop with
compact widgets, terminal typography and a music visualizer. These examples were
visually inspected. Their source attribution is unknown.

Search now follows customized terminal desktops: navy/indigo surfaces, soft
pastel accents, translucent panels over optional scenic backgrounds, thin
borders, monospace text, ASCII identity and restrained music visualization.
The former Precision Console / Phosphor Studio / Amber Archive recommendation
and token palette are superseded. R1–R4 were explicitly discarded (feedback
5–8); R5 has no selection. None is evidence of an approved direction.

Six new original-resolution references were inspected and added below the
user's examples. Each has attribution and a source-page link on the canvas:

| Reference | Source | Original pixels | Transferable styling |
| --- | --- | --- | --- |
| N1 Worm | syndrizzle/hotfiles | 4300 × 3300 | Pastel terminals, audio bars, compact widgets |
| N2 BSPWM | syndrizzle/hotfiles | 4300 × 3300 | Navy panels, illustrated backdrop, music widgets |
| N3 Aphelion | elenapan/dotfiles | 1920 × 2160 | ASCII identity, coordinated terminal controls |
| N4 i3 | Keyitdev/dotfiles | 1920 × 1080 | Translucent music queue and visualizer |
| N5 Catppuccin BSPWM | adarsh-67r/bspwm-dotfiles | 1920 × 1080 | Cyan borders, pastel code colors, ASCII art |
| N6 rmpc | mierak/rmpc | 1444 × 807 | Album artwork, track list, spectrum bars |

Pinterest and Dribbble were searched again. The relevant Pinterest original was
only 640 × 1080, so it was excluded from the canvas. Several desktop previews
were only about 500 pixels wide and were also excluded. The strongest available
originals came from creators' public galleries. Rate-limited Imgur images and
unavailable GitHub attachment URLs were skipped.

## Locked layout

Preserve the top navigation/search bar, searchable left library, main content
panel, Home hero and card slots, anchored search preview, playlist header and row
columns, action sheets, and bottom player. Preserve all panel dimensions, gaps,
padding, control centers, hit regions and scroll behavior at each existing
viewport. Keep current navigation, search, playlist, reorder and playback
behavior. A typography change must fit existing text boxes; use the existing
truncation and full accessibility labels rather than expanding a control.

Apply borders with inset strokes. A smaller painted corner radius or a different
button fill must not change a frame or hit region. Retain the existing circular
play controls' bounds and centers. Render artwork in its existing bounds.

## Typography and theme decisions

The user accepted the revised reference set as the basis for a style/branding
guide and explicitly requested a greenish/bluish default. **Maro / Tidal v1** is
defined in `style-guide.md`, with a visual companion in `guide.html` and reusable
three-layer values in `tokens.json` / `tokens.css`. Default: deep blue-green
surfaces, Mint actions, Cyan support and Foam text; JetBrains Mono 400/500/600.
Current point sizes and resolved text frames remain locked. A role that cannot
fit keeps its current system font and is recorded as a handoff exception.

Default backdrop is solid Abyss; an original vector landscape demonstrates later
background customization. Image-enabled Ocean panels have a 92–100% veil;
controls remain opaque. Font files and the official OFL are bundled only for
the guide preview. The user approved the v1 foundation, including fonts, on
4 October and requested its implementation specification.

Use native-supported JetBrains Mono assets for the application, preserving the
font license. Preserve current text-box sizes, heading hierarchy and readable
body sizes. Use tabular numbers for position, duration and dates. Avoid tiny
all-caps body text or labels that imply an actual command interpreter.

## Customization model

Use semantic roles now, with one solid-background Tidal default. Later, offer
constrained colors/fonts and background customization, presets, preview, reset
and versioned theme import/export. Keep current geometry and real artwork
colors fixed. The current implementation spec excludes the settings interface,
wallpaper delivery and decorative effects.

Open theme settings from the existing account menu so the main screen gains no
new control position. Existing geometry remains fixed across presets and custom
themes. Keep keyboard focus obvious, check text contrast, honor reduced motion,
and default decorative texture and glow off. A terminal appearance does not
require fake telemetry, new visualizer panels, or new shell functionality.

## Evidence and workflow setup

Local references and provenance:
`inspiration/terminal-music-2026-10-03/metadata.json` and five images alongside it.
All five images have unknown reuse licenses and are research references only.

Revised originals and provenance:
`inspiration/terminal-music-2026-10-03/refined/metadata.json`.
No upscaling, screenshot recreation or recompression was used. The saved canvas
assets retain the originals' pixel dimensions and byte counts. Display frames
preserve aspect ratios and stay below half the source width, providing at least
two source pixels per displayed canvas unit at 100% zoom. Earlier thumbnail
research is retained as superseded provenance, not reused as the revised set.

Canvas: https://canvas.bleat.ch/?board=maro-terminal-style-2026-10-03,
revision 83 (foundation cards added). Six new references and captions, plus the three user-added images
with their positions and sizes preserved. Last consumed feedback ID: 8.
The board is now accessible in the browser and the new images were visually
confirmed there, including N4 at a closer zoom. Preview:
`inspiration/terminal-music-2026-10-03/refined/canvas-quality-check.jpg`.
Eleven foundation groups now show eight colors, typography, the geometry lock
and the background customization contract below the references. No application
mockup approval has been inferred.

The local `@devin/laufwerk-workflows` package is installed into Maro using Bun.
The package currently exports `project-showcase`, `github-issue`, `issue-to-fix`,
`potential-customer-analysis`, and `rpi`; it contains no `design-inspo` source or
export. The existing `design-workflow` skill describes the inspiration/canvas
process and its role alongside RPI. That process was used for research; no
Laufwerk execution or design-inspo shim is claimed. The user was asked whether
to use the existing skill with RPI or create a standalone workflow.

## Approval record

The user authorized research, use of Laufwerk setup, and preservation of the
current layout. On 4 October, “Perfect. Now from those references ... create a
style guide as well as branding guidelines” accepted the reference set as the
basis for shared foundations. The follow-up “first I want to have it be a
greenish bluish color palette” fixes the default hue family; colors and background
images should be customizable later. The subsequent request, “I like the style
and the branding guide lines a lot also the fonts. Lets write a spec out of
that,” approves the Tidal v1 foundation and authorizes its implementation spec.
This does not approve unseen application frames.

Requested foundation deliverables are complete. The visual-only implementation
spec is `docs/specs/tidal-terminal-visual-style.md`. The implementation workflow
is tracked in https://github.com/DevinHaas/maro/issues/8 (`ready-for-agent`) and
must carry forward exact baseline geometry and review representative editable
Home, playlist and search/player states before application styling changes.

## Foundation verification

Token references resolve; local font/image/document links exist and the official
font license is preserved. Palette calculations meet the stated text/essential
edge contrast thresholds across default surfaces. The companion was inspected
at the browser's 1280 px viewport; no horizontal overflow. Accent and backdrop
switching, panel opacity, and play/pause specimen state were verified through
the UI. Controls remain opaque when panel translucency changes. Application
sources have not been edited, so no app build or visual migration is claimed.
