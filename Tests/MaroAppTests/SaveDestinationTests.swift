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

private actor BatchSaveRequests {
    enum Failure: Equatable { case rejected, ambiguous }
    let failure: Failure?
    let holdFirstPost: Bool
    var attempted: [String] = []
    var saved: Set<String> = []
    private var heldPost: CheckedContinuation<Void, Never>?
    init(failure: Failure? = nil, holdFirstPost: Bool = false) { self.failure = failure; self.holdFirstPost = holdFirstPost }
    func respond(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let playlistID = query.first { $0.name == "playlistId" }?.value ?? ""
        let status: Int
        let json: String
        if request.httpMethod == "POST" {
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let snippet = body["snippet"] as! [String: Any]
            let destination = snippet["playlistId"] as! String
            attempted.append(destination)
            if holdFirstPost && attempted.count == 1 {
                await withCheckedContinuation { heldPost = $0 }
            }
            if destination == "PLtwo", let failure {
                if failure == .ambiguous { throw URLError(.timedOut) }
                status = 403; json = #"{"error":{"message":"Fixture permission denied"}}"#
            } else {
                saved.insert(destination); status = 200; json = #"{"id":"confirmed-entry"}"#
            }
        } else if request.url?.path.hasSuffix("/playlists") == true {
            status = 200
            let items = ["PLone", "PLtwo", "PLthree"].map {
                ["id": $0, "snippet": ["title": $0], "contentDetails": ["itemCount": saved.contains($0) ? 1 : 0]] as [String: Any]
            }
            json = String(decoding: try JSONSerialization.data(withJSONObject: ["items": items]), as: UTF8.self)
        } else {
            status = 200
            json = saved.contains(playlistID)
                ? #"{"items":[{"id":"entry","snippet":{"title":"A song","resourceId":{"videoId":"abcdefghijk"}}}]}"#
                : #"{"items":[]}"#
        }
        return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func writes() -> [String] { attempted }
    func isHoldingPost() -> Bool { heldPost != nil }
    func releasePost() { heldPost?.resume(); heldPost = nil }
}

@MainActor private func batchSaveFixture(_ requests: BatchSaveRequests) throws -> (MaroController, PlaylistLibrary, URL) {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { try await requests.respond($0) }))
    library.playlists = ["PLone", "PLtwo", "PLthree"].map { YouTubePlaylist(id: $0, title: $0, count: 0) }
    return (controller, library, file)
}

@Test @MainActor func multiDestinationSaveDeduplicatesAndRetainsConfirmedMembership() async throws {
    let requests = BatchSaveRequests()
    let (controller, library, file) = try batchSaveFixture(requests)
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")
    let results = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo", "PLone"], accountScope: library.saveAccountScope)
    #expect(results.map(\.playlistID) == ["PLone", "PLtwo"])
    #expect(results.map(\.result) == [.added, .added])
    #expect(library.containsSavedVideo(video.id, in: "PLone"))
    #expect(library.containsSavedVideo(video.id, in: "PLtwo"))
    let again = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo"], accountScope: library.saveAccountScope)
    #expect(again.map(\.result) == [.alreadyInPlaylist, .alreadyInPlaylist])
    #expect(await requests.writes() == ["PLone", "PLtwo"])
    #expect(!library.busy)
    await controller.shutdown()
}

@Test @MainActor func multiDestinationSaveContinuesAfterRejectedWriteWithoutRepeatingSuccess() async throws {
    let requests = BatchSaveRequests(failure: .rejected)
    let (controller, library, file) = try batchSaveFixture(requests)
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")
    let results = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo", "PLthree"], accountScope: library.saveAccountScope)
    #expect(results[0].result == .added)
    if case .failed = results[1].result { } else { Issue.record("Rejected write should report its destination failure.") }
    #expect(results[2].result == .added)
    #expect(await requests.writes() == ["PLone", "PLtwo", "PLthree"])
    let retry = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo", "PLthree"], accountScope: library.saveAccountScope)
    #expect(retry[0].result == .alreadyInPlaylist)
    #expect(retry[2].result == .alreadyInPlaylist)
    #expect(await requests.writes() == ["PLone", "PLtwo", "PLthree", "PLtwo"])
    await controller.shutdown()
}

@Test @MainActor func multiDestinationSaveStopsEditsAfterAmbiguousWriteAndRejectsStaleScope() async throws {
    let requests = BatchSaveRequests(failure: .ambiguous)
    let (controller, library, file) = try batchSaveFixture(requests)
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")
    let stale = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo"], accountScope: "stale-account")
    #expect(stale.allSatisfy { if case .unavailable = $0.result { return true }; return false })
    #expect(await requests.writes().isEmpty)
    let results = await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo", "PLthree"], accountScope: library.saveAccountScope)
    #expect(results[0].result == .added)
    if case .uncertain = results[1].result { } else { Issue.record("Timed-out write must remain uncertain.") }
    if case .unavailable = results[2].result { } else { Issue.record("Later destinations must wait for authoritative refresh.") }
    #expect(await requests.writes() == ["PLone", "PLtwo"])
    #expect(library.canRetry)
    #expect(!library.canSaveVideo(to: "PLthree"))
    await controller.shutdown()
}

@Test @MainActor func multiDestinationSaveReservesLibraryAgainstConcurrentEdits() async throws {
    let requests = BatchSaveRequests(holdFirstPost: true)
    let (controller, library, file) = try batchSaveFixture(requests)
    defer { try? FileManager.default.removeItem(at: file) }
    library.selected = library.playlists.first
    let video = try VideoSummary(id: "abcdefghijk", title: "A song", creator: "An artist")
    let scope = library.saveAccountScope
    let task = Task { await library.saveVideo(video, toPlaylists: ["PLone", "PLtwo"], accountScope: scope) }
    for _ in 0..<100 {
        if await requests.isHoldingPost() { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(await requests.isHoldingPost())
    #expect(library.busy)
    #expect(!library.canReorder)
    #expect(!library.canSaveVideo(to: "PLthree"))
    #expect(await library.saveVideo(video, to: "PLthree", accountScope: scope) == .busy)
    let concurrent = await library.saveVideo(video, toPlaylists: ["PLthree"], accountScope: scope)
    #expect(concurrent.map(\.result) == [.busy])
    await requests.releasePost()
    #expect(await task.value.map(\.result) == [.added, .added])
    #expect(await requests.writes() == ["PLone", "PLtwo"])
    #expect(!library.busy)
    await controller.shutdown()
}

@Test @MainActor func saveDestinationAddsOnceAndReportsConfirmedResult() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw CancellationError() })
    let requests = SaveRequests()
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { await requests.respond($0) }))
    library.playlists = [YouTubePlaylist(id: "PLone", title: "One", count: 0)]
    library.connected = true
    #expect(library.canSaveVideo(to: "PLone"))
    library.busy = true
    #expect(!library.canSaveVideo(to: "PLone"))
    library.busy = false
    library.connected = false
    #expect(!library.canSaveVideo(to: "PLone"))
    library.connected = true
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
