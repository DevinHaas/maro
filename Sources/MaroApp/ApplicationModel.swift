import AppKit
import Combine
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
    let home: HomeRecommendations
    @Published private(set) var route: ApplicationRoute = .home
    @Published private(set) var history: [ApplicationRoute] = []
    @Published var globalQuery = ""
    @Published var libraryFilter = ""
    @Published var libraryCollapsed = false
    @Published var searchState: SearchViewState
    @Published var searchFocused = false
    @Published var actionError: String?
    private var searchTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var libraryObservation: AnyCancellable?

    init(controller: MaroController, library: PlaylistLibrary, recommendationNow: @escaping () -> Date = Date.init) {
        self.controller = controller; self.library = library
        player = PlayerPresentation(snapshot: controller.snapshot)
        searchState = controller.searchState
        home = HomeRecommendations(controller: controller, now: recommendationNow)
        home.onChange = { [weak self] in self?.objectWillChange.send() }
        libraryObservation = library.objectWillChange.sink { [weak self] in
            Task { @MainActor in
                await Task.yield()
                self?.updateHomePreferences()
            }
        }
        updateHomePreferences()
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
        searchFocused = false
        if case let .playlist(id) = previous, let playlist = library.playlists.first(where: { $0.id == id }), library.selected?.id != id {
            library.open(playlist)
        }
    }
    func navigate(_ destination: ApplicationRoute) {
        searchFocused = false
        guard route != destination else { return }
        history.append(route)
        route = destination
    }
    func render() {
        player.snapshot = controller.snapshot
        searchState = controller.searchState
        updateHomePreferences()
        home.resumeIfNeeded()
    }
    func updateHomePreferences() {
        home.update(favorites: controller.snapshot.favorites,
            playlists: library.connected ? library.playlists : [],
            loaded: library.connected ? library.loadedItemsByPlaylist : [:], scope: library.recommendationScope)
    }
    func playFavorites() {
        let items = controller.snapshot.favorites.map { YouTubePlaylistItem(id: "favorite-" + $0.id, video: $0, title: $0.title) }
        guard !items.isEmpty else { return }
        selectionTask?.cancel()
        selectionTask = Task {
            do { try await controller.playPlaylist(items) }
            catch is CancellationError { }
            catch { actionError = controller.snapshot.error ?? error.localizedDescription }
            render()
        }
    }
    func submitSearch(_ query: String? = nil) {
        let query = (query ?? globalQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        globalQuery = query
        navigate(.search)
        searchTask?.cancel()
        searchTask = Task { await controller.search(query); render() }
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
    func offerAdd(_ video: VideoSummary) { library.pendingVideo = video; libraryCollapsed = false; searchFocused = false }
}
