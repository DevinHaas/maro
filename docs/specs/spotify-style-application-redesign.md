# Maro application redesign: Spotify-style library, discovery, search, and playlists

Status: Published for review before implementation tickets.
Tracker: [GitHub issue #1](https://github.com/DevinHaas/maro/issues/1), labeled `ready-for-agent`.
Date: 2026-10-03.
Target: The existing native macOS Maro application.

## Problem Statement

Maro's current search and playlist surfaces support the essential operations, but separate tabs and utilitarian lists make browsing, discovering music, and managing a playlist feel disconnected. Users cannot keep their library visible while searching, preview results from a global search field, or discover suggestions on a home screen. Playlist editing relies on up/down arrows, and the visual hierarchy does not give cover artwork, playlist identity, and playback the prominence shown in the supplied Spotify references.

The user wants the first page to closely reproduce the layout and visual treatment of reference 1, with all personal playlists on the left, a dedicated library search, and suggestion cards in the main area. Global search should behave like reference 2. Playlist detail and track rows should follow references 3 and 4, with a cover-led header, one green playlist Play button, individual row playback, a trailing actions button, and drag reordering.

## Solution

Give Maro one persistent application window with a top navigation/search bar, a searchable library sidebar, a content panel, and a bottom playback bar. Open Home as the default page. Keep the library and player available while the user moves between Home, search results, and playlist detail.

Treat the four supplied screenshots as the visual acceptance reference: near-black chrome, separated charcoal panels, small gaps and rounded corners, prominent imagery, bold white titles, muted secondary text, compact playlist shortcut tiles, larger discovery cards, and green playback controls. Reproduce their spatial hierarchy and interaction flow closely using Maro's own content. Retain native macOS window controls and provide only controls backed by Maro features.

Home combines quick access to personal playlists with keyword-based video suggestions. Focusing global search opens suggestions and video previews; submitting opens a modernized version of the existing full results list. Playlist detail combines cover artwork and title with saved-order playback, modern rows, an actions modal, and drag editing that persists to YouTube.

This deliverable is one parent spec. Implementation tickets will be written after review.

## User Stories

1. As a listener, I want Maro to open on a Spotify-style Home page, so that browsing and starting playback feel familiar.
2. As a listener, I want my playlist library to remain visible beside the main content, so that I can switch playlists without changing tabs.
3. As a listener, I want every owned playlist available in the sidebar, so that playlists beyond the first API page remain discoverable.
4. As a listener, I want cover thumbnails, playlist names, and useful secondary text in the sidebar, so that I can recognize playlists quickly.
5. As a listener, I want to filter my library by playlist name, so that I can find a saved playlist without searching YouTube.
6. As a listener, I want clearing the library filter to restore my full library, so that I can return to browsing easily.
7. As a listener, I want the current playlist clearly selected, so that I know which playlist the main panel shows.
8. As a listener, I want a visible way to create a playlist, so that library management stays accessible.
9. As a listener, I want account connection and refresh actions available from the library, so that I can load and update my YouTube playlists.
10. As a listener, I want Favorites available in the library, so that the redesign preserves my existing saved videos.
11. As a listener, I want compact playlist shortcuts on Home, so that I can reopen playlists with one click.
12. As a listener, I want recommendation cards grouped into clear sections, so that I can discover videos without first inventing a search query.
13. As a new listener, I want suggestions even before I have favorites or playlists, so that Home is useful immediately.
14. As a returning listener, I want suggestions influenced by my favorites and playlist keywords, so that recommendations reflect my interests.
15. As a listener, I want a short explanation such as “Because you like jazz,” so that I understand why a section appears.
16. As a listener, I want varied recommendations without repeated videos filling the page, so that discovery remains useful.
17. As a listener, I want to play a suggested video directly, so that discovery leads naturally to listening.
18. As a listener, I want to favorite or add a suggested video to a playlist, so that I can keep a discovery.
19. As a listener, I want recommendation loading or failure to leave my library and playback usable, so that discovery does not interrupt listening.
20. As a listener, I want a global search field at the top of every page, so that I can start searching from anywhere.
21. As a listener, I want suggestions and specific videos to appear when I focus search, so that I have a useful starting point before typing.
22. As a listener, I want previews to update as I type, so that I can recognize a useful result quickly.
23. As a listener, I want search previews to show thumbnails, video titles, and creators, so that I can distinguish similar results.
24. As a listener, I want clicking a suggested query to run that search, so that I can explore it without retyping.
25. As a listener, I want an explicit play action on a preview video, so that I can listen immediately.
26. As a listener, I want Enter in the search field to open the full results page, so that I can browse the complete result list.
27. As a keyboard user, I want to navigate search suggestions and dismiss them with Escape, so that the preview is fully usable without a mouse.
28. As a listener, I want search to ignore late responses for an older query, so that the preview always matches what I typed.
29. As a listener, I want modern, readable full search-result rows, so that long titles and useful video metadata are easy to scan.
30. As a listener, I want the existing reveal-more behavior preserved, so that I can continue browsing beyond the initially displayed results.
31. As a listener, I want clear loading, empty, and retry states for search, so that I understand what happened.
32. As a listener, I want a large cover image and playlist title at the top of playlist detail, so that the playlist has a strong visual identity.
33. As a listener, I want playlist description and available metadata beneath the title, so that I understand what I am opening.
34. As a listener, I want one prominent green Play button, so that I can start the full playlist in its current saved order.
35. As a listener, I want a play action on each playlist row, so that I can start at a specific video and continue through the remaining playlist.
36. As a listener, I want the current playing or paused row visually identified, so that I can locate the active item.
37. As a listener, I want unavailable videos shown clearly, so that I understand gaps in playback or metadata.
38. As a playlist owner, I want an actions button at the right of each row, so that editing controls do not clutter the list.
39. As a playlist owner, I want row actions in a modal, so that I can choose an action in a focused, readable surface.
40. As a playlist owner, I want to remove the exact occurrence I selected, so that another occurrence of the same video remains untouched.
41. As a playlist owner, I want to add a row video to another playlist, so that I can organize my collection.
42. As a playlist owner, I want to drag a row to a new position, so that reordering is faster than repeated arrow clicks.
43. As a playlist owner, I want a visible drop indicator and scrolling near list edges, so that I can place an item accurately in a long playlist.
44. As a playlist owner, I want the new order saved to YouTube, so that it survives refresh and matches my playlist elsewhere.
45. As a keyboard user, I want an accessible way to move an item to a chosen position, so that playlist editing does not require dragging.
46. As a playlist owner, I want duplicate videos to retain separate identities while dragging, so that I can move the intended occurrence.
47. As a playlist owner, I want clear recovery when a reorder fails, so that I know whether the new order was saved.
48. As a listener, I want browsing and editing to leave ongoing playback uninterrupted, so that navigation does not stop the music.
49. As a listener, I want edits to affect the next playlist playback rather than unexpectedly changing my active queue, so that listening stays predictable.
50. As a listener, I want bottom playback controls and the compact SketchyBar player to reflect the same playback state, so that either surface stays trustworthy.
51. As a listener, I want the window to adapt to a smaller display, so that controls remain usable at practical window sizes.
52. As a VoiceOver user, I want labeled controls, announced loading and save states, and predictable modal focus, so that I can use the full redesigned flow.

## Implementation Decisions

### Existing architecture and domain

- Keep the native AppKit/SwiftUI application and existing separation between the app, core playback/source logic, command interface, and SketchyBar integration. Build on the current controller, playlist library, authenticated playlist API, extractor worker, state store, and artwork cache.
- Use the existing vocabulary: video, creator, Favorites, playlist, playlist item/occurrence, saved order, and playback queue. A playlist item identifies a particular occurrence; video identity alone is insufficient for row selection, actions, drag payloads, or playback highlighting.
- The current app provides a Search window with Search and Playlists tabs, a compact player, local Favorites, owned YouTube playlists, account connection, playlist creation/rename/deletion, adding/removing items, position-based moves, and sequential playlist playback. Search currently uses the bundled extractor's bounded video search. The redesign replaces the tab-led browsing layout while preserving these behaviors.
- No dedicated domain glossary or ADR collection was found. Existing documented boundaries remain applicable: YouTube is authoritative for playlist edits, failures do not silently queue or repeat writes, and playback uses a captured queue that changes only when the user starts a new selection.
- Extend playlist metadata to expose available artwork, description, owner, and privacy. Extend playlist-item metadata for date added and duration only when available without resolving audio for every row. The current playlist summary contains only identity, title, and count; do not assume richer fields already exist. YouTube provides playlist descriptions, thumbnails, ownership, and privacy metadata. [Playlist resource reference](https://developers.google.com/youtube/v3/docs/playlists).

### Application shell and visual fidelity

- Default route is Home. Main content routes are Home, full search results, and playlist detail. Global search and library filtering are independent fields with separate state. Home and Back navigation preserve library selection, the last submitted query, and useful scroll position.
- At a roomy desktop size, use a top bar approximately 64–72 points tall, a library panel approximately 280–360 points wide, 8–12 point gaps between major panels, and a persistent bottom player approximately 80–96 points tall. Content and library scroll independently. These are starting design targets; validate proportions against reference 1 at matching viewport size.
- Use near-black outer chrome, a slightly lighter main/library surface, lighter hover/selected rows, large bold playlist titles, muted creator/description text, pill-shaped search, subtle borders, and a consistent green primary playback accent. Match reference spacing, imagery scale, and density; do not substitute a generic dashboard layout.
- Home uses a large editorial-style feature region, a compact grid of personal playlist shortcuts, and horizontal sections of larger recommendation cards. The feature region is backed by a real playlist or keyword collection and has a working action; do not show invented announcements or social metrics.
- Include Favorites and all owned playlists in the sidebar, with thumbnail, title, and honest secondary metadata. Playlist filtering is local, case/diacritic-insensitive, and does not make remote requests. Clearing it restores the full collection. A no-match state must not obscure the account/create/refresh controls.
- The reference's albums, artists, podcasts, social, and notification controls are not introduced unless a real Maro feature backs them. Keep Maro identity and use actual available artwork rather than copying Spotify logos, advertisements, or screenshot text into the product.
- Bottom controls share the existing playback controller: artwork/title/creator, play/pause, previous/next, seek timeline, elapsed/total time, volume, and Favorites. Respect existing availability states. Navigation never restarts playback. The existing compact SketchyBar player remains functional and synchronized.
- Resize gracefully: reduce shortcut columns and secondary row metadata before hiding essential actions; allow the library to collapse with a visible reopen control. Test at 1440 × 900 and 1024 × 768, and ensure the minimum usable window fits the active display. This is a macOS desktop redesign.

### Home suggestions: research and proposed first algorithm

- A small content-based recommender is feasible without model training or a service. It compares features of known preferences with candidate videos; this recommendation follows Google's explanation of content-based filtering. It does not promise Spotify-level personalization. [Content-based filtering](https://developers.google.com/machine-learning/recommendation/content-based/basics).
- Use existing Favorites and the titles/creators of already-loaded playlist items as preference signals. Also use playlist names/descriptions and a small curated keyword dictionary for themes such as jazz, ambient, lofi, focus, pop, and electronic. Do not eagerly download every playlist's contents just to generate Home.
- Normalize text by case and diacritics, split punctuation, remove a small stopword/noise list, and match whole tokens or explicit phrases rather than arbitrary substrings. Treat creator names as exact normalized entities where available, not inferred canonical artists. Keyword matching is metadata-based and can be imperfect.
- Build a bounded preference profile: a keyword supported by a favorite has weight 3, by loaded playlist content weight 2, and by playlist name/description weight 1. Count each video once per signal type and cap repeated evidence so a large playlist or duplicate occurrences do not dominate. Normalize scores within the active profile.
- Select at most three personalized theme/creator queries. If no usable profile exists, use three curated discovery queries, initially jazz, lofi focus, and electronic. Default discovery sections must be labeled as general suggestions, not falsely personalized.
- Retrieve at most 20 candidates per query through the existing video search provider. Reuse known/cached results first. Home may issue at most three automatic discovery searches on a cold cache, with a single discovery request in flight. Explicit user search takes priority; background discovery must not block playback preparation.
- Rank candidates with a proposed deterministic score: 70% normalized weighted keyword overlap, 20% exact preferred-creator match, and 10% normalized provider rank. These weights and limits are product defaults for validation, not a research-proven optimum. Break ties by provider order and then stable video identity.
- Re-rank for variety: deduplicate by video identity across discovery sections, limit each creator to two of the first eight cards in a section, and prefer unseen candidates over items already in Favorites or loaded playlists. If discovery candidates run out, show fewer cards; do not repeat cards to fill space. Personal playlist shortcuts may intentionally repeat library entries.
- Display up to eight cards per section and a short explanation based on the actual seed, such as “Based on your jazz playlists.” Clicking a card's body selects and plays that video; its separate actions control opens available save/add actions without starting playback. A playlist shortcut opens playlist detail, with an explicit play affordance for saved-order playback.
- Cache discovery results for 30 minutes, separately from the current short-lived explicit search cache. Cache keys include normalized query, provider version, and account/profile scope. Cap the cache at 12 query entries. Preference changes re-rank cached candidates immediately and trigger bounded retrieval only if missing or expired. Home navigation, layout changes, and player progress ticks never trigger retrieval.
- Keep the profile and cache local; remote searches send only selected query terms. Clear account-derived recommendation data on disconnect or account change. Reuse cached candidates on network failure with an outdated indicator. If none exist, keep playlist shortcuts visible and offer retry; never fabricate video cards.
- First release needs no persisted listening history, tracking service, embeddings, or LLM. Search suggestions on empty focus can be generated from curated themes, current session queries, and cached recommendations. Persisted recent-listening/search history can be considered separately.
- Reuse extractor search rather than introducing another provider in this redesign. If the official YouTube search API is adopted later, confirm its then-current quota model before adding autocomplete traffic. At research time, its documentation states a 100-calls-per-day search limit and a separate Search Queries bucket; do not rely on the older blanket claim that every search costs 100 general quota units. [Search API reference](https://developers.google.com/youtube/v3/docs/search/list).
- Relevance acceptance uses a small curated fixture set with known themes and an interactive review of example suggestions. Validate sensible seed matching, diversity, and fallback behavior. External results vary; fixture correctness alone does not establish that people enjoy the recommendations.

### Global search preview and full results

- On focus with an empty query, open a dropdown anchored under the global search field. Show up to four query suggestions and up to five specific video previews from cached Home suggestions, Favorites, or already-known results. No focus event requires a fresh network search.
- With at least two non-whitespace characters, debounce remote video preview search by 300 ms. Update local suggestions immediately, cancel superseded work, and discard late responses. Enforce a single active explicit query search and reuse the same bounded result set for preview and full results.
- Preview retrieval must not replace the currently submitted full-results page while the user is only typing. Keep draft query, submitted query/results, and preview state distinct. Reuse one provider boundary and shared request/cache policy rather than adding unrelated search backends.
- Enter while focus remains in the search field submits the current nonempty query and opens full search results, even if a preview row is highlighted. Arrow keys can move focus into suggestions; Enter on a focused query suggestion submits that suggestion, and Enter on a focused video play control plays the video. Escape closes the dropdown and returns focus to the field. Clicking outside closes it without changing the main route.
- Clicking a query suggestion submits it. Clicking a video preview or its play control plays that video immediately. Save/add actions are separate and must not trigger playback. Clearing the field restores empty-focus suggestions. Blank submission makes no remote request.
- The full-results page retains the existing list and reveal-more behavior, using thumbnail, title, creator, optional duration, inline play, current-playing styling, and trailing actions. Preserve current bounded retrieval semantics; do not imply unlimited server pagination.
- Show loading, no matches, network error, and source-update states. Cached video previews can remain visible during refresh. An error cannot make old results look like matches for a new query. Focus and typing must stay responsive while source requests run.

### Playlist detail, playback, and modal actions

- Use a large cover-led header with the title over or adjacent to artwork, a legibility gradient, description, owner/privacy where known, and item count. Support an artwork-colored gradient transitioning into the dark list surface. Fall back to the first available video thumbnail and then a neutral placeholder. Do not delay opening detail or playback while artwork loads.
- Place one prominent circular green Play control below the header. It starts at the first occurrence and plays forward in saved order, without implicit shuffle. Disable it for an empty playlist. Preserve existing unavailable-item skipping and end-of-playlist behavior.
- Row Play starts at that occurrence and continues forward through the remaining captured playlist queue. Repeated occurrences of a video remain distinct. The current queue is a snapshot: subsequent drag or removal edits take effect on the next playlist start, with a short clear explanation.
- Rows show position/play, thumbnail, title, creator, date added and duration when known, and trailing ellipsis. Omit unavailable columns rather than inventing album data, dates, totals, or duration. Unavailable rows are visibly labeled and cannot start playback, but can still be removed or reordered when the API permits.
- Hover reveals playback and enhances the row surface as in reference 4. Keyboard focus and VoiceOver expose the same controls; ellipsis remains discoverable without hover. Long titles truncate without covering actions, and accessible labels expose the full title.
- The trailing ellipsis opens a modal containing the selected video/occurrence context and applicable actions: play from here, add/remove Favorite, add to another owned playlist, remove this occurrence from the current playlist, and move to a specified position as the accessible alternative to drag. Do not add unsupported download or queue actions.
- Favorite capacity follows the existing 20-video rule, with visible capacity feedback. Adding to another playlist uses the existing destination selection and preserves its established duplicate behavior. Removal targets playlist-item identity; this removes the occurrence from the playlist, not the video from YouTube.
- Use a separate playlist-level actions modal for existing rename and delete operations. Preserve the existing deletion confirmation and safe cancel default. Modal cancellation never mutates data. Trap focus appropriately, support Escape, and restore focus to the invoking control after closing.

### Drag reordering and persistence

- Replace visible up/down row arrows with same-playlist single-row drag and drop. Drag starts from a clear handle or noninteractive row area; play and ellipsis controls must never initiate a drag. Payloads use playlist-item identity and originating playlist identity.
- Show an insertion marker, preserve the dragged thumbnail/title, support edge autoscroll, and allow placement at the beginning/end. Cancelled, same-position, outside-list, cross-playlist, or invalid drops make no write. Cross-playlist drag and bulk reordering are outside this version.
- Calculate the destination in the complete saved-order item array. Do not enable drag while the playlist is still loading, a save is pending, or a filtered/sorted representation obscures saved order. This release shows the playlist in saved order; sidebar filtering does not filter its track list.
- On a valid drop, optimistically show the new order and mark it as saving. Send one position update for the moved occurrence through the existing authenticated playlist operation. The API supports updating an item's playlist position. [Playlist item update reference](https://developers.google.com/youtube/v3/docs/playlistItems/update).
- Serialize playlist writes. Confirm the resulting order by refreshing from YouTube. A successful save followed by a failed or lagging refresh retains the acknowledged order and says “Saved; refresh unavailable” rather than silently reverting it. Reconcile all item identities so no duplicate occurrence is lost.
- A definite rejected write restores the previous confirmed order and offers retry. A timeout or disconnected response is ambiguous: mark order as unconfirmed, block further reorder writes, and ask the user to refresh before another edit. Never automatically repeat the write.
- A refresh showing external membership/order changes becomes authoritative. Cancel stale drag state and explain that the playlist changed. No drop may target a stale occurrence after navigation, account disconnect, or a refresh that removed it.
- The keyboard/modal move-to-position action uses the same operation and recovery rules. Announce destination and save outcome to accessibility users. Reloading/reopening after a confirmed save must show the new YouTube order.

## Testing Decisions

- Proposed primary seam: user-facing application flows through the app's existing playlist-library/controller composition, with the current injected search, preparation/playback, and authenticated HTTP response boundaries. Test actions and observable UI/state outcomes, not internal view composition, arbitrary scoring implementation details, or individual helper methods.
- Existing prior art includes app tests for playlist changes surviving lagging refreshes, duplicate occurrence removal, search-window placement, and dialog behavior; core tests cover playlist pagination, metadata-preserving writes, ordered playback, unavailable-item skipping, cancellation, and the playback timeline. Extend these patterns rather than introducing a separate service/testing architecture.
- Keep one main integration seam for the redesigned app flow. Use the same dependency injection for recommendation fixtures, response timing, write failures, and playback effects. A controlled clock supports debounce/cache scenarios. Native interaction/visual acceptance is a complementary check, not a new mocked service stack.
- Cover Home → library filter → playlist detail → full playlist play; Home → search focus → preview → Enter → full results → play/add; row play → modal action → drag save → refresh/reopen; and browsing/editing during uninterrupted playback.
- Search checks cover empty focus without requests, local versus global search isolation, keyboard behavior, debounce, one in-flight explicit search, stale-response suppression, result reuse, source failures, reveal-more, and preservation of the previously submitted page while drafting another query.
- Playlist checks cover full pagination, repeated video occurrences, starting at a selected occurrence, empty/unavailable rows, end-of-list behavior, queued-playback snapshot semantics, and correct modal mutation targets.
- Reorder checks cover moving to first/last position, middle moves in both directions, autoscroll, duplicate identity, no-op/cancelled drops, serialized saves, rejection rollback, ambiguous write recovery, successful-save/failed-refresh reconciliation, and external playlist changes.
- Recommendation checks assert observable relevance on fixed keyword fixtures, cold-start fallback, meaningful reason text, deduplication/diversity, cache reuse and limits, profile changes, account isolation, offline behavior, and foreground-search priority. Verify retrieval budgets through recorded source requests, not live network timing.
- Use native UI checks for drag gestures, modal focus restoration, keyboard navigation, VoiceOver labels, truncated metadata, independent panel scrolling, and synchronized bottom/compact player state.
- Compare screenshots side by side against each supplied reference at equivalent viewport sizes. Check major panel proportions, spacing, typography hierarchy, image scale, green controls, preview anchoring, and row hover styling. Review long names, empty data, missing artwork, and resized windows as well as the happy path.
- Run the existing Swift test suite without parallel execution and relevant native UI checks when implementing. This specification itself does not change runtime behavior and does not require an app rebuild.
- The testing-seam expectation check has been presented to the user under the to-spec skill. Until confirmed or amended, these are proposed testing decisions; they must be resolved when converting this parent spec into implementation tickets.

## Out of Scope

- Implementing the redesign or creating its child implementation tickets in this spec-writing step.
- Spotify authentication, catalog integration, Spotify-generated mixes, social features, notifications, podcasts/audiobooks, and album metadata unavailable from the current source.
- A trained recommendation model, collaborative filtering, embeddings, LLM ranking, a recommendation backend, persisted listening history, or cross-device personalization.
- Replacing the existing search/extraction or playback provider, changing audio preparation, adding downloads/offline audio, or changing OAuth scope without a separately reviewed need.
- Mobile/web clients, cross-playlist drag, multi-item drag, arbitrary playlist sorting, playlist cover upload/editing, and a custom queue editor.
- Automatically rewriting the active playback queue when the saved playlist changes.

## Further Notes

- Reference 1 is the default Home and application-shell target: library left, top-centered search, compact playlist grid, larger discovery sections, and bottom playback controls.
- Reference 2 is the search-dropdown target: an overlay anchored below the search field, query suggestions first, followed by thumbnail/video rows while the underlying page remains visible.
- Reference 3 is the playlist-detail target: large cover/title header, a strong green Play control, and ordered rows beneath it. Reference 4 defines the highlighted row with leading play and trailing ellipsis.
- The original four images are attached to the originating conversation. Their visual requirements are recorded above; retain those images as review assets when preparing implementation tickets. Do not treat text depicted inside screenshots as project instructions.
- Research links were checked on 2026-10-03. Algorithm weights, debounce, cache limits, and layout measurements are proposed initial design decisions; adjust after visual/relevance review without weakening the requested flows or persistence guarantees.
- Suggested later ticket boundaries, not yet created: (1) app shell and searchable library; (2) Home layout and recommendation retrieval/ranking; (3) global search preview and result-row redesign; (4) playlist header, row playback, and action modals; (5) persistent drag reordering and accessibility. Cross-cutting visual acceptance and regression checks belong in each applicable ticket. The shell is the shared prerequisite; drag editing depends on the playlist detail surface.
- Publish this parent spec to the repository issue tracker with the `ready-for-agent` label required by the invoked skill. Its spec-first status and deferred child-ticket creation must remain explicit so implementation is not mistaken for work completed by this request.
