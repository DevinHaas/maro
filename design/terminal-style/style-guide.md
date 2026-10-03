# Maro — Tidal

Visual style guide and branding guidelines · v1.0 · 4 October 2026

**Direction:** a personal music workstation with a blue-green terminal aesthetic.
Deep ocean surfaces, mint actions, cyan details and clear monospace typography.
The terminal desktop references provide the visual language; Maro's existing
Spotify-style layout provides the complete structural baseline.

Status: foundation approved on 4 October 2026, including the palette, branding
and fonts. The user requested its implementation specification. Application
mockups still require their own review; this guide approves the visual
foundation while preserving the exact current layout.

Visual companion: [guide.html](guide.html). Reusable values: [tokens.json](tokens.json).
The CSS file powers the companion only; the application is native SwiftUI.

## 1. Brand identity

**Product name:** Maro. **Wordmark:** `maro`, lowercase, four letters.
**Personality:** calm, precise, personal, capable. Music comes first; the
workstation character makes the environment feel like it belongs to its user.
**Optional external tagline:** “Your music. Your environment.”

Use JetBrains Mono Semibold for the approved wordmark. Default to Foam on dark
surfaces; Mint is the accent version. Use Abyss on a light background. Keep all
letters the same color. Preserve proportions and baseline; no horizontal
stretching, gradients inside letters, glow or animated cursor.

For brand material, leave at least one lowercase `m` of clear space on each
side. Use a wordmark at least 20 px high for standalone digital material.
In the app, retain the current 24 pt wordmark size and its exact existing frame
and position. Standalone clear-space rules must not move nearby app controls.
No additional prompt, brackets or cursor is appended to the in-app wordmark.
An app-icon redesign is a separate asset decision; this guide does not replace it.

**Voice:** concise and human. Prefer “Search your library”, “Add to playlist”,
“Retry” and “Saved on this Mac”. Avoid shell commands, hacker language, fake
system telemetry or error codes as primary UI copy. Keep existing application
labels and messages during the visual migration. All caps are reserved for short
section labels already present in the baseline, not track names or paragraphs.

## 2. Default color palette

The default is **Tidal / Seafoam**. Blue-green neutrals occupy most of the screen.
Mint identifies primary actions and active playback; Cyan supports secondary
signals. Error and warning colors are functional exceptions to the palette.

| Token / name | Hex | Usage |
| --- | --- | --- |
| `surface.canvas` / Abyss | `#0B151A` | App chrome and bottom player |
| `surface.panel` / Ocean | `#10232B` | Library and content panels |
| `surface.raised` / Lagoon | `#18323B` | Search, menus, cards, sheets |
| `surface.hover` | `#21434C` | Existing hover surfaces |
| `surface.selected` | `#1D4547` | Persistent selected row |
| `text.primary` / Foam | `#DDF1F0` | Titles, labels, important content |
| `text.secondary` / Mist | `#A0BDC4` | Artist, duration, metadata, placeholders |
| `text.onAccent` | `#0B151A` | Glyph/text on filled Mint controls |
| `text.disabled` | `#78949E` | Inactive controls, with existing disabled behavior |
| `accent.primary` / Mint | `#91DAB8` | Primary action, active title, progress |
| `accent.hover` | `#ABEDCE` | Primary-button hover |
| `accent.pressed` | `#79C9A7` | Primary-button pressed state |
| `accent.secondary` / Cyan | `#82CDDF` | Supporting accents, information |
| `border.decorative` | `#2B4A54` | Panel dividers and decorative framing |
| `border.interactive` | `#729CA6` | Essential control edges and progress track |
| `border.focus` | `#B5F3E8` | Keyboard focus, 2 pt inset |
| `status.success` | `#91DAB8` | Success with a label or existing icon |
| `status.info` | `#82CDDF` | Informational feedback |
| `status.warning` | `#E5C78D` | Stale data or warnings |
| `status.error` | `#F0A0A0` | Failures and destructive actions |

Never use the decorative divider as the only visible edge of an interactive
control. Do not use color alone to communicate playback, selection or errors.
Keep the existing glyphs, labels and persistent state indicators.

Calculated minimum contrast across the five opaque surfaces above:

| Pair | Minimum ratio |
| --- | --- |
| Primary text / surfaces | 8.98:1 |
| Secondary text / surfaces | 5.30:1 |
| Mint / surfaces | 6.48:1 |
| Cyan / surfaces | 5.89:1 |
| Interactive border / surfaces | 3.52:1 |
| Error / surfaces | 5.13:1 |
| Abyss / Mint filled control | 11.37:1 |

These are palette calculations, not a claim that the application has passed an
accessibility audit. Require at least 4.5:1 for normal text and 3:1 for essential
non-text indicators, including every customized combination. Source:
[W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

## 3. Typography

**Primary family:** [JetBrains Mono](https://www.jetbrains.com/lp/mono/).
Regular 400 for content; Medium 500 for navigation and row titles; Semibold 600
for headings, emphasis and the wordmark. Use upright text, normal tracking and
tabular numbers. Disable programming ligatures in UI strings. Use system glyph
fallback for unsupported scripts and emoji; retain SF Symbols for icons.
The font is distributed under SIL Open Font License 1.1; preview font files and
the license are included in `fonts/`. The native application will need a
separate font-bundling decision during implementation.

**No new application type scale.** Preserve the point size, line limit,
alignment, baseline and bounding box of each current role. The source evidence
below is a handoff map, not permission to resize text containers.

| Current role | Existing point size | Proposed weight |
| --- | --- | --- |
| In-app wordmark | 24 | 600 |
| Playlist header | 54, existing scaling policy | 600 |
| Favorites header | 44 | 600 |
| Home hero | 26 / 34, existing width rule | 600 |
| Search page heading | 28 | 600 |
| Home section heading | 23 | 600 |
| Library heading | 15 | 600 |
| Library / playlist / result title | 14 | 500; 600 where already emphasized |
| Search-preview title | 13 | 600 |
| Artist / supporting body / duration | Existing 11–13 | 400 |
| Short captions / technical labels | Existing 10–11 | 400 / 500 |

Some current text views size themselves from their font. Before substituting a
family, measure and retain the original resolved text-container geometry so
intrinsic font metrics cannot push adjacent controls or change a row's height.
Keep the same line limits, ellipsis policy and existing scaling rules; preserve
full accessibility labels. Do not shrink every label or expand the layout to
make monospace fit. A role that cannot pass the geometry check retains its
current system font in v1 and is recorded as an explicit handoff exception.

## 4. Component styling

Preserve current corners (5 / 6 / 8 pt, capsules and circles), SF Symbol names,
icon sizes and artwork crops. Add fine 1 pt inset framing where appropriate;
use a 2 pt inset focus stroke. Neither stroke changes measured size or clipping.
Hover and pressed feedback changes paint only, without scale or translation.

| Component | Default | Hover / selected / pressed | Focus / disabled |
| --- | --- | --- | --- |
| Primary button / play circle | Mint fill, Abyss glyph | Mint Hover / Mint Pressed | Inset Focus stroke; disabled token and unchanged action availability |
| Secondary icon button | Transparent or existing Lagoon fill, Foam icon | Existing hover area in Hover | Inset Focus stroke; no added label or hit region |
| Search input | Lagoon fill, Foam text, Mist placeholder, Interactive edge | Existing hover region only | Inset Focus stroke; keep field height, caret and preview anchor |
| Library / playlist / search row | Existing transparent/default fill | Hover fill; Selected fill; active title in Mint | Existing focus semantics plus Focus stroke; preserve drag and row controls |
| Card / hero | Ocean or Lagoon, restrained blue-green gradient | Existing hover fill and play-overlay behavior | Current focus behavior; artwork stays full color |
| Menu / sheet / search preview | Opaque Lagoon, Foam text, subtle divider | Existing hover and selected rows | Focus visible; warning/error text paired with existing messaging |
| Player / seek / volume | Abyss chrome; Interactive track; Mint progress | Existing knob visibility and states | Existing keyboard/value behavior and hit bounds |
| Artwork fallback / Favorites | Lagoon fallback, Cyan symbol; Lagoon-to-Cyan Favorites treatment | No hover recoloring of real album art | Same image frame and accessibility semantics |

No new waveform or visualizer panel is introduced by this style guide. The
reference visualizers contribute color rhythm and technical character; adding
one to the app is a later feature requiring its own scope and placement.

## 5. Backgrounds and atmosphere

Default app background: solid Abyss. The companion also shows an original
blue-green vector landscape as an optional background demonstration.

Later, allow a user-selected background image, crop, tint and blur through theme
settings. Render it behind existing surfaces, clipped to the current window;
it never creates a new panel or changes layout. Use cover cropping rather than
stretching. Default tint follows the blue-green neutrals, with no animated
wallpaper, scanlines, bloom, glitch or noisy texture.

With an image enabled, Ocean panels may use 92–100% opacity. Controls, menus,
sheets and text-heavy rows remain opaque in v1. At 92% Ocean over pure white,
the composited surface is approximately `#23353C`: primary text 10.88:1,
secondary text 6.42:1, interactive edges 4.27:1. This solid veil provides the
contrast boundary; blur is atmosphere, not the readability mechanism.
Reduced Transparency uses opaque surfaces; Reduced Motion disables decorative
transitions. Existing functional loading/progress behavior remains intact.

Original album art and video thumbnails keep their colors, crop and recognition.
No duotone filter or scenic image replaces real artwork. Do not ship borrowed
reference screenshots or wallpapers as product assets without suitable rights.

## 6. Customization contract

The token architecture is **primitive → semantic → component**. Components
consume purpose-based roles, not individual palette hex values. Later presets
can remap these roles without touching structural code. The guide's accent and
backdrop controls demonstrate that separation; they do not add app settings.

Future theme fields: semantic colors, constrained font choice, background image
and crop/tint, allowed opacity, blur and optional decorative effects. Provide
preview, reset and import/export with a versioned schema. Open settings from the
existing account menu so this work introduces no new main-screen control.

Exclude position, size, padding, spacing, density, breakpoints, row heights,
hit regions and navigation behavior from the theme schema. Validate contrast
and font fit before a theme can be saved. Keep a solid-background preset for
readability and predictable rendering.

## 7. Geometry contract for the future spec

Baseline: redesign integration `ce978cf` / PR #7, source views in
`Sources/MaroApp/`, acceptance images in
`docs/specs/assets/spotify-redesign/acceptance/`.

| Existing value | Locked measurement |
| --- | --- |
| Top navigation | 64 pt high |
| Library sidebar | 280 pt below 1200 pt window width; 320 pt otherwise |
| Panel gap / outer horizontal inset | 8 pt / 8 pt |
| Bottom inset / player | 4 pt / 88 pt high |
| Global search | 44 pt high; current max width 520 pt |
| Standard icon / Home card play / playlist play | 38 / 44 / 62 pt |
| Home hero / playlist header | 260 / 320 pt high |
| Home card / artwork | 196 / 176 pt wide |
| Library / playlist-row artwork | 50 / 44 pt |

These are key anchors, not an exhaustive reconstruction. The future spec must
also lock every existing resolved frame, column width, gap, padding, overlay
anchor, hit region and responsive rule from the source/baseline. All button
centers remain identical at the same viewport and content state. In particular,
do not move the play controls, player cluster, preview popover, drag handles or
playlist row actions. Preserve scroll, keyboard, focus, reorder and playback.

Future acceptance gate: capture the same Home, playlist, search and player
states at 1440×900 and 1024×768, plus immediately below/at the 1200 pt sidebar
breakpoint. Compare frames and hit regions numerically; require identical
geometry. Use screenshot overlays to catch visible drift, with antialiasing
differences assessed separately. Verify empty/loading/error/disabled states,
long titles, unsupported scripts and background customization. Application
build and behavior tests supplement those checks; they cannot prove visual parity.

## 8. Reference traceability and handoff

[Canvas](https://canvas.bleat.ch/?board=maro-terminal-style-2026-10-03), N1–N6,
and the three user-added examples are the accepted basis for foundation work.
Last consumed feedback: 8; no newer feedback at guide creation.

| Evidence | Contribution |
| --- | --- |
| User PowerShell example | Translucency, ASCII detail, framed readouts |
| User blue desktop example | Blue-green atmosphere, fine borders, monospace rhythm |
| User lavender desktop example | Compact coordinated surfaces; hue translated to the requested blue-green |
| N1 Worm / N2 BSPWM | Coordinated terminal widgets and quiet desktop atmosphere |
| N3 Aphelion / N5 Catppuccin | ASCII identity, text hierarchy, disciplined terminal colors |
| N4 i3 / N6 rmpc | Music-specific rows, progress and artwork coexistence |

The user said “Perfect” to the revised references, requested guidelines for a
future spec, then specified greenish/bluish colors and later customizable
backgrounds. On 4 October 2026, “I like the style and the branding guide lines
a lot also the fonts. Lets write a spec out of that” approved this Tidal v1
foundation and requested its implementation specification. Application frames
still require their own review.

Implementation handoff: [visual-only redesign spec](../../docs/specs/tidal-terminal-visual-style.md),
with exact existing geometry and representative editable screen/state designs.
Application sources and behavior have not been changed by this guide.
