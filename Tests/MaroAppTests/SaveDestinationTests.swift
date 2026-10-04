import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

private actor SaveRequests {
    var writes = 0
    func respond(_ request: URLRequest) -> (Data, URLResponse) {
        if request.httpMethod == "POST" { writes += 1; return (Data(#"{"id":"entry1"}"#.utf8), response(request)) }
        if request.url?.path.hasSuffix("/playlists") == true {
            return (Data(#"{"items":[{"id":"PLone","snippet":{"title":"One"},"contentDetails":{"itemCount":1}}]}"#.utf8), response(request))
        }
        return (Data(#"{"items":[]}"#.utf8), response(request))
    }
    func writeCount() -> Int { writes }
    private func response(_ request: URLRequest) -> URLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
}

private actor AmbiguousSaveRequests {
    var writes = 0
    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        if request.httpMethod == "POST" { writes += 1; throw URLError(.timedOut) }
        return (Data(#"{"items":[]}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func writeCount() -> Int { writes }
}

@Test @MainActor func saveDestinationAddsOnceAndReportsConfirmedResult() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let requests = SaveRequests()
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { await requests.respond($0) }))
    library.playlists = [YouTubePlaylist(id: "PLone", title: "One", count: 0)]
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")

    let result = await library.saveVideo(video, to: "PLone", accountScope: library.saveAccountScope)

    #expect(result == .added)
    #expect(await requests.writeCount() == 1)
    #expect(library.playlists.first?.count == 1)
    await controller.shutdown()
}

@Test @MainActor func saveDestinationRejectsStaleAccountWithoutWriting() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let requests = SaveRequests()
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { await requests.respond($0) }))
    library.playlists = [YouTubePlaylist(id: "PLone", title: "One", count: 0)]
    let staleScope = UUID().uuidString
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")

    let result = await library.saveVideo(video, to: "PLone", accountScope: staleScope)

    #expect(result == .unavailable("This YouTube account changed. Reopen the save menu."))
    #expect(await requests.writeCount() == 0)
    await controller.shutdown()
}

@Test @MainActor func uncertainSaveIsNotReplayedBeforeAuthoritativeRefresh() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let requests = AmbiguousSaveRequests()
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { try await requests.respond($0) }))
    library.playlists = [YouTubePlaylist(id: "PLone", title: "One", count: 0)]
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")

    let first = await library.saveVideo(video, to: "PLone", accountScope: library.saveAccountScope)
    let second = await library.saveVideo(video, to: "PLone", accountScope: library.saveAccountScope)

    if case .uncertain = first { } else { Issue.record("A timed-out POST should report an uncertain result.") }
    if case .unavailable = second { } else { Issue.record("A second save should wait for an authoritative refresh.") }
    #expect(await requests.writeCount() == 1)
    await controller.shutdown()
}
