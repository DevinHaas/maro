import AppKit
import MaroCore
import SwiftUI

enum ApplicationRoute: Equatable {
    case home, search, playlist(String), favorites
}

/// Navigation and discovery state never replace the controller's captured playback queue.
@MainActor final class ApplicationModel: ObservableObject {
    let controller: MaroController
    let library: PlaylistLibrary
    let player: PlayerPresentation
    @Published private(set) var route: ApplicationRoute = .home
    @Published private(set) var history: [ApplicationRoute] = []
    @Published var globalQuery = "" { didSet { if oldValue != globalQuery { updatePreview() } } }
    @Published var libraryFilter = ""
    @Published var libraryCollapsed = false
    @Published var searchState: SearchViewState
    @Published var searchFocused = false
    @Published private(set) var previewOpen = false
    @Published private(set) var previewVideos: [VideoSummary] = []
    @Published private(set) var previewQueries: [String] = []
    @Published private(set) var previewLoading = false
    @Published private(set) var previewError: String?
    @Published var previewFocusedIndex: Int?
    private var searchSeedVideos: [VideoSummary] = []
    private var searchSeedQueries: [String] = ["Live music", "Piano", "Jazz", "Ambient"]
    private var previewTask: Task<Void, Never>?
    private var previewID = UUID()
    private let previewDelay: @Sendable (Duration) async throws -> Void
    @Published var actionError: String?
    private var searchTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?

    init(controller: MaroController, library: PlaylistLibrary,
         previewDelay: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.controller = controller; self.library = library
        self.previewDelay = previewDelay
        player = PlayerPresentation(snapshot: controller.snapshot)
        searchState = controller.searchState
    }

    var filteredPlaylists: [YouTubePlaylist] {
        let query = libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return library.playlists }
        return library.playlists.filter { $0.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
    var favoritesVisible: Bool {
        libraryFilter.isEmpty || "Favorites".range(of: libraryFilter, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
    var canGoBack: Bool { !history.isEmpty }

    func showHome() { navigate(.home) }
    func showFavorites() { navigate(.favorites) }
    func openPlaylist(_ playlist: YouTubePlaylist) {
        library.open(playlist)
        navigate(.playlist(playlist.id))
    }
    func goBack() {
        guard let previous = history.popLast() else { return }
        route = previous
        closeSearch()
        if case let .playlist(id) = previous, let playlist = library.playlists.first(where: { $0.id == id }), library.selected?.id != id {
            library.open(playlist)
        }
    }
    func navigate(_ destination: ApplicationRoute) {
        closeSearch(cancelRequest: destination != .search)
        guard route != destination else { return }
        history.append(route)
        route = destination
    }
    func render() {
        player.snapshot = controller.snapshot
        searchState = controller.searchState
    }
    func submitSearch(_ query: String? = nil) {
        let query = (query ?? globalQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        globalQuery = query
        navigate(.search)
        searchTask?.cancel()
        searchTask = Task { await controller.search(query); render() }
    }
    func retrySearch() { submitSearch(searchState.query) }
    func setSearchSeeds(videos: [VideoSummary], queries: [String]) {
        searchSeedVideos = videos; searchSeedQueries = queries.isEmpty ? ["Live music", "Piano", "Jazz", "Ambient"] : queries
        if previewOpen, globalQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { updatePreview() }
    }
    func focusSearch() { searchFocused = true; previewOpen = true; updatePreview() }
    func dismissPreview() {
        previewOpen = false; previewFocusedIndex = nil; previewID = UUID()
        previewTask?.cancel(); previewTask = nil; previewLoading = false
    }
    func closeSearch(cancelRequest: Bool = true) {
        searchFocused = false; previewOpen = false; previewFocusedIndex = nil; previewID = UUID(); previewLoading = false
        if cancelRequest { previewTask?.cancel(); previewTask = nil }
    }
    func movePreviewFocus(_ direction: Int) {
        guard previewOpen else { focusSearch(); return }
        let count = previewQueries.count + previewVideos.count
        guard count > 0 else { return }
        previewFocusedIndex = min(max((previewFocusedIndex ?? (direction > 0 ? -1 : count)) + direction, 0), count - 1)
    }
    func activateFocusedPreview() {
        guard let index = previewFocusedIndex else { return }
        if previewQueries.indices.contains(index) { submitSearch(previewQueries[index]) }
        else {
            let videoIndex = index - previewQueries.count
            if previewVideos.indices.contains(videoIndex) { play(previewVideos[videoIndex]); closeSearch() }
        }
    }
    func retryPreview() { updatePreview() }
    private func updatePreview() {
        guard searchFocused || previewOpen else { return }
        previewOpen = true; previewFocusedIndex = nil; previewTask?.cancel(); previewID = UUID()
        let id = previewID
        let query = globalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let known = searchSeedVideos + player.snapshot.favorites + searchState.results
        var ids = Set<String>()
        previewVideos = Array(known.filter { video in
            ids.insert(video.id).inserted && (query.isEmpty || "\(video.title) \(video.creator)".localizedStandardContains(query))
        }.prefix(5))
        var queries = Set<String>()
        previewQueries = Array((searchSeedQueries + known.map(\.creator)).filter {
            !$0.isEmpty && queries.insert($0.lowercased()).inserted && (query.isEmpty || $0.localizedStandardContains(query))
        }.prefix(4))
        previewError = player.snapshot.sourceNeedsUpdate ? ExtractorFailure.sourceNeedsUpdate.message : nil
        previewLoading = false
        guard !player.snapshot.sourceNeedsUpdate else { return }
        guard query.count >= 2 else { return }
        previewLoading = true
        previewTask = Task { [weak self, controller, previewDelay] in
            do {
                try await previewDelay(.milliseconds(300))
                try Task.checkCancellation()
                let videos = try await controller.metadataSearch(query, intent: .foreground)
                try Task.checkCancellation()
                guard let self, self.previewID == id else { return }
                self.previewVideos = Array(videos.prefix(5)); self.previewLoading = false
            } catch {
                guard let self, self.previewID == id else { return }
                self.previewLoading = false
                if !(error is CancellationError) {
                    self.previewError = (error as? ExtractorFailure)?.message ?? "Search could not be completed. Try again."
                    self.previewVideos = []
                }
            }
        }
    }
    func revealMore() { controller.revealMoreResults(); render() }
    func play(_ video: VideoSummary) {
        selectionTask?.cancel(); actionError = nil
        selectionTask = Task {
            do { try await controller.select(video) }
            catch is CancellationError { }
            catch { actionError = controller.snapshot.error ?? error.localizedDescription }
            render()
        }
    }
    func toggleFavorite(_ video: VideoSummary) {
        do { try controller.toggleFavorite(video); actionError = nil }
        catch { actionError = error.localizedDescription }
        render()
    }
    func perform(_ command: CommandName, videoID: String? = nil) {
        actionError = nil
        Task {
            do {
                let response = try await controller.execute(CommandRequest(command: command, videoID: videoID), openSearch: { self.showHome() })
                actionError = response.error?.message
            } catch { actionError = error.localizedDescription }
            render()
        }
    }
    func offerAdd(_ video: VideoSummary) { library.pendingVideo = video; libraryCollapsed = false; closeSearch() }
}
