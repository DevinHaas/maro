import AVFoundation
import Foundation
import Testing
@testable import MaroCore

private actor PlaylistRequests {
    var requests: [URLRequest] = []
    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        let url = request.url!
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []
        var body = "{}"
        if request.httpMethod == "POST", url.path.hasSuffix("/playlists") {
            body = #"{"id":"PLnew","snippet":{"title":"New"}}"#
        } else if request.httpMethod == "GET", url.path.hasSuffix("/playlists") {
            if query.contains(where: { $0.name == "id" }) {
                body = #"{"items":[{"id":"PLmine","snippet":{"title":"Old","description":"Keep this","defaultLanguage":"en","channelId":"owner"}}]}"#
            } else if query.contains(where: { $0.name == "pageToken" }) {
                body = #"{"items":[{"id":"PLtwo","snippet":{"title":"Second"},"contentDetails":{"itemCount":0}}]}"#
            } else {
                body = #"{"items":[{"id":"PLmine","snippet":{"title":"First"},"contentDetails":{"itemCount":3}}],"nextPageToken":"second"}"#
            }
        } else if request.httpMethod == "GET" {
            if query.contains(where: { $0.name == "playlistId" && $0.value == "PLpaged" }) {
                body = query.contains(where: { $0.name == "pageToken" })
                    ? #"{"items":[{"id":"later","snippet":{"resourceId":{"videoId":"01234567890"}}}]}"#
                    : #"{"items":[],"nextPageToken":"later"}"#
            } else {
                body = #"{"items":[{"id":"item1","snippet":{"title":"One","resourceId":{"videoId":"01234567890"}}},{"id":"item2","snippet":{"title":"One again","resourceId":{"videoId":"01234567890"}}},{"id":"item3","snippet":{"title":"Gone"}}]}"#
            }
        }
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: request.httpMethod == "DELETE" ? 204 : 200,
            httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func unavailablePlaylistEntriesRetainDatesAndResourceIdentityWithoutBecomingPlayable() async throws {
    let api = YouTubePlaylists(token: { "fixture" }, send: { request in
        let body = #"{"items":[{"id":"private","snippet":{"title":"Private video","publishedAt":"2026-09-02T13:45:00Z","resourceId":{"videoId":"01234567890"}}},{"id":"deleted","snippet":{"title":"Deleted video","resourceId":{"videoId":"01234567891"}}},{"id":"live","snippet":{"title":"Live set","publishedAt":"unknown","resourceId":{"videoId":"01234567892"}}}]}"#
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    })
    let items = try await api.items(in: "PLone")
    #expect(items[0].video == nil && items[1].video == nil)
    #expect(items[0].resourceVideoID == "01234567890")
    #expect(items[0].addedAt == ISO8601DateFormatter().date(from: "2026-09-02T13:45:00Z"))
    #expect(items[2].video?.title == "Live set")
    #expect(items[2].addedAt == nil)
}

@Test @MainActor func playlistAPIPaginatesPreservesDuplicatesAndWritesOnlyRequestedFields() async throws {
    let probe = PlaylistRequests()
    let api = YouTubePlaylists(token: { "test-token" }, send: { try await probe.respond($0) })
    let playlists = try await api.playlists()
    #expect(playlists.map(\.id) == ["PLmine", "PLtwo"])
    let items = try await api.items(in: "PLmine")
    #expect(items.count == 3)
    #expect(items[0].video?.id == items[1].video?.id)
    #expect(items[0].id != items[1].id)
    #expect(items[2].video == nil)
    let created = try await api.create(title: "  New  ")
    #expect(created.id == "PLnew" && created.title == "New" && created.count == 0)
    try await api.rename("PLmine", title: "Renamed")
    await #expect(throws: YouTubeAccountError.self) { try await api.add(#require(items[0].video), to: "PLmine") }
    await #expect(throws: YouTubeAccountError.self) { try await api.add(#require(items[0].video), to: "PLpaged") }
    try await api.add(VideoSummary(id: "abcdefghijk", title: "One", creator: "Test"), to: "PLmine")
    try await api.move(items[1], in: "PLmine", to: 0)
    try await api.remove(items[1])
    let requests = await probe.requests
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-token" })
    #expect(requests[0].url!.query!.contains("mine=true"))
    #expect(requests[1].url!.query!.contains("pageToken=second"))
    let bodies = try requests.compactMap(\.httpBody).map { try JSONSerialization.jsonObject(with: $0) as! [String: Any] }
    #expect((bodies[0]["status"] as? [String: String])?["privacyStatus"] == "private")
    #expect((bodies[0]["snippet"] as? [String: String])?["title"] == "New")
    let renamed = bodies[1]["snippet"] as! [String: String]
    #expect(renamed == ["title": "Renamed", "description": "Keep this", "defaultLanguage": "en"])
    #expect(bodies[3]["id"] as? String == "item2")
    #expect((bodies[3]["snippet"] as? [String: Any])?["position"] as? Int == 0)
    #expect(requests.last?.httpMethod == "DELETE")
    #expect(requests.last?.url?.query == "id=item2")
    #expect(requests.allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
    await #expect(throws: YouTubeAccountError.self) { try await api.create(title: "   ") }
    await #expect(throws: YouTubeAccountError.self) { try await api.items(in: "../other") }
    #expect(await probe.requests.count == requests.count)
    try await api.delete("PLnew")
    let deletion = await probe.requests.last
    #expect(deletion?.httpMethod == "DELETE")
    #expect(deletion?.url?.path == "/youtube/v3/playlists")
    #expect(deletion?.url?.query == "id=PLnew")
    #expect(deletion?.httpBody == nil)
    await #expect(throws: YouTubeAccountError.self) { try await api.delete("../other") }
    #expect(await probe.requests.count == requests.count + 1)

    let denied = YouTubePlaylists(token: { "test" }, send: { request in
        (Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}]}}"#.utf8),
         HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!)
    })
    do { _ = try await denied.playlists(); Issue.record("Expected quota error") }
    catch { #expect(error.localizedDescription.contains("daily API allowance")) }
}

@Test @MainActor func timelineEndOnlyAdvancesPlayingPlaylistOnce() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let audio = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: audio) }
    let video = try VideoSummary(id: "01234567890", title: "Repeated", creator: "Test")
    let engine = PlaybackEngine()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, position in
            try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    try await controller.playPlaylist((0..<3).map { YouTubePlaylistItem(id: "\($0)", video: video, title: video.title) })
    controller.pause()
    let duration = try #require(engine.timeline?.duration)
    let id = try #require(controller.snapshot.timelineID)
    controller.seek(to: duration, timelineID: id)
    let deadline = ContinuousClock().now.advanced(by: .seconds(4))
    while engine.positionSeconds < duration - 0.05, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    try await Task.sleep(for: .milliseconds(50))
    #expect(controller.snapshot.canGoPrevious == false, "Paused seek must not advance")
    controller.seek(to: 0.1, timelineID: id)
    while engine.positionSeconds > 0.2, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    try await controller.resume()
    controller.seek(to: duration, timelineID: id)
    while controller.snapshot.canGoPrevious != true, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    controller.pause()
    #expect(controller.snapshot.canGoPrevious == true)
    #expect(controller.snapshot.canGoNext == true, "Must advance to second occurrence, not third")
    #expect(controller.snapshot.timelineID != id)
    controller.seek(to: 0.8, timelineID: id)
    #expect(controller.snapshot.seekTarget == nil, "Old occurrence's draft must not seek the reused player")
    await controller.shutdown()
}

@Test @MainActor func selectedDuplicateKeepsOccurrenceAndOriginThroughCapturedQueueAndPause() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let audio = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: audio) }
    let video = try VideoSummary(id: "01234567890", title: "Repeated", creator: "Test")
    let next = try VideoSummary(id: "01234567891", title: "Next", creator: "Test")
    let engine = PlaybackEngine()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, position in
            try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    var saved = [YouTubePlaylistItem(id: "first", video: video, title: video.title),
                 YouTubePlaylistItem(id: "second", video: video, title: video.title),
                 YouTubePlaylistItem(id: "third", video: next, title: next.title)]
    try await controller.playPlaylist(saved, startingAt: 1, playlistID: "PLone")
    controller.pause()
    saved.remove(at: 1)
    #expect(controller.snapshot.activePlaylistItemID == "second")
    #expect(controller.snapshot.originPlaylistID == "PLone")
    #expect(controller.snapshot.playback == .paused)
    #expect(try await controller.execute(CommandRequest(command: .next), openSearch: {}).ok)
    #expect(controller.snapshot.activePlaylistItemID == "third")
    #expect(controller.snapshot.loadedVideo?.video == next)
    try await controller.select(video)
    #expect(controller.snapshot.activePlaylistItemID == nil)
    #expect(controller.snapshot.originPlaylistID == nil)
    await controller.shutdown()
}

@Test @MainActor func playlistPlaybackSkipsFailuresKeepsOccurrencesAndStopsAtEnd() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let audio = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: audio) }
    let first = try VideoSummary(id: "01234567890", title: "First", creator: "Test")
    let bad = try VideoSummary(id: "01234567891", title: "Bad", creator: "Test")
    let last = try VideoSummary(id: "01234567892", title: "Last", creator: "Test")
    let engine = PlaybackEngine()
    var attempts: [String] = []
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [bad] }, prepare: { video, position in
            attempts.append(video.id)
            if video.id == bad.id { throw ExtractorFailure.videoUnavailable }
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video, positionSeconds: position)
        })
    let items = [YouTubePlaylistItem(id: "a", video: first, title: first.title),
                 YouTubePlaylistItem(id: "b", video: first, title: first.title),
                 YouTubePlaylistItem(id: "c", video: nil, title: "Gone"),
                 YouTubePlaylistItem(id: "d", video: bad, title: bad.title),
                 YouTubePlaylistItem(id: "e", video: last, title: last.title)]
    try await controller.playPlaylist(items)
    controller.pause()
    #expect(controller.snapshot.canGoPrevious == false)
    #expect(controller.snapshot.canGoNext == true)
    #expect(try await controller.execute(CommandRequest(command: .next), openSearch: {}).ok)
    #expect(controller.snapshot.loadedVideo?.video == first)
    #expect(controller.snapshot.canGoPrevious == true, "Second occurrence must have its own index")
    #expect(controller.snapshot.playback == .paused)
    #expect(try await controller.execute(CommandRequest(command: .previous), openSearch: {}).ok)
    #expect(controller.snapshot.loadedVideo?.video == first)
    #expect(controller.snapshot.canGoPrevious == false, "Previous returns to the first occurrence")
    #expect(controller.snapshot.playback == .paused)
    #expect(try await controller.execute(CommandRequest(command: .next), openSearch: {}).ok)
    #expect(controller.snapshot.canGoPrevious == true)
    await controller.search("unrelated")
    #expect(try await controller.execute(CommandRequest(command: .next), openSearch: {}).ok)
    #expect(controller.snapshot.loadedVideo?.video == last)
    #expect(controller.snapshot.error?.contains("Skipped 2") == true)
    #expect(controller.snapshot.canGoNext == false)
    try await controller.playPlaylist([items[0], items[3], items[4]])
    let deadline = ContinuousClock().now.advanced(by: .seconds(8))
    while !(controller.snapshot.loadedVideo?.video == last && controller.snapshot.playback == .ended),
          ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(20)) }
    #expect(controller.snapshot.loadedVideo?.video == last)
    #expect(controller.snapshot.playback == .ended)
    #expect(!engine.isPlaying)
    try await controller.playPlaylist([items[2], items[3]])
    #expect(!engine.isPlaying)
    #expect(controller.snapshot.error == "No playable videos remain in this direction.")
    await controller.shutdown()
}

@Test @MainActor func playlistPreparationCannotOverrideNewSelectionOrPause() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let audio = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: audio) }
    let slow = try VideoSummary(id: "01234567890", title: "Slow", creator: "Test")
    let chosen = try VideoSummary(id: "01234567891", title: "Chosen", creator: "Test")
    let engine = PlaybackEngine()
    var started = false
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { video, _ in
            if video.id == slow.id { started = true; try await Task.sleep(for: .milliseconds(200)) }
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video)
        })
    let item = YouTubePlaylistItem(id: "slow", video: slow, title: slow.title)
    let old = Task { try await controller.playPlaylist([item]) }
    while !started { await Task.yield() }
    try await controller.select(chosen)
    controller.pause()
    _ = try? await old.value
    #expect(controller.snapshot.loadedVideo?.video == chosen)
    #expect(controller.snapshot.canGoNext == false)
    started = false
    let pending = Task { try await controller.playPlaylist([item]) }
    while !started { await Task.yield() }
    controller.pause()
    _ = try? await pending.value
    #expect(!engine.isPlaying)
    #expect(controller.snapshot.loadedVideo?.video == slow)
    #expect(controller.snapshot.playback == .paused)
    engine.stop()
    started = false
    let same = Task { try await controller.playPlaylist([item]) }
    while !started { await Task.yield() }
    try await controller.select(slow)
    controller.pause()
    _ = try? await same.value
    #expect(controller.snapshot.loadedVideo?.video == slow)
    #expect(controller.snapshot.playback == .paused)
    await controller.shutdown()
}

@Test @MainActor func oauthLoopbackRejectsWrongStateAndAcceptsOnlyItsCallback() async throws {
    let callback = try OAuthCallback(state: "expected-state")
    let redirect = try await callback.start()
    defer { callback.cancel() }
    #expect(redirect.hasPrefix("http://127.0.0.1:"))
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 2
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    _ = try? await session.data(from: URL(string: redirect + "?state=wrong&code=bad")!)
    _ = try? await session.data(from: URL(string: redirect + "?state=expected-state&state=wrong&code=bad")!)
    let (_, response) = try await session.data(from: URL(string: redirect + "?state=expected-state&code=good")!)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect(try await callback.code() == "good")
    let cancelled = try OAuthCallback(state: "cancel-state")
    _ = try await cancelled.start()
    cancelled.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.code() }
}
