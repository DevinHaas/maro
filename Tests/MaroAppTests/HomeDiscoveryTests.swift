import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

private actor HomeSourceFixture {
    var queries: [String] = []
    var fail = false
    let responses: [String: [VideoSummary]]
    init(_ responses: [String: [VideoSummary]] = [:]) { self.responses = responses }
    func search(_ query: String) throws -> [VideoSummary] {
        queries.append(query)
        if fail { throw URLError(.notConnectedToInternet) }
        return responses[query] ?? []
    }
    func setFailure(_ value: Bool) { fail = value }
}

@MainActor private func homeFixture(_ source: HomeSourceFixture, state: StateDocument = StateDocument(),
    playlists: [YouTubePlaylist] = [], now: @escaping () -> Date = Date.init) throws -> (ApplicationModel, URL) {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let recommendationEpoch = now(), searchEpoch = ContinuousClock().now
    let controller = try MaroController(loaded: StateLoadResult(document: state, preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(),
        searchNow: { searchEpoch.advanced(by: .seconds(now().timeIntervalSince(recommendationEpoch))) },
        search: { try await source.search($0) },
        prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" },
        send: { _ in Issue.record("Home must not load playlist contents for personalization"); throw CancellationError() }))
    library.playlists = playlists
    return (ApplicationModel(controller: controller, library: library, recommendationNow: now), file)
}

@MainActor private func waitForHome(_ app: ApplicationModel) async {
    for _ in 0..<5_000 {
        if !app.home.isLoading { return }
        await Task.yield()
    }
    Issue.record("Home discovery did not finish")
}

@Test @MainActor func homeColdStartUsesThreeBoundedGeneralSuggestionsAndNoPlaylistFetches() async throws {
    let source = HomeSourceFixture()
    let (app, file) = try homeFixture(source)
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    #expect(await source.queries == ["jazz", "lofi focus", "electronic"])
    #expect(app.home.sections.map(\.title) == ["Jazz", "Lofi & focus", "Electronic"])
    #expect(app.home.sections.allSatisfy { $0.reason == "General suggestions" && $0.videos.isEmpty })
    app.showFavorites(); app.showHome(); app.render(); app.render()
    await Task.yield()
    #expect(await source.queries.count == 3)
    await app.controller.shutdown()
}

private actor HomePrioritySource {
    var queries: [String] = []
    var interrupted = false
    func search(_ query: String) async throws -> [VideoSummary] {
        queries.append(query)
        if query == "jazz", !interrupted {
            interrupted = true
            try await Task.sleep(for: .seconds(30))
        }
        return []
    }
}

@Test @MainActor func homeYieldsToForegroundWithoutExceedingThreeAutomaticAttempts() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let source = HomePrioritySource()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { try await source.search($0) },
        prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { _ in throw CancellationError() }))
    let app = ApplicationModel(controller: controller, library: library)
    while await source.queries.isEmpty { await Task.yield() }
    app.submitSearch("wanted")
    for _ in 0..<5_000 {
        if app.searchState.query == "wanted", !app.searchState.isSearching { break }
        await Task.yield()
    }
    app.render()
    await waitForHome(app)
    let queries = await source.queries
    #expect(queries == ["jazz", "wanted", "lofi focus", "electronic"])
    #expect(app.home.error == nil)
    await controller.shutdown()
}

private func homeVideo(_ number: Int, _ title: String, creator: String) throws -> VideoSummary {
    try VideoSummary(id: String(format: "v%010d", number), title: title, creator: creator)
}

@Test @MainActor func homeRanksRealSeedsNormalizesNamesAndReranksSavedVideosWithoutRefetching() async throws {
    let favorite = try homeVideo(0, "JÁZZ classics", creator: "Café Trio")
    var state = StateDocument(); try state.toggleFavorite(favorite)
    let preferred = try homeVideo(2, "Jazz session", creator: "Cafe Trio")
    let second = try homeVideo(4, "Jazz session", creator: "Café Trio")
    var candidates = [favorite, try homeVideo(1, "Ambient session", creator: "Other"), preferred,
        try homeVideo(3, "Jazz piano", creator: "Café Trio Extended"), second,
        try homeVideo(5, "Jazz groove", creator: "Café Trio")]
    candidates += try (6..<28).map { try homeVideo($0, "Jazz session", creator: "Creator \($0)") }
    let source = HomeSourceFixture(["jazz": candidates, "Café Trio": candidates])
    let (app, file) = try homeFixture(source, state: state)
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    let first = try #require(app.home.sections.first)
    #expect(first.reason == "Because you saved jazz videos")
    #expect(first.videos.prefix(2).map(\.id) == [preferred.id, second.id])
    #expect(first.videos.count == 8)
    let all = app.home.sections.flatMap(\.videos)
    #expect(Set(all.map(\.id)).count == all.count)
    #expect(!all.contains { $0.id == favorite.id || $0.id == "v0000000027" })
    for section in app.home.sections {
        let cafeCount = section.videos.filter { ["Cafe Trio", "Café Trio"].contains($0.creator) }.count
        #expect(cafeCount <= 2)
    }
    app.toggleFavorite(preferred)
    #expect(app.home.sections.first?.videos.first?.id == second.id)
    #expect(!app.home.isLoading)
    await Task.yield()
    #expect(await source.queries.count == 2)
    await app.controller.shutdown()
}

@MainActor private final class HomeClock {
    var date = Date(timeIntervalSince1970: 1_000)
    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
}

@Test @MainActor func homeKeepsThirtyMinuteMetadataAndRecoversWithHonestOfflineCards() async throws {
    let saved = try homeVideo(100, "Jazz", creator: "Solo")
    let discovered = try homeVideo(101, "Jazz piano", creator: "Another creator")
    var state = StateDocument(); try state.toggleFavorite(saved)
    let source = HomeSourceFixture(["jazz": [discovered]])
    let clock = HomeClock()
    let (app, file) = try homeFixture(source, state: state, now: { clock.date })
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    clock.advance(1_799); app.home.retry(); await waitForHome(app)
    #expect(await source.queries.count == 2)
    await source.setFailure(true)
    clock.advance(2); app.home.retry(); await waitForHome(app)
    #expect(app.home.sections.first?.videos.map(\.id) == [discovered.id])
    #expect(app.home.sections.first?.isOutdated == true)
    #expect(app.home.error != nil)
    app.showFavorites(); #expect(app.route == .favorites)
    await source.setFailure(false)
    app.home.retry(); await waitForHome(app)
    #expect(app.home.sections.first?.isOutdated == false)
    #expect(app.home.error == nil)
    #expect(await source.queries.count == 6)
    await app.controller.shutdown()
}

@Test @MainActor func homeCacheIsLimitedToTwelveQueriesAndTouchesReusedMetadata() async throws {
    let first = try homeVideo(200, "Unrelated", creator: "Artist 0")
    var state = StateDocument(); try state.toggleFavorite(first)
    let source = HomeSourceFixture()
    let (app, file) = try homeFixture(source, state: state)
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    var active = first
    for number in 1..<14 {
        let next = try homeVideo(200 + number, "Unrelated", creator: "Artist \(number)")
        app.controller.removeFavorite(id: active.id); try app.controller.toggleFavorite(next); app.render()
        active = next; await waitForHome(app)
    }
    #expect(await source.queries.count == 14)
    let retained = try homeVideo(202, "Unrelated", creator: "Artist 2")
    app.controller.removeFavorite(id: active.id); try app.controller.toggleFavorite(retained); app.render()
    await waitForHome(app)
    #expect(await source.queries.count == 14)
    app.controller.removeFavorite(id: retained.id); try app.controller.toggleFavorite(first); app.render()
    await waitForHome(app)
    #expect(await source.queries.count == 15)
    await app.controller.shutdown()
}

@Test @MainActor func homeKeywordSeedsMatchExplicitPhrasesWithoutSubstringFalsePositives() async throws {
    let source = HomeSourceFixture()
    let (app, file) = try homeFixture(source, playlists: [YouTubePlaylist(id: "PLphrase", title: "Café Lo-Fi JÁZZBerry", count: 0)])
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    #expect(app.home.suggestedQueries == ["lofi focus"])
    #expect(app.home.sections.first?.reason == "Based on your lofi & focus playlists")
    #expect(await source.queries == ["lofi focus"])
    await app.controller.shutdown()
}

private actor HomeLoadedPlaylistFixture {
    var requests = 0
    func response(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests += 1
        let url = request.url!
        let body: [String: Any]
        if url.path.hasSuffix("/playlists") {
            body = ["items": (1...3).map { ["id": "PLjazz\($0)", "snippet": ["title": "Jazz"], "contentDetails": ["itemCount": 50]] }]
        } else {
            body = ["items": (1...50).map { ["id": "occurrence-\($0)", "snippet": ["title": "Ambient", "videoOwnerChannelTitle": "Ambient Creator", "resourceId": ["videoId": "v0000000300"]]] }]
        }
        return (try JSONSerialization.data(withJSONObject: body), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func homeCountsRepeatedLoadedVideosOnceAndUsesOnlyAlreadyLoadedEvidence() async throws {
    let source = HomeSourceFixture(), playlistSource = HomeLoadedPlaylistFixture()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { try await source.search($0) }, prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { try await playlistSource.response($0) }))
    library.open(YouTubePlaylist(id: "PLjazz1", title: "Jazz", count: 50))
    while library.busy { await Task.yield() }
    let app = ApplicationModel(controller: controller, library: library)
    await waitForHome(app)
    #expect(app.home.suggestedQueries == ["jazz", "ambient", "Ambient Creator"])
    #expect(app.home.sections.first?.reason == "Based on your jazz playlists")
    #expect(await playlistSource.requests == 2)
    #expect(await source.queries.count == 3)
    library.disconnect(); app.render(); await waitForHome(app)
    #expect(app.home.suggestedQueries == ["jazz", "lofi focus", "electronic"])
    #expect(app.home.sections.allSatisfy { $0.reason == "General suggestions" })
    #expect(library.loadedItemsByPlaylist.isEmpty)
    await controller.shutdown()
}

private actor HomeAccountSource {
    var started = false
    var pending: CheckedContinuation<[VideoSummary], Error>?
    func search(_ query: String) async throws -> [VideoSummary] {
        if query == "ambient" {
            started = true
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        return []
    }
    func release(_ videos: [VideoSummary]) { pending?.resume(returning: videos); pending = nil }
}

@Test @MainActor func homeDisconnectClearsAccountSeedsAndRejectsLateAccountResponses() async throws {
    let source = HomeAccountSource()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let oldVideo = try homeVideo(400, "Ambient private seed", creator: "Old account creator")
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { try await source.search($0) }, prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" }, send: { _ in throw CancellationError() }))
    library.playlists = [YouTubePlaylist(id: "PLaccount", title: "Ambient", count: 1)]
    let app = ApplicationModel(controller: controller, library: library)
    while !(await source.started) { await Task.yield() }
    library.disconnect(); app.render()
    #expect(app.home.suggestedQueries == ["jazz", "lofi focus", "electronic"])
    #expect(app.home.sections.allSatisfy { $0.reason == "General suggestions" && $0.videos.isEmpty })
    await source.release([oldVideo])
    await waitForHome(app)
    #expect(app.home.sections.allSatisfy { $0.videos.isEmpty })
    #expect(app.home.error == nil)
    await controller.shutdown()
}

@Test @MainActor func homeFailureWithoutCachedCandidatesKeepsLibraryAndShowsNoInventedCards() async throws {
    let source = HomeSourceFixture(); await source.setFailure(true)
    let playlist = YouTubePlaylist(id: "PLoffline", title: "Jazz", count: 3)
    let (app, file) = try homeFixture(source, playlists: [playlist])
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    #expect(app.home.error != nil)
    #expect(app.home.sections.allSatisfy { $0.videos.isEmpty })
    #expect(app.library.playlists == [playlist])
    app.showFavorites(); #expect(app.route == .favorites)
    await app.controller.shutdown()
}

@Test @MainActor func savingDiscoveryReportsFavoritesCapacityWithoutStartingPlayback() async throws {
    var state = StateDocument()
    for number in 500..<520 { try state.toggleFavorite(homeVideo(number, "Jazz", creator: "Creator \(number)")) }
    let (app, file) = try homeFixture(HomeSourceFixture(), state: state)
    defer { try? FileManager.default.removeItem(at: file) }
    await waitForHome(app)
    let video = try homeVideo(520, "Jazz discovery", creator: "Another creator")
    app.toggleFavorite(video)
    #expect(app.actionError == "Favorites are full. Remove one before adding another.")
    #expect(app.controller.snapshot.favorites.count == 20)
    #expect(!app.controller.snapshot.favorites.contains(video))
    #expect(app.controller.snapshot.loadedVideo == nil)
    await app.controller.shutdown()
}
