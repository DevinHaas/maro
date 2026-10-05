import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MaroCore

@MainActor
enum PlaylistSaveResult: Equatable {
    case added
    case alreadyInPlaylist
    case unavailable(String)
    case busy
    case failed(String)
    case uncertain(String)
    case savedRefreshUnavailable(String)
}

struct PlaylistSaveOutcome: Equatable {
    let playlistID: String
    let result: PlaylistSaveResult
}

@MainActor
final class PlaylistLibrary: ObservableObject {
    @Published var playlists: [YouTubePlaylist] = []
    @Published var items: [YouTubePlaylistItem] = []
    @Published var selected: YouTubePlaylist?
    @Published var busy = false
    @Published private var loadingTracksPlaylistID: String?
    private var loadingTracksRevision = UUID()
    var loadingTracks: Bool { busy && loadingTracksPlaylistID != nil && loadingTracksPlaylistID == selected?.id }
    @Published var connected = false
    @Published var configured = false
    @Published var status = "Connect YouTube to browse your own playlists."
    @Published var stale = false
    @Published var pendingVideo: VideoSummary?
    @Published var destination = ""
    @Published var signingIn = false
    @Published var canRetry = false
    @Published var actionContext: PlaylistActionContext?
    @Published private(set) var loadedItemsByPlaylist: [String: [YouTubePlaylistItem]] = [:]
    @Published private(set) var recommendationScope = UUID().uuidString
    private var loadedPlaylistOrder: [String] = []
    private var account: YouTubeAccount?
    private var api: YouTubePlaylists?
    private var retry: (() async throws -> Void)?
    private var operation: Task<Void, Never>?
    private let controller: MaroController
    private let now: () -> Date
    private var accountRevision = 0
    @Published private(set) var reorderState: PlaylistReorderState = .idle
    @Published private(set) var orderRevision = UUID()
    @Published private(set) var dragPayload: PlaylistDragPayload?
    @Published private(set) var dragInsertion: Int?
    private struct AcknowledgedOrder {
        var items: [YouTubePlaylistItem]
        var laggingSignatures: [[String]]
        let protectsLagUntil: Date
    }
    private var acknowledgedOrders: [String: AcknowledgedOrder] = [:]
    private var unconfirmedPlaylists: Set<String> = []
    // A confirmed POST is stronger evidence than an immediately lagging playlist read.
    @Published private var confirmedSavedVideos: [String: Set<String>] = [:]
    private var confirmedSaveProtection: [String: [String: Date]] = [:]
    private var rejectedMove: (occurrenceID: String, playlistID: String, position: Int, signature: [String])?
    var canReorder: Bool { connected && !busy && selected != nil && unconfirmedPlaylists.isEmpty }
    func canSaveVideo(to playlistID: String) -> Bool {
        connected && !busy && unconfirmedPlaylists.isEmpty && playlists.contains(where: { $0.id == playlistID })
    }
    @Published private(set) var saveScopeID = UUID()
    var saveAccountScope: String { saveScopeID.uuidString }

    func containsSavedVideo(_ videoID: String, in playlistID: String) -> Bool {
        confirmedSavedVideos[playlistID, default: []].contains(videoID)
            || loadedItemsByPlaylist[playlistID, default: []].contains { $0.resourceVideoID == videoID }
            || (selected?.id == playlistID && items.contains { $0.resourceVideoID == videoID })
    }

    init(controller: MaroController, api: YouTubePlaylists? = nil, now: @escaping () -> Date = Date.init) {
        self.controller = controller
        self.now = now
        if let api {
            self.api = api; connected = true; configured = true
            return
        }
        do {
            let account = try YouTubeAccount(keychainService:
                ProcessInfo.processInfo.environment["MARO_KEYCHAIN_SERVICE"] ?? "Maro.YouTube")
            self.account = account
            self.api = YouTubePlaylists(token: { try await account.accessToken() })
            connected = account.isConnected; configured = account.isConfigured
        } catch { status = error.localizedDescription }
    }

    func importCredentials() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose the downloaded JSON for your Google Desktop app OAuth client."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let account = try account ?? YouTubeAccount()
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 65_536 else { throw YouTubeAccountError("This credentials file is too large.") }
            try account.configure(json: Data(contentsOf: url))
            self.account = account
            api = YouTubePlaylists(token: { try await account.accessToken() })
            configured = true; connected = false
            self.accountRevision += 1
            self.saveScopeID = UUID()
            playlists = []; items = []; selected = nil; clearLoadedEvidence()
            retry = nil; canRetry = false; stale = false
            status = "Credentials imported. Connect YouTube to continue."
        } catch { status = error.localizedDescription }
    }

    func connect() {
        guard !busy else { return }
        guard let account else { return }
        run {
            self.signingIn = true
            defer { self.signingIn = false }
            self.status = "Finish Google sign-in in your browser."
            try await account.connect { NSWorkspace.shared.open($0) }
            self.accountRevision += 1
            self.saveScopeID = UUID()
            self.connected = true
            self.playlists = []; self.items = []; self.selected = nil; self.clearLoadedEvidence()
            try await self.reload()
        }
    }

    func cancelSignIn() { operation?.cancel(); account?.cancelSignIn() }

    func disconnect() {
        guard !busy else { return }
        do {
            try account?.disconnect()
            accountRevision += 1
            saveScopeID = UUID()
            connected = false; playlists = []; items = []; selected = nil; clearLoadedEvidence()
            pendingVideo = nil; retry = nil; canRetry = false; stale = false
            status = "Disconnected on this Mac. Your YouTube playlists are unchanged."
        } catch { status = error.localizedDescription }
    }

    func refresh() {
        guard connected else { return }
        run { self.announce("Refreshing playlists from YouTube."); try await self.reload() }
    }

    func open(_ playlist: YouTubePlaylist) {
        invalidateDrag()
        selected = playlist; items = []
        reorderState = unconfirmedPlaylists.contains(playlist.id) ? .unconfirmed : .idle
        refresh()
    }

    func back() { invalidateDrag(); selected = nil; items = []; refresh() }

    func addPending() {
        guard let video = pendingVideo, !destination.isEmpty, let api else { return }
        let destination = destination
        mutate {
            try await api.add(video, to: destination)
            if self.pendingVideo == video { self.pendingVideo = nil }
        }
    }

    func create() {
        guard let name = askName(title: "Create private playlist", value: "") else { return }
        create(title: name)
    }

    func create(title: String) {
        guard let api else { return }
        var created: YouTubePlaylist?
        mutate({ created = try await api.create(title: title) }, reconcile: {
            guard let created else { return }
            self.playlists.removeAll { $0.id == created.id }
            self.playlists.insert(created, at: 0)
            self.destination = created.id
            self.status = "Playlist created."
        })
    }

    func confirmDelete() {
        guard canReorder, let selected else { return }
        let scope = saveAccountScope
        let alert = PlaylistDialogs.deletion(title: selected.title)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        guard scope == saveAccountScope, canReorder, self.selected?.id == selected.id else { return }
        delete(selected)
    }

    func delete(_ playlist: YouTubePlaylist) {
        guard let api else { return }
        mutate({ try await api.delete(playlist.id) }, reconcile: {
            self.playlists.removeAll { $0.id == playlist.id }
            if self.selected?.id == playlist.id { self.selected = nil; self.items = [] }
            if self.destination == playlist.id { self.destination = self.playlists.first?.id ?? "" }
            self.status = "Playlist deleted from YouTube."
        })
    }

    func rename() {
        guard canReorder, let selected else { return }
        let scope = saveAccountScope
        guard let name = askName(title: "Rename playlist", value: selected.title),
              scope == saveAccountScope, canReorder, self.selected?.id == selected.id else { return }
        rename(playlistID: selected.id, title: name)
    }

    func rename(playlistID: String, title: String) {
        guard let playlist = playlists.first(where: { $0.id == playlistID }), let api else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 150 else { status = "Enter a playlist name of 1–150 characters."; return }
        let renamed = YouTubePlaylist(id: playlist.id, title: title, count: playlist.count,
            thumbnailURL: playlist.thumbnailURL, description: playlist.description, owner: playlist.owner, privacy: playlist.privacy)
        mutate({ try await api.rename(playlistID, title: title) }, reconcile: {
            if let index = self.playlists.firstIndex(where: { $0.id == playlistID }) { self.playlists[index] = renamed }
            if self.selected?.id == playlistID { self.selected = renamed }
        })
    }

    func presentItemActions(occurrenceID: String, playlistID: String) {
        guard let item = item(occurrenceID: occurrenceID, in: playlistID), let selected else { return }
        actionContext = PlaylistActionContext(playlist: selected, item: item)
    }

    func presentPlaylistActions() {
        guard let selected else { return }
        actionContext = PlaylistActionContext(playlist: selected)
    }

    func dismissActions() { actionContext = nil }

    func item(occurrenceID: String, in playlistID: String) -> YouTubePlaylistItem? {
        guard selected?.id == playlistID else { status = "This playlist is no longer open. Open it again to edit this occurrence."; return nil }
        guard let item = items.first(where: { $0.id == occurrenceID }) else {
            status = "This occurrence is no longer in the playlist. Refresh to see its current contents."; return nil
        }
        return item
    }

    func remove(occurrenceID: String, from playlistID: String) {
        guard let item = item(occurrenceID: occurrenceID, in: playlistID) else { return }
        remove(item)
    }

    func add(_ video: VideoSummary, to playlistID: String) {
        guard playlists.contains(where: { $0.id == playlistID }), let api else { return }
        mutate { try await api.add(video, to: playlistID) }
    }

    /// Saves one explicit video occurrence to one currently listed account playlist.
    /// The captured account revision prevents stale popovers from writing after a switch.
    func saveVideo(_ video: VideoSummary, to playlistID: String, accountScope: String) async -> PlaylistSaveResult {
        guard !busy else { return .busy }
        busy = true
        defer { busy = false }
        return await saveVideoWhileReserved(video, to: playlistID, accountScope: accountScope)
    }

    /// Reserve the shared library for the complete batch; never race another edit between destinations.
    /// Confirmed failures can be retried independently; ambiguous writes block all subsequent edits.
    func saveVideo(_ video: VideoSummary, toPlaylists playlistIDs: [String], accountScope: String) async -> [PlaylistSaveOutcome] {
        var unique = Set<String>()
        let destinations = playlistIDs.filter { unique.insert($0).inserted }
        guard !busy else { return destinations.map { PlaylistSaveOutcome(playlistID: $0, result: .busy) } }
        busy = true
        defer { busy = false }
        var outcomes: [PlaylistSaveOutcome] = []
        for playlistID in destinations {
            let result = await saveVideoWhileReserved(video, to: playlistID, accountScope: accountScope)
            outcomes.append(PlaylistSaveOutcome(playlistID: playlistID, result: result))
        }
        return outcomes
    }

    private func saveVideoWhileReserved(_ video: VideoSummary, to playlistID: String, accountScope: String) async -> PlaylistSaveResult {
        guard accountScope == saveAccountScope else { return .unavailable("This YouTube account changed. Reopen the save menu.") }
        guard connected, let api else { return .unavailable("Connect YouTube to save to your playlists.") }
        guard playlists.contains(where: { $0.id == playlistID }) else {
            return .unavailable("This playlist is no longer available. Refresh the list and reopen the save menu.")
        }
        guard unconfirmedPlaylists.isEmpty else {
            return .unavailable("A previous playlist edit has an unconfirmed result. Refresh YouTube before another edit.")
        }
        do { try video.validate() }
        catch { return .unavailable(error.localizedDescription) }
        guard !containsSavedVideo(video.id, in: playlistID) else { return .alreadyInPlaylist }

        let revision = accountRevision
        canRetry = false
        do {
            try await api.add(video, to: playlistID)
        } catch {
            guard revision == accountRevision, connected else {
                return .unavailable("The YouTube account changed while saving. Reopen the save menu.")
            }
            if error.localizedDescription.localizedCaseInsensitiveContains("already in this playlist") {
                confirmedSavedVideos[playlistID, default: []].insert(video.id)
                confirmedSaveProtection[playlistID, default: [:]][video.id] = now().addingTimeInterval(60)
                return .alreadyInPlaylist
            }
            if let writeError = error as? YouTubeWriteError, writeError.outcome == .ambiguous {
                unconfirmedPlaylists.insert(playlistID)
                retry = { try await self.reload() }
                canRetry = true
                let message = "Save outcome is unconfirmed. Refresh YouTube before trying again; Maro will not repeat this save."
                announce(message)
                return .uncertain(message)
            }
            return .failed(error.localizedDescription)
        }
        guard revision == accountRevision, connected else {
            return .unavailable("The YouTube account changed while saving. Reopen the save menu.")
        }
        confirmedSavedVideos[playlistID, default: []].insert(video.id)
        confirmedSaveProtection[playlistID, default: [:]][video.id] = now().addingTimeInterval(60)

        // The POST was confirmed. Keep a useful local count even if the subsequent refresh fails.
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            let old = playlists[index]
            playlists[index] = YouTubePlaylist(id: old.id, title: old.title, count: old.count + 1,
                thumbnailURL: old.thumbnailURL, description: old.description, owner: old.owner, privacy: old.privacy)
        }
        retry = { try await self.reload() }
        do {
            try await reload()
            return .added
        } catch {
            guard revision == accountRevision, connected else {
                return .unavailable("The YouTube account changed after saving. Reopen the save menu.")
            }
            let message = "Saved on YouTube, but refresh failed. Retry refresh to see the updated playlist."
            canRetry = true
            announce(message)
            return .savedRefreshUnavailable(message)
        }
    }

    func toggleFavorite(_ video: VideoSummary) {
        do { try controller.toggleFavorite(video); status = "Favorites: \(controller.snapshot.favorites.count) of 20 saved." }
        catch StateError.favoritesFull { status = "Favorites are full (20 of 20). Remove one before adding another." }
        catch { status = error.localizedDescription }
    }

    /// Final zero-based position in the complete saved-order array, shared by keyboard and drag.
    func move(occurrenceID: String, in playlistID: String, to position: Int) {
        guard canReorder, let item = item(occurrenceID: occurrenceID, in: playlistID), let api,
              items.indices.contains(position), let old = items.firstIndex(where: { $0.id == occurrenceID }), old != position else { return }
        guard item.resourceVideoID != nil else { status = "This entry has no resource identity and cannot be reordered."; return }
        let previous = items
        var moved = items
        moved.insert(moved.remove(at: old), at: position)
        let revision = accountRevision
        let priorReceipt = acknowledgedOrders[playlistID]
        rejectedMove = nil
        invalidateDrag()
        items = moved; reorderState = .saving
        announce("Moving \(item.title) to position \(position + 1). Saving to YouTube.")
        run {
            do { try await api.move(item, in: playlistID, to: position) }
            catch {
                guard revision == self.accountRevision, self.connected else { return }
                if (error as? YouTubeWriteError)?.outcome == .rejected {
                    if self.selected?.id == playlistID { self.items = previous; self.reorderState = .rejected }
                    self.rejectedMove = (occurrenceID, playlistID, position, previous.map(\.id))
                    self.retry = { try await self.reload() }
                    self.announce("Move rejected. Previous saved order restored. \(error.localizedDescription) Retry move when ready.")
                } else {
                    self.unconfirmedPlaylists.insert(playlistID)
                    if self.selected?.id == playlistID { self.reorderState = .unconfirmed }
                    self.retry = { try await self.reload() }
                    self.announce("Move outcome unconfirmed. Refresh YouTube before another edit. The move will not be repeated automatically.")
                }
                throw YouTubeAccountError(self.status)
            }
            guard revision == self.accountRevision, self.connected else { return }
            self.acknowledgedOrders[playlistID] = AcknowledgedOrder(items: moved,
                laggingSignatures: Array(((priorReceipt?.laggingSignatures ?? []) + [previous.map(\.id)]).suffix(8)),
                protectsLagUntil: self.now().addingTimeInterval(60))
            self.rememberLoaded(moved, playlistID: playlistID)
            self.retry = { try await self.reload() }
            do { try await self.reload() }
            catch {
                guard revision == self.accountRevision, self.connected else { return }
                if self.selected?.id == playlistID { self.items = moved; self.reorderState = .savedRefreshUnavailable }
                self.announce("Saved; refresh unavailable. Your confirmed order is retained. Retry refresh when connected.")
                throw YouTubeAccountError(self.status)
            }
        }
    }

    func play(occurrenceID: String, in playlistID: String) {
        guard let item = item(occurrenceID: occurrenceID, in: playlistID), item.video != nil,
              let index = items.firstIndex(where: { $0.id == occurrenceID }) else { return }
        play(from: index)
    }

    func play(_ playlist: YouTubePlaylist) {
        guard let api, connected else { return }
        let revision = accountRevision
        Task {
            do {
                let queue = selected?.id == playlist.id && !busy ? items : try await api.items(in: playlist.id)
                guard revision == accountRevision, connected else { return }
                rememberLoaded(queue, playlistID: playlist.id)
                guard !queue.isEmpty else { status = "This playlist is empty."; return }
                try await controller.playPlaylist(queue, playlistID: playlist.id)
                status = controller.snapshot.error ?? "Playing in saved order. Edits apply the next time you play this playlist."
            } catch is CancellationError { }
            catch { status = error.localizedDescription }
        }
    }

    func remove(_ item: YouTubePlaylistItem) {
        guard let api, let playlistID = selected?.id else { return }
        mutate({ try await api.remove(item) }, reconcile: {
            if let videoID = item.resourceVideoID {
                self.confirmedSavedVideos[playlistID]?.remove(videoID)
                self.confirmedSaveProtection[playlistID]?.removeValue(forKey: videoID)
            }
            if var receipt = self.acknowledgedOrders[playlistID], receipt.items.contains(where: { $0.id == item.id }) {
                receipt.laggingSignatures.append(receipt.items.map(\.id))
                receipt.items.removeAll { $0.id == item.id }
                self.acknowledgedOrders[playlistID] = receipt
            }
            guard self.selected?.id == playlistID else { return }
            self.items.removeAll { $0.id == item.id }
            self.rememberLoaded(self.items, playlistID: playlistID)
        })
    }

    func move(_ item: YouTubePlaylistItem, offset: Int) {
        guard let selected, let index = items.firstIndex(where: { $0.id == item.id }),
              items.indices.contains(index + offset) else { return }
        move(occurrenceID: item.id, in: selected.id, to: index + offset)
    }

    func play(from index: Int = 0) {
        let items = items
        let playlistID = selected?.id
        guard items.indices.contains(index) else { return }
        Task {
            do {
                try await controller.playPlaylist(items, startingAt: index, playlistID: playlistID)
                status = controller.snapshot.error ?? "Playing in saved order. Edits apply the next time you play this playlist."
            } catch is CancellationError { }
            catch { status = "Could not play this selection. \(controller.snapshot.error ?? error.localizedDescription)" }
        }
    }

    func retryLast() {
        guard !busy else { return }
        if reorderState == .rejected, let move = rejectedMove {
            guard selected?.id == move.playlistID, items.map(\.id) == move.signature else { refresh(); return }
            self.move(occurrenceID: move.occurrenceID, in: move.playlistID, to: move.position)
        } else if let retry { run(retry) }
    }

    private func reload() async throws {
        guard let api else { return }
        let loadRevision = UUID()
        loadingTracksRevision = loadRevision
        loadingTracksPlaylistID = selected?.id
        defer { if loadingTracksRevision == loadRevision { loadingTracksPlaylistID = nil } }
        let revision = accountRevision
        let fresh = try await api.playlists()
        // Opening another playlist while a read is in flight must not restore the old page.
        while true {
            let requestedID = selected?.id
            let freshSelected = fresh.first { $0.id == requestedID }
            if loadingTracksRevision == loadRevision { loadingTracksPlaylistID = freshSelected?.id }
            var freshItems: [YouTubePlaylistItem] = []
            if let freshSelected { freshItems = try await api.items(in: freshSelected.id) }
            var recovered: [String: [YouTubePlaylistItem]] = [:]
            // Refresh also resolves an uncertain save after navigation back to Home.
            for playlistID in unconfirmedPlaylists where playlistID != requestedID && fresh.contains(where: { $0.id == playlistID }) {
                recovered[playlistID] = try await api.items(in: playlistID)
            }
            guard revision == accountRevision, connected else { return }
            guard requestedID == selected?.id else { continue }
            for (playlistID, authoritativeItems) in recovered {
                unconfirmedPlaylists.remove(playlistID); acknowledgedOrders.removeValue(forKey: playlistID)
                rememberLoaded(authoritativeItems, playlistID: playlistID)
            }
            unconfirmedPlaylists.formIntersection(Set(fresh.map(\.id)))
            acknowledgedOrders = acknowledgedOrders.filter { receipt in fresh.contains { $0.id == receipt.key } }
            let oldIDs = items.map(\.id)
            var message = "Up to date with YouTube."
            if !recovered.isEmpty || (requestedID == nil && unconfirmedPlaylists.isEmpty && reorderState == .unconfirmed) {
                reorderState = .idle
                message = "Refreshed YouTube's authoritative order. You can reorder again."
            }
            if let requestedID {
                if unconfirmedPlaylists.remove(requestedID) != nil {
                    acknowledgedOrders.removeValue(forKey: requestedID)
                    message = "Refreshed YouTube's authoritative order. You can reorder again."
                    reorderState = .idle
                } else if let receipt = acknowledgedOrders[requestedID] {
                    if freshItems.map(\.id) == receipt.items.map(\.id) {
                        acknowledgedOrders.removeValue(forKey: requestedID); reorderState = .idle
                        message = "Saved and confirmed with YouTube."
                    } else if now() < receipt.protectsLagUntil && receipt.laggingSignatures.contains(freshItems.map(\.id)) {
                        // YouTube supplies no read revision: old lag and an external restoration are
                        // indistinguishable. Protect immediate lag for one minute, then accept a
                        // successful read as authoritative. Failed reads still retain visible order.
                        // Match occurrences, never video IDs; preserve fresh metadata alongside acknowledged order.
                        let byID = Dictionary(freshItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                        freshItems = receipt.items.map { byID[$0.id] ?? $0 }
                        reorderState = .savedRefreshUnavailable
                        message = "Saved; refresh unavailable. YouTube's read is still catching up; confirmed order retained."
                    } else {
                        acknowledgedOrders.removeValue(forKey: requestedID); reorderState = .idle
                        message = "Playlist changed on YouTube. Its current membership and order are now shown."
                    }
                } else if !oldIDs.isEmpty && oldIDs != freshItems.map(\.id) {
                    message = "Playlist changed on YouTube. Its current membership and order are now shown."
                }
            }
            if oldIDs != freshItems.map(\.id) { invalidateDrag(); actionContext = nil }
            playlists = fresh; selected = freshSelected; items = freshItems
            if let requestedID { rememberLoaded(freshItems, playlistID: requestedID) }
            loadedItemsByPlaylist = loadedItemsByPlaylist.filter { entry in fresh.contains { $0.id == entry.key } }
            announce(fresh.isEmpty ? "No playlists yet. Create your first private playlist." : message)
            break
        }
        if !fresh.contains(where: { $0.id == destination }) { destination = fresh.first?.id ?? "" }
        stale = false
    }

    private func mutate(_ write: @escaping () async throws -> Void, reconcile: @escaping () -> Void = {}) {
        guard unconfirmedPlaylists.isEmpty else {
            announce("Move outcome unconfirmed. Refresh YouTube before another edit."); return
        }
        run {
            do { try await write() }
            catch {
                // A timed-out write may already have reached YouTube. Never replay it automatically.
                self.retry = { try await self.reload() }
                throw YouTubeAccountError("\(error.localizedDescription) Refresh to check YouTube before trying the edit again.")
            }
            // Keep confirmed writes visible even when the immediate list response lags behind.
            reconcile()
            defer { reconcile() }
            self.retry = { try await self.reload() }
            do { try await self.reload() }
            catch { throw YouTubeAccountError("Saved on YouTube, but refresh failed. Retry refresh to see the updated playlist.") }
        }
    }

    private func rememberLoaded(_ items: [YouTubePlaylistItem], playlistID: String) {
        // Accept refreshed membership after the immediate eventual-consistency window.
        let authoritativeIDs = Set(items.compactMap(\.resourceVideoID))
        confirmedSavedVideos[playlistID] = confirmedSavedVideos[playlistID, default: []].filter {
            authoritativeIDs.contains($0) || (confirmedSaveProtection[playlistID]?[$0] ?? .distantPast) > now()
        }
        confirmedSaveProtection[playlistID] = confirmedSaveProtection[playlistID, default: [:]].filter { $0.value > now() }
        loadedPlaylistOrder.removeAll { $0 == playlistID }; loadedPlaylistOrder.append(playlistID)
        loadedItemsByPlaylist[playlistID] = Array(items.prefix(50))
        while loadedPlaylistOrder.count > 12 { loadedItemsByPlaylist.removeValue(forKey: loadedPlaylistOrder.removeFirst()) }
    }

    private func clearLoadedEvidence() {
        loadingTracksRevision = UUID(); loadingTracksPlaylistID = nil
        recommendationScope = UUID().uuidString
        loadedItemsByPlaylist = [:]; loadedPlaylistOrder = []; confirmedSavedVideos = [:]; actionContext = nil
        confirmedSaveProtection = [:]
        invalidateDrag(); acknowledgedOrders = [:]; unconfirmedPlaylists = []; rejectedMove = nil; reorderState = .idle
    }

    private func invalidateDrag() { dragPayload = nil; dragInsertion = nil; orderRevision = UUID() }

    func beginDrag(occurrenceID: String, in playlistID: String) -> PlaylistDragPayload? {
        guard canReorder, selected?.id == playlistID, let item = items.first(where: { $0.id == occurrenceID }), item.resourceVideoID != nil else { return nil }
        let payload = PlaylistDragPayload(playlistID: playlistID, occurrenceID: occurrenceID, revision: orderRevision, accountScope: recommendationScope)
        dragPayload = payload; return payload
    }

    func acceptsDrag(_ payload: PlaylistDragPayload, in playlistID: String) -> Bool {
        canReorder && dragPayload == payload && payload.playlistID == playlistID && selected?.id == playlistID
            && payload.revision == orderRevision && payload.accountScope == recommendationScope
            && items.contains { $0.id == payload.occurrenceID }
    }

    func updateDragInsertion(_ insertion: Int?) { dragInsertion = insertion }
    func cancelDrag() { dragPayload = nil; dragInsertion = nil }

    @discardableResult func drop(_ payload: PlaylistDragPayload, in playlistID: String, insertionIndex: Int) -> Bool {
        guard acceptsDrag(payload, in: playlistID), (0...items.count).contains(insertionIndex),
              let old = items.firstIndex(where: { $0.id == payload.occurrenceID }) else { cancelDrag(); return false }
        let destination = insertionIndex > old ? insertionIndex - 1 : insertionIndex
        cancelDrag()
        guard destination != old else { return false }
        move(occurrenceID: payload.occurrenceID, in: playlistID, to: destination)
        return true
    }

    private func announce(_ message: String) {
        status = message
        guard let window = NSApp?.keyWindow else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func run(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true; canRetry = false; retry = action
        operation = Task {
            defer { busy = false; operation = nil }
            do { try await action(); canRetry = false; retry = nil }
            catch is CancellationError { status = "Sign-in cancelled."; retry = nil }
            catch { stale = !playlists.isEmpty; announce(error.localizedDescription); canRetry = true }
        }
    }

    private func askName(title: String, value: String) -> String? {
        let (alert, field) = PlaylistDialogs.name(title: title, value: value)
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

/// Native dialogs retain keyboard/modal semantics and explicit cancellation.
@MainActor enum PlaylistDialogs {
    private static func styledAlert() -> NSAlert {
        let alert = NSAlert()
        alert.window.appearance = NSAppearance(named: .darkAqua)
        alert.window.backgroundColor = NSColor(AppDesign.Surface.raised)
        return alert
    }

    static func name(title: String, value: String) -> (NSAlert, NSTextField) {
        let alert = styledAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        MaroAppearance.primary(alert.buttons[0])
        alert.buttons[0].bezelColor = NSColor(AppDesign.Accent.primary)
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        field.font = .systemFont(ofSize: 13)
        field.textColor = NSColor(AppDesign.Text.primary)
        field.backgroundColor = NSColor(AppDesign.Surface.raised)
        field.setAccessibilityLabel("Playlist name")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        applySurface(alert)
        return (alert, field)
    }

    static func deletion(title: String) -> NSAlert {
        let alert = styledAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you really want to remove the playlist?"
        alert.informativeText = "“\(title)” will be permanently deleted from YouTube. The videos themselves are not deleted."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Remove playlist")
        // Return must never approve destruction by default.
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        alert.window.initialFirstResponder = alert.buttons[0]
        applySurface(alert)
        return alert
    }

    private static func applySurface(_ alert: NSAlert) {
        alert.layout()
        alert.window.contentView?.wantsLayer = true
        alert.window.contentView?.layer?.backgroundColor = NSColor(AppDesign.Surface.raised).cgColor
    }
}

struct PlaylistLibraryView: View {
    @ObservedObject var library: PlaylistLibrary
    @State private var selectedItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(library.selected?.title ?? "Your YouTube playlists", systemImage: "music.note.list")
                    .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Spacer()
                if library.busy { ProgressView().controlSize(.small) }
                if library.connected {
                    Button("Refresh") { library.refresh() }.disabled(library.busy)
                    Menu("Account") {
                        Button("Reconnect YouTube") { library.connect() }
                        Button("Disconnect on this Mac") { library.disconnect() }
                    }.disabled(library.busy).fixedSize()
                }
            }
            if !library.connected {
                Text("Connect your Google account to create and edit your own YouTube playlists. New playlists are private.")
                Text("Google's permission covers more than playlists. Maro uses it only for playlist access and editing.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Import Google credentials…") { library.importCredentials() }.disabled(library.busy)
                    Button("Connect YouTube") { library.connect() }
                        .buttonStyle(.borderedProminent).disabled(!library.configured || library.busy)
                }
                Link("Google Desktop app setup instructions", destination: URL(string: "https://developers.google.com/youtube/v3/guides/auth/installed-apps")!)
                Spacer()
            } else {
                if let pending = library.pendingVideo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add: \(pending.title)").lineLimit(1)
                        HStack {
                            Picker("Playlist", selection: $library.destination) {
                                ForEach(library.playlists) { Text($0.title).tag($0.id) }
                            }
                            Button("Add") { library.addPending() }.disabled(library.destination.isEmpty)
                            Button("Cancel") { library.pendingVideo = nil }
                        }
                    }.padding(12).background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: MaroAppearance.border).opacity(0.3)))
                        .cornerRadius(8).disabled(library.busy)
                }
                if library.selected == nil {
                    List(library.playlists) { playlist in
                        Button { library.open(playlist); selectedItem = nil } label: {
                            HStack {
                                Image(systemName: "music.note.list")
                                Text(playlist.title).lineLimit(1)
                                Spacer()
                                Text("\(playlist.count) videos").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                            }.padding(.vertical, 5).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(library.busy)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if library.playlists.isEmpty && !library.busy {
                            Text("No playlists yet. Create one to get started.")
                                .foregroundStyle(.secondary).allowsHitTesting(false)
                        }
                    }
                    Button("Create playlist…") { library.create() }
                        .buttonStyle(.borderedProminent).disabled(library.busy)
                } else {
                    HStack {
                        Button("All playlists") { library.back(); selectedItem = nil }
                        Button("Rename…") { library.rename() }
                        Button("Delete playlist…", role: .destructive) { library.confirmDelete() }
                        Spacer()
                        Button("Play all") { library.play() }.disabled(library.items.isEmpty)
                    }.disabled(library.busy)
                    List(selection: $selectedItem) {
                        ForEach(Array(library.items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(item.title).lineLimit(1)
                                    Text(item.video?.creator ?? "Unavailable · skipped during playback")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button { library.play(from: index) } label: { Image(systemName: "play.fill") }
                                    .help("Play from this video").accessibilityLabel("Play \(item.title)")
                            }.tag(item.id).padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button("Move up") { if let item = selection { library.move(item, offset: -1) } }
                            .disabled(selection?.video == nil || selectedItem == library.items.first?.id)
                        Button("Move down") { if let item = selection { library.move(item, offset: 1) } }
                            .disabled(selection?.video == nil || selectedItem == library.items.last?.id)
                        Spacer()
                        Button("Remove video") { if let item = selection { library.remove(item) } }.disabled(selection == nil)
                    }.disabled(library.busy)
                }
            }
            if library.stale { Text("Previously loaded data · may be outdated").font(.caption).foregroundStyle(.orange) }
            HStack(alignment: .top) {
                Text(library.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                if library.signingIn { Button("Cancel sign-in") { library.cancelSignIn() } }
                else if library.canRetry { Button("Retry") { library.retryLast() }.disabled(library.busy) }
            }
        }.font(.system(size: 12))
            .controlSize(.small)
            .tint(Color(nsColor: MaroAppearance.accent))
            .padding(16).frame(minWidth: 490, minHeight: 360)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: MaroAppearance.background))
            .preferredColorScheme(.dark)
    }

    private var selection: YouTubePlaylistItem? { library.items.first { $0.id == selectedItem } }
}
