# Spec: Maro / Tidal terminal visual style

Date: 2026-10-04. Approved foundation: Maro / Tidal v1.0.
Layout baseline: `ce978cf6738a92583770931238b0492ed1acbe42` in redesign PR #7.
Published as [GitHub issue #8](https://github.com/DevinHaas/maro/issues/8),
labelled `ready-for-agent`.

## Problem Statement

Maro currently has the desired Spotify-style arrangement and music interactions,
but its black surfaces, bright green accents and system typography do not express
the personal terminal workstation the user wants. The user has approved the
Tidal style and branding guide, including its fonts, and wants that visual
identity applied to the current application.

Changing the theme must not change where anything is. A user must find the same
buttons, artwork, navigation, search, playlist columns and player controls in
exactly the same positions. The eventual ability to customize colors and
background images should be supported by the styling architecture without
expanding this first implementation into a theme editor.

## Solution

Apply the approved blue-green Tidal theme to the native Maro interface: deep
ocean surfaces, soft Mint actions, Cyan supporting details, Foam text, fine
inset borders and JetBrains Mono typography. Keep the existing layout,
responsive behavior, content and interactions intact.

The initial release uses a solid Abyss background and one default palette.
Shared semantic styling roles make future presets and wallpaper customization
possible. The guide's preview controls are demonstrations, not application
features to implement in this release.

## User Stories

1. As a listener, I want Maro to feel like a calm terminal workstation, so that the application reflects the visual direction I approved.
2. As a listener, I want deep blue-green surfaces with Mint and Cyan accents, so that the default theme feels coherent across the application.
3. As a returning user, I want every panel and button to remain in its existing position, so that my muscle memory continues to work.
4. As a user resizing the window, I want the same responsive layout and breakpoints, so that resizing behaves exactly as it does today.
5. As a listener, I want JetBrains Mono in the approved hierarchy, so that headings, track information and controls share the terminal character.
6. As a reader of long titles, I want the existing wrapping and truncation behavior preserved, so that typography changes do not crowd adjacent controls.
7. As a reader of multilingual titles, I want unsupported scripts and emoji to remain readable, so that the chosen font does not lose music metadata.
8. As a listener checking progress, I want aligned duration and position numerals, so that changing values remain easy to read.
9. As a Home user, I want the hero, quick tiles and recommendation cards restyled in their current slots, so that discovery stays familiar.
10. As a library user, I want filtering, selected rows and hover feedback to remain clear, so that I can recognize my current destination.
11. As a search user, I want the existing search field and caret to remain readable in the new theme, so that typing still feels native and dependable.
12. As a search user, I want suggestions to open at the same anchor with the same keyboard behavior, so that I can use previews without relearning them.
13. As a search user, I want full results, reveal-more and source failure states to use the same visual language, so that search feels integrated with the application.
14. As a playlist user, I want the header, metadata, track columns and action slots to retain their dimensions, so that browsing and managing playlists stay predictable.
15. As a playlist user, I want the active playback occurrence distinguished in Mint, so that I can identify the playing row even when a video appears more than once.
16. As a playlist editor, I want drag handles, reorder feedback and save recovery to remain visible and usable, so that styling does not interfere with editing.
17. As a Favorites user, I want a coordinated blue-green fallback treatment, so that this collection belongs to the new identity.
18. As a listener, I want album art and video thumbnails to retain their original colors and crops, so that I can recognize music visually.
19. As a listener navigating between views, I want the bottom player to remain fixed and playback to continue, so that a cosmetic change does not interrupt music.
20. As a listener seeking or changing volume, I want the same slider positions, hit regions and value behavior, so that controls remain precise.
21. As a keyboard user, I want an obvious focus indicator with unchanged focus order and shortcuts, so that every existing action remains accessible.
22. As a user opening actions and dialogs, I want their current placement, choices, confirmations and focus restoration preserved, so that playlist management remains trustworthy.
23. As a user encountering unavailable media, loading or errors, I want readable existing messages and disabled states, so that I understand what is happening.
24. As a user who prefers reduced motion or transparency, I want the new styling to honor those preferences, so that its atmosphere does not reduce comfort or readability.
25. As a user of Maro, I want the lowercase wordmark to use the approved identity in its current frame, so that the branding changes without displacing navigation.
26. As a future theme customizer, I want visual roles separated from layout, so that later color and background changes cannot rearrange the application.
27. As a maintainer, I want before-and-after evidence of identical geometry and unchanged behavior, so that this release can be reviewed as a visual-only change.

## Implementation Decisions

- **Native application scope.** Style the existing AppShellView, library,
  Home, search field and preview, search results, Favorites, playlist detail,
  row actions, application-owned dialogs and BottomPlayerView. Use the shared
  AppDesign layer for common primitives. The HTML guide is a reference artifact;
  this work remains SwiftUI/AppKit. Platform-owned menus and system dialogs
  retain their native structure and behavior; apply supported styling only.

- **Baseline and structural invariant.** Freeze geometry against the current
  production baseline at the same logical viewport, backing scale, content,
  application state and scroll offset. This includes resolved frames, text
  containers, baselines, row and column dimensions, gaps, padding, button
  centers, hit regions, overlay anchors, clipping and responsive rules. Do not
  change structural layout constants, alignment, view order or spacing to make
  the theme fit. Existing behavior and accessibility semantics remain intact.

  | Existing anchor | Required measurement in logical points |
  | --- | --- |
  | Top navigation | 64 high |
  | Library sidebar | 280 below 1200 window width; 320 at or above 1200 |
  | Panel gap / outer horizontal inset | 8 / 8 |
  | Bottom inset / player | 4 / 88 high |
  | Global search | 44 high; current maximum width 520 |
  | Standard icon button / Home overlay play / playlist play | 38 × 38 / 44 × 44 / 62 × 62 |
  | Home hero / playlist header | 260 / 320 high |
  | Home card / artwork | 196 wide / 176 × 176 |
  | Library / playlist-row artwork | 50 × 50 / 44 × 44 |

  These anchors are not a replacement layout specification. All additional
  measurements come from the current resolved production views.

- **Theme structure.** Use the guide's primitive → semantic → component
  hierarchy. Resolve purpose-based roles centrally and consume them in shared
  components and screen-specific paint. Keep raw palette values out of individual
  views. Any compatibility aliases must resolve to the same semantic roles.
  The initial theme is immutable and selected by default; introduce no user
  settings, persistence format, import/export interface or theme switching UI.
  Existing controller, source, search, playlist, queue and playback interfaces
  need no behavior or API changes. Styling has no geometry fields.

- **Approved default palette.** Use these exact values at full opacity unless
  an existing state requires compositing. Do not reuse Spotify green for an
  application-owned accent.

  | Semantic role | Hex value |
  | --- | --- |
  | Canvas / Abyss | `#0B151A` |
  | Panel / Ocean | `#10232B` |
  | Raised / Lagoon | `#18323B` |
  | Hover surface | `#21434C` |
  | Selected surface | `#1D4547` |
  | Primary text / Foam | `#DDF1F0` |
  | Secondary text / Mist | `#A0BDC4` |
  | Text on accent | `#0B151A` |
  | Disabled text | `#78949E` |
  | Primary accent / Mint | `#91DAB8` |
  | Primary hover / pressed | `#ABEDCE` / `#79C9A7` |
  | Secondary accent / Cyan | `#82CDDF` |
  | Decorative border | `#2B4A54` |
  | Interactive border or track | `#729CA6` |
  | Focus border | `#B5F3E8` |
  | Success / information | `#91DAB8` / `#82CDDF` |
  | Warning / error | `#E5C78D` / `#F0A0A0` |

- **Typography and native assets.** Bundle native-supported JetBrains Mono
  Regular 400, Medium 500 and Semibold 600 from the official distribution,
  preserve the SIL Open Font License and register the resources for the native
  app. The guide's WOFF2 files are browser assets, not the native font bundle.
  Use normal tracking, disable programming ligatures, and use tabular numerals
  for positions, durations and dates. Retain system fallback for unsupported
  scripts and emoji. SF Symbols remain native symbols, not font glyphs.

  Preserve current point sizes, line limits, scaling policies and baseline
  alignment. Headings and the wordmark use 600; titles and controls use 500
  or 600 where the current hierarchy emphasizes them; supporting text uses
  400. Key roles retain the current 24-point wordmark, 54-point playlist title,
  44-point Favorites title, 26/34-point adaptive Home hero, 28-point search
  heading, 23-point Home section heading, 15-point library heading, 14-point
  row titles, 13-point search preview title and existing 10–13-point supporting
  text. Retain the playlist title's current two-line limit and minimum scaling
  factor of 0.6; retain the Home hero's existing adaptive threshold.

  Measure intrinsic text and resulting parent geometry before substitution.
  Constrain the new face to the same resolved text areas without reducing
  point sizes, altering tracking or expanding frames. If a role cannot fit
  while preserving these requirements, retain its existing font for this
  release and document the specific role and evidence. Surface that exception
  in visual review; never silently accept geometry drift. This rule applies
  to native text-field bridges as well as SwiftUI text.

- **Branding.** Render the four-letter lowercase `maro` wordmark in JetBrains
  Mono 600 and Foam, retaining its current 24-point size, resolved frame and
  position. No appended prompt, cursor or brackets. Existing application copy
  stays unchanged. The optional external tagline and marketing clear-space
  rules do not add content or spacing to the application.

- **Surface and component mapping.** Use Abyss for outer chrome and the player,
  Ocean for main panels, and Lagoon for raised elements, search and application-
  owned menus, sheets and the preview. Keep the current transparency of rows
  until hover or selection requires its semantic fill. Use fine 1-point inset
  framing where the guide calls for a border. Preserve the existing 5/6/8-point
  corner radii and existing circles and capsules. Borders must not add padding
  or change clipping bounds.

  Primary play/action fills use Mint with Abyss glyphs and the specified hover
  and pressed variants. Secondary icons use Foam, with Hover paint in their
  existing interaction area. Selected rows use the Selected surface; playing
  occurrence titles use Mint without changing occurrence identity. Search
  uses Foam text, Mist placeholder, an Interactive edge and visible native
  caret/selection. Slider tracks use Interactive and progress uses Mint;
  preserve existing knob visibility, values, gestures and keyboard behavior.
  Keep all existing SF Symbol names, sizes, positions and action availability.
  Favorites fallback may use Lagoon-to-Cyan with the existing symbol; ordinary
  fallback artwork uses Lagoon and Cyan. Real artwork is never recolored.

- **Focus and feedback.** Use a visible 2-point inset Focus stroke on
  application-owned controls where applicable, preserving existing focus
  semantics and bounds. Decorative and focus overlays do not intercept input
  or enter the accessibility tree. Hover/pressed feedback changes paint only;
  allow approximately 120 ms color transitions with no scaling or translation.
  Reduced Motion disables new decorative transitions. Preserve functional
  loading and playback feedback. Keep current labels, full-title accessibility
  values, shortcut mappings, focus order, Escape dismissal and focus restoration.
  Warning and error colors supplement existing messaging and state cues.

- **Background and future customization boundary.** Ship solid Abyss and
  opaque default panels. Do not ship a wallpaper or the preview landscape as
  the default. Reserve semantic styling as the future extension point for
  constrained colors, fonts and backgrounds. Future wallpaper work should
  render behind existing surfaces, use cover cropping, maintain a 92–100%
  Ocean veil where images are exposed, and keep controls, menus and text-heavy
  surfaces opaque. Reduced Transparency must use opaque surfaces. Position,
  dimensions, spacing, density, hit regions and breakpoints must never become
  theme settings. No future background interface is implemented here.

- **Review sequence.** Before changing application paint, capture a fresh
  baseline from the pinned production views and prepare representative Home,
  playlist and search/player screenshots and an HTML mockup using the approved
  foundations and the measured layout. Native screenshots plus the HTML mockup
  are sufficient review artifacts; editable Figma frames are not required.
  Carry forward the application-mockup review gate; approval of this guide does
  not imply approval of unseen application designs. Prepare the screenshot and
  HTML package as a complete reviewable result before requesting approval of
  its version and scope. Then implement shared styling
  and migrate all scoped surfaces, inspecting each state against the baseline.

## Testing Decisions

- **Primary seam: the rendered native application.** Reuse the existing
  disposable redesign acceptance fixture, which hosts the actual production
  SearchWindow/AppShellView and their child views with local fake API responses,
  generated artwork and muted audio. Extend its observations and state coverage
  as needed; avoid introducing a separate mock component gallery as proof of
  application correctness. Test externally visible geometry, appearance,
  interaction and accessibility rather than private token implementation.
  The user confirmed this validation approach on 4 October 2026: “Yes, use
  that approach.”

- **Exact layout gate.** Compare baseline and themed views at 1440 × 900 and
  1024 × 768 logical content sizes, plus widths 1199 and 1200 at the same
  supported height to exercise the sidebar breakpoint. Verify both rendered
  glyphs and surrounding geometry at the existing Home-title adaptive threshold.
  Use the same backing scale, fixtures and settled state for each comparison.
  Record frames and hit regions numerically at the native view/accessibility
  boundary and use render/layout observations within the same fixture where
  SwiftUI does not expose an individual element. No production public testing
  API or second application architecture is required. Expect identical layout
  coordinates and dimensions, with no blanket one-point drift allowance.
  Check control centers, text bounds and baselines, preview anchor, player
  cluster, playlist columns and drag handle regions specifically. Screenshot
  overlays supplement measurements; intentional color, glyph shape and text
  antialiasing changes are not geometry failures.

- **Appearance and content states.** Capture Home, library filter, search
  preview, results, Favorites, playlist header and rows, active duplicate
  occurrence, bottom player and actions/dialogs. Include empty, loading,
  source failure, unavailable/disabled, focus, hover, pressed and selected
  states. Include long titles, failed covers, multilingual text and emoji to
  expose font fallback and clipping. Preserve actual artwork dimensions,
  color and crop. Check cold-launch font loading and the supported fallback
  path; record any role that retains its original font.

- **Readability and accessibility.** Check actual composited text/surface
  pairs for at least 4.5:1 normal text contrast and essential control/focus
  edges for at least 3:1 against adjacent surfaces. Decorative dividers are
  distinct from essential control boundaries; disabled states remain clearly
  recognizable. Verify keyboard traversal, focus visibility, full metadata
  labels, no duplicate overlay accessibility elements, Reduced Motion and
  Reduced Transparency. Palette calculations alone do not constitute an
  accessibility audit.

- **Behavior regression.** Reuse existing application navigation, global
  search, Home discovery, playlist dialog/library/reorder, playback timeline
  and controller tests. Build the native application and run the nonparallel
  Swift suite and existing isolated app/CLI lifecycle check. In the native
  fixture, repeat preview keyboard submission/dismissal, navigation during
  playback, duplicate-occurrence playback, seek/volume, modal focus restoration
  and keyboard reorder/save recovery. No new live authenticated API exercise
  is required for a styling-only release.

- **Evidence and limits.** Save before/after captures, numerical geometry
  comparisons and a concise acceptance report identifying baseline revision,
  viewports, font exceptions and any unverified interaction. Existing acceptance
  prior art has 20 captures and 135 passing Swift tests; that historical result
  must not be presented as verification of the new theme. Native end-to-end
  pointer drop and edge autoscroll were previously unverified; preserve the
  drag bridge and report any remaining verification limit explicitly. Build
  and behavioral success cannot substitute for visual and geometry review.

## Out of Scope

- Changes to layout, spacing, density, responsive rules, button placement or hit regions.
- New screens, music visualizers, terminal commands, ASCII control replacements or fake telemetry.
- New playback, search, recommendation, playlist, reorder or authentication behavior.
- A theme editor, additional selectable presets, color overrides, font picker, wallpaper upload/crop controls, preview/reset, or theme import/export.
- Wallpaper delivery, blur/glow/texture effects, animation systems, scanlines or glitch effects.
- Recoloring real album artwork or shipping borrowed inspiration imagery.
- An application icon replacement, new marketing site, copy rewrite or web migration.
- Broad architecture refactoring, API/schema migrations or replacement of existing test seams.

## Further Notes

- The user explicitly approved the style and branding guide, including fonts,
  on 4 October 2026: “I like the style and the branding guide lines a lot also
  the fonts.” This approval selects Tidal v1; the earlier request for a
  greenish/bluish default and exact layout remains binding.
- Authoritative handoff artifacts are the repository's Tidal written guide,
  interactive visual companion and token manifest. The theme name is Tidal;
  the product name remains Maro. The preview's alternate accents and scenic
  background demonstrate future customization and do not enlarge this scope.
  This specification includes the complete default palette and implementation
  contract so the published issue can be used independently of the local
  preview. The local supporting guide is `design/terminal-style/style-guide.md`,
  with its visual companion and token manifest alongside it.
- Reference board: [accepted terminal inspiration and foundation cards](https://canvas.bleat.ch/?board=maro-terminal-style-2026-10-03).
- Structural baseline: [redesign PR #7](https://github.com/DevinHaas/maro/pull/7).
  This specification extends its visual language; the previous redesign's
  behavior and acceptance evidence remain relevant prior art.
- Native font source: [official JetBrains Mono distribution](https://github.com/JetBrains/JetBrainsMono).
  Retain the bundled license and provenance when introducing native assets.
- Implementation is complete only when the scoped surfaces use the approved
  theme, geometry parity and existing behavior pass, and representative visual
  evidence is available with all exceptions explicitly recorded.
