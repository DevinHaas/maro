import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

private actor LibraryResponses {
    var deleted = false
    let rejectDelete: Bool
    init(rejectDelete: Bool) { self.rejectDelete = rejectDelete }
    func respond(_ request: URLRequest) -> (Data, URLResponse) {
        let playlist = #"{"id":"PLnew","snippet":{"title":"New"}}"#
        if request.httpMethod == "DELETE" { deleted = true }
        let body = request.httpMethod == "POST" ? playlist : deleted ? "{\"items\":[\(playlist)]}" : #"{"items":[]}"#
        let code = request.httpMethod == "DELETE" && rejectDelete ? 403 : 200
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
    }
}

@Test(arguments: [false, true]) @MainActor func removedOccurrenceStaysRemovedAfterLaggingRefresh(rejectDelete: Bool) async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let api = YouTubePlaylists(token: { "fixture" }, send: { request in
        let list = #"{"items":[{"id":"PLone","snippet":{"title":"One"}}]}"#
        let items = #"{"items":[{"id":"occ1","snippet":{"title":"Video","resourceId":{"videoId":"abcdefghijk"}}},{"id":"occ2","snippet":{"title":"Video","resourceId":{"videoId":"abcdefghijk"}}}]}"#
        let deleting = request.httpMethod == "DELETE"
        let body = deleting ? "{}" : request.url!.path.hasSuffix("/playlists") ? list : items
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: deleting && rejectDelete ? 403 : 200, httpVersion: nil, headerFields: nil)!)
    })
    let library = PlaylistLibrary(controller: controller, api: api)
    library.refresh()
    while library.busy { await Task.yield() }
    library.open(try #require(library.playlists.first))
    while library.busy { await Task.yield() }
    library.remove(try #require(library.items.first))
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == (rejectDelete ? ["occ1", "occ2"] : ["occ2"]))
    await controller.shutdown()
}

@Test(arguments: [false, true]) @MainActor func confirmedPlaylistChangesSurviveLaggingRefresh(rejectDelete: Bool) async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(
        loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] },
        prepare: { _, _ in throw CancellationError() })
    let responses = LibraryResponses(rejectDelete: rejectDelete)
    let api = YouTubePlaylists(token: { "fixture" }, send: { await responses.respond($0) })
    let library = PlaylistLibrary(controller: controller, api: api)
    library.create(title: "New")
    while library.busy { await Task.yield() }
    #expect(library.playlists.map(\.id) == ["PLnew"])
    #expect(library.destination == "PLnew")
    let created = try #require(library.playlists.first)
    library.selected = created
    library.delete(created)
    while library.busy { await Task.yield() }
    if rejectDelete {
        #expect(library.playlists == [created])
        #expect(library.selected == created)
        #expect(library.canRetry)
    } else {
        #expect(library.playlists.isEmpty)
        #expect(library.selected == nil)
        #expect(library.destination.isEmpty)
    }
    await controller.shutdown()
}
