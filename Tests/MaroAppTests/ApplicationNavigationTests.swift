import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

@Test @MainActor func libraryFilterIsLocalAndIndependentOfNavigationAndGlobalQuery() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { throw CancellationError() },
        send: { _ in Issue.record("Filtering must not request YouTube"); throw CancellationError() }))
    library.playlists = [YouTubePlaylist(id: "quiet", title: "Café piano", count: 3), YouTubePlaylist(id: "rock", title: "Rock", count: 2)]
    let app = ApplicationModel(controller: controller, library: library)
    #expect(app.route == .home)
    app.globalQuery = "live jazz"
    app.libraryFilter = "CAFE"
    #expect(app.filteredPlaylists.map(\.id) == ["quiet"])
    app.showFavorites()
    app.showHome()
    app.goBack()
    #expect(app.route == .favorites)
    #expect(app.globalQuery == "live jazz")
    #expect(app.libraryFilter == "CAFE")
    app.libraryFilter = ""
    #expect(app.filteredPlaylists.map(\.id) == ["quiet", "rock"])
    await controller.shutdown()
}
