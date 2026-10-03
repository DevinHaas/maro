---
task: ad-free-youtube-music-player-with-search-and-favorites
type: design-prd
repo: DevinHaas/maro
branch: ad-free-youtube-music-player-with-search-and-favorites
sha: bfb50e9a5a29541d5ee837d1c5f06496296e3efb
---

# SketchyBar Music Player

### Problem to Solve

Mac users who want lightweight music playback while working must leave the menu bar and manage the full YouTube experience, adding visual clutter, interruptions, and context switching. The requested product should make music search, current-video recognition, play/pause control, and a small favorites collection accessible from SketchyBar while keeping listening simple.

No player exists in the current repository. The platform research establishes that ad-free, background, audio-focused YouTube playback cannot be delivered through YouTube's official APIs: official playback requires a visible embedded player and prohibits ad blocking, background playback, and separating audio from video. The product will knowingly use a Grayjay-style direct-stream approach instead, accepting that it is unofficial, may conflict with YouTube's terms and policies, and can break when YouTube changes undocumented behavior.

### What does business success look like, and how can we measure it?

Success is demonstrated through task-based acceptance rather than product analytics because this is a personal menu-bar utility. In a manual acceptance session, the user can:

- find and start a desired track without navigating a full YouTube page;
- recognize the current selection from its thumbnail and metadata;
- pause and resume the current selection;
- save a selection and replay it from a small favorites collection; and
- complete a 30-minute listening session without an unrecoverable playback failure, with any unavailable media or service error explained clearly.

### Proposed Solution

Build a compact, online-first SketchyBar music utility whose first release searches and plays only YouTube content. Following Grayjay's product model, the utility resolves playable media outside the official YouTube IFrame player and uses an application-controlled player for ad-free, background, audio-focused listening.

The product keeps the intended workflow—search, choose one video, start listening, recognize it, pause or resume it, and switch to favorites—without adding queues or other streaming catalogs. Local-file playback may follow later, but it is not required for the initial release. Non-commercial, personal use is the intended distribution model, but it does not remove the documented policy or breakage risk.

### Alternative Solutions Considered

- **Apple Music, Spotify, or another licensed catalog** — Rejected for the first release because the product is intended to support YouTube only.
- **Official YouTube embedded playback** — Rejected because its required visible audiovisual player, YouTube-served advertising, and prohibition on background or audio-only playback do not satisfy the desired listening experience.

### Solution Details

#### Discovery and favorites remain centered on YouTube

Search results, current-video information, and favorites all refer to YouTube videos. Favorites are a small product-owned collection of YouTube selections rather than a mirror of another music service's library.

#### Search begins in a focused companion panel

When nothing is playing, clicking the SketchyBar music item opens a lightweight search panel with keyboard focus already in its query field. During playback, the user opens the same panel through the Search action in the item's controls popup. The user types a YouTube search and sees the first five matching videos with a thumbnail, title, creator, and duration. **Load 5 more** appends the next five matches when the initial set is insufficient.

Selecting a result first checks whether the video offers a usable audio-only source. When it does, the selection replaces the loaded video and starts playback. Search results never become a queue, and loading more results does not change what is playing. The panel closes when playback starts so the interaction returns immediately to the menu bar.

When a result has no usable audio-only source, it is marked unavailable for this player. The current video and its playback state remain unchanged, and the search panel stays open so the user can choose another result. The utility does not fall back to a combined video/audio stream.

Opening or browsing Search does not interrupt the current video. It continues playing until the user selects a replacement, pauses it from the controls popup, or it reaches the end. Closing Search without choosing a result leaves playback unchanged.

```task-artifact
.humanlayer/tasks/ad-free-youtube-music-player-with-search-and-favorites/mockup-search-entry-options.html
```

```task-artifact
.humanlayer/tasks/ad-free-youtube-music-player-with-search-and-favorites/mockup-search-results-options.html
```

Search does not depend on Raycast, Alfred, a terminal, or another launcher. The companion panel exists because SketchyBar can display and click items but cannot accept editable keyboard text.

#### Playback controls only pause or resume the current video

Once a video is selected, the player exposes one transport action: pause while playing and resume while paused. It does not maintain a queue, advance to another search result, autoplay a recommendation, or expose next and previous controls. To change tracks, the user opens search again and explicitly selects another video; that selection replaces the current one.

When playback reaches the end, the video remains loaded and its state changes to **Ended**. The popup retains its thumbnail and metadata, and the transport action becomes **Replay**. Replay starts the same video from the beginning; only Search or selecting a favorite replaces it.

When the utility relaunches, it restores the last loaded video's thumbnail, metadata, and most recent playback position in a paused state. Playback never starts automatically on launch. If the restored video is no longer playable, the popup explains that it is unavailable and offers Search; favorites remain intact.

```task-artifact
.humanlayer/tasks/ad-free-youtube-music-player-with-search-and-favorites/mockup-end-of-track-options.html
```

#### The bar item opens a compact controls popup

Clicking the SketchyBar item while a video is loaded opens a popup rather than changing playback immediately. The popup shows the current thumbnail, title, creator, and playing or paused state together with three explicit actions: Play/Pause, Favorite, and Search. This keeps the persistent bar item compact and prevents accidental playback changes.

```task-artifact
.humanlayer/tasks/ad-free-youtube-music-player-with-search-and-favorites/mockup-bar-controls-options.html
```

Play/Pause toggles the loaded video's state, Favorite changes whether it belongs to the user's collection, and Search opens the focused companion panel. The popup reflects state changes immediately and remains the single control surface for the loaded video.

Playback is controlled only through this SketchyBar popup. The first release does not integrate with the Mac play/pause key, Control Center, Now Playing, or other system media controls.

#### Favorites stay inside the SketchyBar popup

The controls popup switches between **Now Playing** and **Favorites** without opening the larger search panel. Now Playing presents the loaded video's metadata and actions; Favorites presents up to 20 saved videos with a thumbnail, title, and creator for each entry, ordered with the most recently added favorite first.

```task-artifact
.humanlayer/tasks/ad-free-youtube-music-player-with-search-and-favorites/mockup-favorites-options.html
```

Selecting a favorite starts it only when a usable audio-only source is still available. Otherwise the favorite remains saved, an unavailable state is shown, and the current video continues unchanged. Favoriting or unfavoriting the current video updates the collection immediately. When 20 videos are already saved, trying to add another explains that the collection is full and asks the user to remove an existing favorite; the utility never deletes one automatically. Favorites do not form a queue, advance automatically, or sync to a YouTube account.

#### Playback prioritizes audio while preserving video identity

Selecting a result starts a usable audio-only source in the utility's player without displaying or streaming video. Audio-only availability is required: the utility never falls back to a combined video/audio source. The SketchyBar experience continues to show the video's thumbnail, title, and creator so the playing source remains recognizable. Playback continues while the user works in other applications and is controlled independently of a YouTube webpage.

#### Source breakage is expected and visible

The first release accesses YouTube anonymously and does not offer YouTube or Google sign-in. Public videos should work without an account, while age-restricted, private, member-only, personalized, or login-gated videos may be unavailable. The utility does not ask for credentials or attempt to bypass an account requirement; it explains that the video cannot be played and leaves the user able to search for another selection.

Videos may also be unavailable because of removal, geography, bot checks, format changes, or changes to YouTube's undocumented interfaces. The utility must distinguish an unavailable video from a broken source integration, explain when the user needs to retry or update, and never represent unofficial access as guaranteed.

When failures indicate that YouTube has broken the source integration rather than one video, the utility stops automatic retries and shows **YouTube source needs an update**. Search and playback remain unavailable until the user installs a compatible application update, while the favorites collection and loaded-video metadata remain intact. The utility does not repeatedly probe YouTube in the background because retries cannot repair incompatible extraction behavior and may worsen bot challenges.

#### The product consciously accepts an unofficial boundary

The first release intentionally follows the direct-stream behavior researched in Grayjay rather than YouTube's supported embedded-player path. This enables the desired ad-free and audio-focused experience but creates policy, enforcement, reliability, and maintenance risk. The product does not claim endorsement by YouTube or FUTO, and it does not treat personal or non-commercial use as making the approach officially permitted.

### Deferred to TDD

The technical design will determine how the Grayjay reference is adapted, including source-plugin ownership, YouTube request and response handling, audio-source selection, cipher and format compatibility, media playback, update delivery, process lifecycle, persistence, and the boundary between the companion panel and SketchyBar. These choices must preserve the product behavior and failure states defined here without expanding the first-release scope.

### Out of Scope

- Apple Music, Spotify, SoundCloud, or other online music catalogs
- Local-file playback in the first release
- A visible official YouTube player fallback in the first release
- Offline downloads or permanent caching of YouTube media
- Guaranteed access to restricted, private, removed, or region-blocked videos
- Queues, autoplay, recommendations, and next or previous navigation
- YouTube or Google account sign-in in the first release
- Mac media keys, Control Center, Now Playing, and other system media controls
