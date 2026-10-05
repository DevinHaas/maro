# Sidebar connection footer research

Read-only source inspection at `32ccc9a` (2026-10-04). No application/configuration, Keychain, sign-in, network, or repository mutations. Only this report was written.

## Findings and ownership

- `Sources/MaroApp/AppShellView.swift:54` owns the current `LibrarySidebar`. Its footer container is unconditional at `:91`; only onboarding copy/button is gated by `!library.connected` (`:92`). Busy, stale-data, shared status, cancel, and retry are rendered at `:99–103`. `:104` adds padding even in a future text-only suppression. Remove the connected footer container itself to recover its space.
- `Sources/MaroApp/PlaylistLibrary.swift:12–19` owns connection/configuration flags and one shared `status` string. Successful `reload()` selects “Up to date with YouTube.” at `:351`, then announces it at `:386`. Do not delete this string globally as a shortcut for a sidebar presentation request; other surfaces consume status.
- `Sources/MaroCore/YouTubeAccount.swift:19–20`: configured = credentials exist; connected = a refresh token exists. Neither proves that the grant still works. `PlaylistLibrary` copies these flags at initialization (`:53–58`), sets connected after sign-in (`:89`), and clears it on credential import or explicit disconnect (`:74`, `:101`). Failed requests do not clear it: `run` only sets stale/status/canRetry (`:459–466`).
- `YouTubeAccount.swift:97–113`: access-token renewal is automatic when the cached token has <=60 seconds remaining; concurrent callers share a refresh task. There is no public force-refresh or reload-connection API. A failed refresh retains credentials and the refresh token. `exchange()` collapses all non-200/malformed token responses to an untyped authorization message (`:125–138`), so it currently cannot distinguish revoked consent (`invalid_grant`) from token-server failures.
- `Sources/MaroCore/YouTubePlaylists.swift:193` requests a token on every API request. HTTP 401 becomes an “expired connection” string (`:229`) without automatic token invalidation/retry or a connection-state transition. 403 includes permission/API-setup failures (`:230`); quota is separately messaged (`:224`). Reorder errors use `YouTubeWriteError` (`:214–219`) and may lose authentication cause; preflight token errors are wrapped as rejected writes (`:164–165`). Do not infer disconnected state from arbitrary failure text, 403, quota, offline errors, or `stale`.

## What “reload connection” means today

- **Refresh library:** `PlaylistLibrary.refresh()` (`:107–109`) does nothing when disconnected; otherwise reloads owned playlists and selected items (`:327–390`). It may trigger automatic token renewal, but cannot repair a missing/revoked grant.
- **Reconnect YouTube:** existing account-menu action (`AppShellView.swift:45`) calls `PlaylistLibrary.connect()` (`:82–92`), which starts browser OAuth consent (`YouTubeAccount.swift:52–83`), saves a new refresh token, clears library/selection, and reloads playlists. This is the existing actionable interpretation for the user's “reload connection.” Recommended button wording is **Reconnect YouTube**, with “Sign in again to reload your connection.” If literal “Reload connection” wording is chosen, explain that it opens Google sign-in.
- **Import credentials:** required only when not configured (`AppShellView.swift:95–97`); import resets local connection (`PlaylistLibrary.swift:74–78`). Do not route normal reconnection through import or `disconnect()`; disconnect clears local tokens and library (`:97–104`).
- Existing retry has a naming trap: `run` initially saves the whole action (`:461`). A sign-in that succeeds but whose first reload fails keeps the entire connect action as retry; the sidebar's “Retry refresh” can launch browser consent again. Assign a reload-only retry after successful authentication before the initial read.

## Proposed scoped ticket

**Title:** Show sidebar footer only when YouTube needs connecting; retain actionable operation feedback outside it.

Use an explicit connection presentation state, separate from operation feedback. A narrow state/helper is sufficient; no account-system rewrite or background health polling is needed. Treat the existing stored-token `connected` boolean as insufficient to detect revoked authorization.

| Effective state | Sidebar footer | Action / behavior |
| --- | --- | --- |
| Configured, token present, no confirmed auth failure | Absent, including during ordinary refresh and ordinary failures | Refresh progress belongs beside the library refresh control; failures go to operation notice |
| No credentials | Setup prompt | Import Google credentials; no enabled reconnect action |
| Configured, no token / explicitly disconnected | Connection prompt | Connect/Reconnect YouTube calls `connect()` |
| Definitive auth rejection / reauthorization required | “YouTube disconnected” recovery prompt | Reconnect YouTube calls `connect()`; preserve cached data with a stale indication and disable authenticated writes until repaired |
| Sign-in started from a disconnected state | Same connection footer, pending state | “Finish sign-in in your browser”; disable duplicate starts; retain Cancel sign-in; failure/cancellation returns to actionable prompt |
| Keychain/connection-load failure | Connection-unavailable recovery prompt, actual diagnostic | Do not mislabel as missing credentials or silently replace credentials; provide an explicit reread/retry path if included in this ticket |

For a reconnect manually started while connected, keep the footer absent and expose progress/cancellation in the account/operation notice surface. Successful authentication hides the disconnected footer even if the subsequent playlist read fails; that read failure is an operation notice. Explicit disconnect returns the prompt. Network/5xx/quota/ordinary permission failures leave the connection classification intact.

Minimum accurate authentication extension: preserve a typed `requiresReauthorization` cause for definitive token-exchange rejection and API 401 through read/write wrappers into `PlaylistLibrary`. Parse OAuth failure codes instead of classifying every non-200 token response as disconnected. Keep write outcome (`rejected`/`ambiguous`) orthogonal to authentication recovery. Do not erase persisted credentials merely to display disconnected UI. If this auth classification is deferred, explicitly scope the first ticket to *locally disconnected only*; revoked-token recovery will otherwise remain missing from the requested behavior.

## Operation-error preservation is required

Gating the entire existing footer without relocating feedback would hide failures on Home and other routes. `HomeView.swift:32` renders recommendation errors, not `library.status`; Search/Favorites render `app.actionError`, not library-operation errors (`SearchResultsView.swift:17`, `:55`). Creation/deletion can originate from the account menu or dismissed dialogs. Add-to-playlist clears `pendingVideo` on successful write before the subsequent refresh (`PlaylistLibrary.swift:124–126`), so its sheet cannot reliably carry the later failure.

Existing detail and modal surfaces are partial coverage: `PlaylistDetailView.swift:86–87` displays generic status/stale data; its pinned recovery bar is restricted to reorder state or “Saved” prefix (`:91–100`); `PlaylistActionsSheet.swift:28`, `:68–69` shows status and some retries; `AppShellView.swift:119` shows status inside AddToPlaylistSheet. The older `PlaylistLibraryView` (`PlaylistLibrary.swift:525`) has its own status but no current construction found; it is not evidence of a fallback for AppShell.

Recommended destination: a conditional notice in AppShell's main content, visible on every route even when the sidebar is collapsed. Store explicit operation severity and recovery action separately from neutral/success status; render actionable errors and stale/uncertain-save warnings there. Retain relevant modal/detail errors while those surfaces are open, avoid duplicate competing retry buttons, and preserve `announce()` accessibility output (`PlaylistLibrary.swift:452–456`). Cover synchronous guards/favorite-capacity failures (`:172`, `:194–197`, `:212–214`) as well as async `run` failures. Do not key visibility solely on `canRetry`, `stale`, English prefixes, or `reorderState`.

Keep recovery semantics: failed/uncertain writes refresh/read before another user edit (`PlaylistLibrary.swift:393–409`); only an explicit **Retry move** repeats a definitely rejected reorder (`:319–324`). Confirmed writes whose refresh fails remain explicitly marked saved. This is an existing documented contract (`docs/YOUTUBE_PLAYLISTS.md:71–83`). Neutral/success “Up to date” remains absent from the sidebar and does not create a replacement permanent notice.

## Acceptance criteria and test seams

1. Connected successful library, empty library, and ordinary refreshing library render no footer text, controls, or reserved footer padding. A refresh spinner can appear in the header. Library rows use the recovered space.
2. Unconfigured and configured/disconnected fixtures show the correct enabled action; pending sign-in has cancellation; failure/cancellation remains recoverable; success removes the footer. Disconnected recovery dispatches `connect()`, never the guarded no-op `refresh()`.
3. Definitive auth failures show reconnect guidance, including failures during write preflight and move responses. Offline, quota, 403 permissions, and 5xx do not misclassify the account. Cached data and confirmed write order survive recoverable failures.
4. With footer hidden and sidebar collapsed, failed refresh/create/delete/add and favorite-capacity errors remain readable with appropriate recovery. A sign-in success + initial-read failure offers read retry without starting OAuth again. Uncertain writes are never replayed automatically.
5. Existing reorder behavior remains: definite rejection offers explicit Retry move; uncertain outcome requires Refresh YouTube; successful write + failed refresh stays marked saved. VoiceOver receives actionable notices; keyboard access reaches recovery and Cancel sign-in.

Reuse injected `YouTubePlaylists(token:send:)` and `PlaylistLibrary(controller:api:)` fixtures (`Tests/MaroAppTests/PlaylistLibraryTests.swift:75`, `:98`), with synthetic token rejection, 401, 403, 5xx, and network errors. Existing injected API initializer bypasses Keychain and marks connected/configured (`PlaylistLibrary.swift:48–50`). Add pure presentation-state tests rather than snapshots of English strings. Extend reorder regression cases (`Tests/MaroAppTests/PlaylistReorderTests.swift:108`, `:130`; `Tests/MaroCoreTests/PlaylistReorderAPITests.swift:47`, `:56`) to verify error recovery classification survives wrapping. Testing token exchange itself needs a small injected transport/clock or pure response classifier because it currently hardcodes `URLSession.shared` and `Date`; do not use real Keychain/OAuth. Check native layout and accessibility at both sidebar widths after implementation. No tests executed for this research-only report.

## Decisions for the later spec

- Approve **Reconnect YouTube** wording or literal **Reload connection** with browser-sign-in explanation.
- Confirm whether first-use credential setup belongs in the same exceptional footer (recommended: yes).
- Choose main-content notice placement/lifetime: recommended persistent actionable error until resolved or deliberately dismissed; unresolved reorder lock still needs visible recovery after dismissal.
- Include definitive-auth classification in this ticket (recommended to meet real disconnected behavior), or explicitly split visual cleanup from auth-health detection; never claim `!connected` detects revoked tokens.
- Decide whether Keychain reread retry is included or a separately scoped recovery improvement. Current import fallback is not an equivalent retry.
