import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

private actor ReorderResponses {
    var order = ["a", "b", "c"]
    var writes: [URLRequest] = []
    var mode = "lag"
    func setMode(_ mode: String) { self.mode = mode }
    func setOrder(_ order: [String]) { self.order = order }
    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        let writing = request.httpMethod == "PUT"
        if writing {
            writes.append(request)
            if mode == "ambiguous" { throw URLError(.timedOut) }
        }
        if !writing && mode == "failedRefresh" && !writes.isEmpty { throw URLError(.notConnectedToInternet) }
        let body: String
        if writing { body = "{}" }
        else if request.url!.path.hasSuffix("/playlists") { body = #"{"items":[{"id":"PLone","snippet":{"title":"One"}}]}"# }
        else {
            let rows = order.map { #"{"id":"\#($0)","snippet":{"title":"Duplicate","publishedAt":"2024-01-01T00:00:00Z","resourceId":{"kind":"youtube#video","videoId":"abcdefghijk"}}}"# }
            body = "{\"items\":[" + rows.joined(separator: ",") + "]}"
        }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: writing && mode == "reject" ? 403 : 200, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor private func reorderFixture(_ responses: ReorderResponses, now: @escaping () -> Date = Date.init) async throws -> (PlaylistLibrary, MaroController, URL) {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let api = YouTubePlaylists(token: { "fixture" }, send: { try await responses.respond($0) })
    let library = PlaylistLibrary(controller: controller, api: api, now: now)
    library.refresh()
    while library.busy { await Task.yield() }
    library.open(try #require(library.playlists.first))
    while library.busy { await Task.yield() }
    return (library, controller, file)
}

@Test @MainActor func occurrenceMoveKeepsAcknowledgedOrderThroughLaggingRefreshAndReopen() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    library.move(occurrenceID: "a", in: "PLone", to: 2)
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    #expect(await responses.writes.count == 1)
    library.back()
    while library.busy { await Task.yield() }
    library.open(try #require(library.playlists.first))
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    await controller.shutdown()
}

@Test @MainActor func priorExternalOrderBecomesAuthoritativeAfterSaveLagWindow() async throws {
    let responses = ReorderResponses()
    var time = Date(timeIntervalSince1970: 1_000)
    let (library, controller, file) = try await reorderFixture(responses, now: { time })
    defer { try? FileManager.default.removeItem(at: file) }
    library.move(occurrenceID: "a", in: "PLone", to: 2)
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    time = time.addingTimeInterval(61)
    await responses.setMode("failedRefresh")
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    await responses.setMode("lag")
    await responses.setOrder(["a", "b", "c"])
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["a", "b", "c"])
    #expect(library.reorderState == .idle)
    #expect(library.status.contains("Playlist changed"))
    #expect(await responses.writes.count == 1)
    await controller.shutdown()
}

@Test @MainActor func ambiguousMoveCannotRepeatUntilAuthoritativeRefresh() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    await responses.setMode("ambiguous")
    library.move(occurrenceID: "a", in: "PLone", to: 2)
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    library.move(occurrenceID: "b", in: "PLone", to: 2)
    while library.busy { await Task.yield() }
    #expect(library.reorderState == .unconfirmed)
    #expect(!library.canReorder)
    library.remove(try #require(library.items.first))
    while library.busy { await Task.yield() }
    #expect(library.reorderState == .unconfirmed)
    #expect(library.items.map(\.id) == ["b", "c", "a"])
    library.move(occurrenceID: "c", in: "PLone", to: 0)
    #expect(await responses.writes.count == 1)
    library.retryLast()
    while library.busy { await Task.yield() }
    #expect(library.canReorder)
    #expect(library.items.map(\.id) == ["a", "b", "c"])
    #expect(await responses.writes.count == 1)
    await controller.shutdown()
}

@Test @MainActor func rejectedMoveRollsBackAndOnlyExplicitRetryMakesSecondWrite() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    await responses.setMode("reject")
    library.move(occurrenceID: "c", in: "PLone", to: 0)
    #expect(library.items.map(\.id) == ["c", "a", "b"])
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["a", "b", "c"])
    #expect(library.canRetry)
    #expect(library.reorderState == .rejected)
    #expect(await responses.writes.count == 1)
    await responses.setMode("lag")
    library.retryLast()
    // The explicit retry dispatches on the main actor before starting its save task.
    await Task.yield()
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["c", "a", "b"])
    #expect(await responses.writes.count == 2)
    await controller.shutdown()
}

@Test @MainActor func acknowledgedMoveSurvivesFailedRefreshThenAcceptsExternalMembership() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    await responses.setMode("failedRefresh")
    library.move(occurrenceID: "c", in: "PLone", to: 0)
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["c", "a", "b"])
    #expect(library.reorderState == .savedRefreshUnavailable)
    #expect(library.status.contains("Saved; refresh unavailable"))
    await responses.setMode("lag")
    await responses.setOrder(["c", "b", "external"])
    library.retryLast()
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["c", "b", "external"])
    #expect(library.status.contains("Playlist changed"))
    #expect(await responses.writes.count == 1)
    await controller.shutdown()
}

@Test @MainActor func dragUsesOccurrenceInsertionBoundariesAndRejectsInvalidCancelledOrStaleDrops() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    var payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 2))
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    #expect(!library.drop(payload, in: "PLother", insertionIndex: 0))
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    library.cancelDrag()
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 0))
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 4))
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    library.refresh()
    while library.busy { await Task.yield() }
    // A refresh with unchanged membership is safe, but one removing the occurrence invalidates it.
    await responses.setOrder(["a", "c"])
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 0))
    #expect(await responses.writes.isEmpty)
    await responses.setOrder(["a", "b", "c"])
    library.refresh()
    while library.busy { await Task.yield() }
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    #expect(library.drop(payload, in: "PLone", insertionIndex: 3))
    #expect(library.items.map(\.id) == ["a", "c", "b"])
    #expect(library.beginDrag(occurrenceID: "a", in: "PLone") == nil)
    while library.busy { await Task.yield() }
    payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    #expect(library.drop(payload, in: "PLone", insertionIndex: 0))
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["b", "a", "c"])
    #expect(await responses.writes.count == 2)
    await controller.shutdown()
}

@Test @MainActor func navigationAndDisconnectInvalidateCapturedDrag() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    let payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    library.back()
    while library.busy { await Task.yield() }
    library.open(try #require(library.playlists.first))
    while library.busy { await Task.yield() }
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 0))
    let accountPayload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    library.disconnect()
    #expect(!library.drop(accountPayload, in: "PLone", insertionIndex: 0))
    #expect(await responses.writes.isEmpty)
    await controller.shutdown()
}

@Test @MainActor func applicationHomeAndBackRejectCapturedDragEvenWhenPlaylistStaysSelected() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    let app = ApplicationModel(controller: controller, library: library)
    app.navigate(.playlist("PLone"))
    let payload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    app.showHome()
    app.goBack()
    #expect(app.route == .playlist("PLone"))
    #expect(library.selected?.id == "PLone")
    #expect(!library.drop(payload, in: "PLone", insertionIndex: 0))
    while library.busy { await Task.yield() }
    app.showFavorites()
    let backPayload = try #require(library.beginDrag(occurrenceID: "b", in: "PLone"))
    app.goBack()
    #expect(!library.drop(backPayload, in: "PLone", insertionIndex: 0))
    while library.busy { await Task.yield() }
    #expect(await responses.writes.isEmpty)
    await controller.shutdown()
}

@Test @MainActor func failedExplicitRefreshKeepsAmbiguousMoveBlocked() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    await responses.setMode("ambiguous")
    library.move(occurrenceID: "b", in: "PLone", to: 0)
    while library.busy { await Task.yield() }
    await responses.setMode("failedRefresh")
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(!library.canReorder)
    #expect(library.reorderState == .unconfirmed)
    #expect(library.items.map(\.id) == ["b", "a", "c"])
    #expect(await responses.writes.count == 1)
    await controller.shutdown()
}

@Test @MainActor func refreshFromHomeResolvesUnconfirmedPlaylistWithoutReplayingMove() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    await responses.setMode("ambiguous")
    library.move(occurrenceID: "b", in: "PLone", to: 0)
    while library.busy { await Task.yield() }
    await responses.setMode("failedRefresh")
    library.back()
    while library.busy { await Task.yield() }
    await responses.setMode("lag")
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(library.reorderState == .idle)
    #expect(library.loadedItemsByPlaylist["PLone"]?.map(\.id) == ["a", "b", "c"])
    library.open(try #require(library.playlists.first))
    while library.busy { await Task.yield() }
    #expect(library.canReorder)
    #expect(library.items.map(\.id) == ["a", "b", "c"])
    #expect(await responses.writes.count == 1)
    await controller.shutdown()
}

@Test @MainActor func confirmedRemovalAfterMoveDoesNotReturnDuringLaggingRefresh() async throws {
    let responses = ReorderResponses()
    let (library, controller, file) = try await reorderFixture(responses)
    defer { try? FileManager.default.removeItem(at: file) }
    library.move(occurrenceID: "c", in: "PLone", to: 0)
    while library.busy { await Task.yield() }
    library.remove(occurrenceID: "a", from: "PLone")
    while library.busy { await Task.yield() }
    library.refresh()
    while library.busy { await Task.yield() }
    #expect(library.items.map(\.id) == ["c", "b"])
    await controller.shutdown()
}
