import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

private actor NavigatingLibraryAPI {
    var loadingFirst = false
    func respond(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        let first = url.query?.contains("playlistId=PLfirst") == true
        let body: String
        if url.path.hasSuffix("/playlists") {
            body = #"{"items":[{"id":"PLfirst","snippet":{"title":"First"}},{"id":"PLsecond","snippet":{"title":"Second"}}]}"#
        } else {
            if first { loadingFirst = true; try await Task.sleep(for: .milliseconds(100)) }
            body = first ? #"{"items":[{"id":"first-item","snippet":{"title":"First item"}}]}"# : #"{"items":[{"id":"second-item","snippet":{"title":"Second item"}}]}"#
        }
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func navigatingDuringPlaylistLoadShowsTheLatestSelection() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let response = NavigatingLibraryAPI()
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { try await response.respond($0) }))
    library.open(YouTubePlaylist(id: "PLfirst", title: "First", count: 1))
    while !(await response.loadingFirst) { await Task.yield() }
    library.open(YouTubePlaylist(id: "PLsecond", title: "Second", count: 1))
    while library.busy { await Task.yield() }
    #expect(library.selected?.id == "PLsecond")
    #expect(library.items.map(\.id) == ["second-item"])
    await controller.shutdown()
}
