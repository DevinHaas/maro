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

@Test func playlistSearchMatchesTitleAndCreatorWithoutLosingOccurrencePositions() throws {
    let beyonce = try VideoSummary(id: "abcdefghijk", title: "Halo", creator: "Beyoncé")
    let other = try VideoSummary(id: "bcdefghijkl", title: "Other", creator: "Else")
    let items = [
        YouTubePlaylistItem(id: "first", video: beyonce, title: "Halo"),
        YouTubePlaylistItem(id: "middle", video: other, title: "Other"),
        YouTubePlaylistItem(id: "duplicate", video: beyonce, title: "Halo")
    ]

    let creatorMatches = PlaylistSearchProjection(items: items, query: "  BEYONCE  ")
    #expect(creatorMatches.map(\.originalIndex) == [0, 2])
    #expect(creatorMatches.map(\.item.id) == ["first", "duplicate"])

    let titleMatches = PlaylistSearchProjection(items: items, query: "hÁLo")
    #expect(titleMatches.map(\.originalIndex) == [0, 2])
    #expect(PlaylistSearchProjection(items: items, query: "missing").isEmpty)
    #expect(PlaylistSearchProjection(items: items, query: " ").map(\.item.id) == items.map(\.id))
}

@Test @MainActor func staleModalCannotRemoveAnotherPlaylistOccurrenceAndCancelDoesNotWrite() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let requests = ModalRequests()
    let api = YouTubePlaylists(token: { "fixture" }, send: { await requests.respond($0) })
    let library = PlaylistLibrary(controller: controller, api: api)
    let first = YouTubePlaylist(id: "PLone", title: "One", count: 2)
    let other = YouTubePlaylist(id: "PLtwo", title: "Two", count: 1)
    library.playlists = [first, other]
    library.selected = first
    let video = try VideoSummary(id: "abcdefghijk", title: "Duplicate", creator: "Test")
    library.items = [YouTubePlaylistItem(id: "a", video: video, title: video.title),
                     YouTubePlaylistItem(id: "b", video: video, title: video.title)]
    library.presentItemActions(occurrenceID: "b", playlistID: first.id)
    library.dismissActions()
    #expect(await requests.writes.isEmpty)
    library.presentItemActions(occurrenceID: "b", playlistID: first.id)
    library.selected = other
    library.items = [YouTubePlaylistItem(id: "b", video: video, title: video.title)]
    library.remove(occurrenceID: "b", from: first.id)
    #expect(await requests.writes.isEmpty)
    #expect(library.items.map(\.id) == ["b"])
    #expect(library.status.contains("no longer open"))
    await controller.shutdown()
}

private actor ModalRequests {
    var writes: [String] = []
    func respond(_ request: URLRequest) -> (Data, URLResponse) {
        if request.httpMethod != "GET" { writes.append(request.url!.absoluteString) }
        return (Data(#"{"items":[]}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func rowFavoriteCapacityGivesFeedbackAndAllowsRemoval() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let favorites = try (0..<20).map { try VideoSummary(id: String(format: "%011d", $0), title: "Saved \($0)", creator: "Test") }
    var document = StateDocument()
    for video in favorites { try document.toggleFavorite(video) }
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }))
    let new = try VideoSummary(id: "abcdefghijk", title: "New favorite", creator: "Test")
    library.toggleFavorite(new)
    #expect(controller.snapshot.favorites.count == 20)
    #expect(library.status == "Favorites are full (20 of 20). Remove one before adding another.")
    library.toggleFavorite(favorites[0])
    library.toggleFavorite(new)
    #expect(controller.snapshot.favorites.contains(new))
    #expect(controller.snapshot.favorites.count == 20)
    await controller.shutdown()
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
