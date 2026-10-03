import Foundation
import Testing
@testable import MaroCore
@testable import MaroApp

@Test @MainActor func emptyFocusUsesKnownVideosAndLocalSuggestionsWithoutNetwork() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "aaaaaaaaaaa", title: "Piano live", creator: "Fixture")
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in Issue.record("Empty focus must not search"); return [] },
        prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { throw CancellationError() }))
    let app = ApplicationModel(controller: controller, library: library)
    app.setSearchSeeds(videos: [video], queries: ["piano live", "jazz", "ambient", "classical", "fifth"])
    app.focusSearch()
    #expect(app.previewOpen)
    #expect(app.previewVideos == [video])
    #expect(app.previewQueries.count == 4)
    app.libraryFilter = "local only"
    app.submitSearch(" \n ")
    #expect(app.route == .home)
    app.dismissPreview()
    #expect(!app.previewOpen)
    #expect(app.searchFocused)
    await controller.shutdown()
}

@Test @MainActor func previewDebouncesDraftAndPreservesFullResultsUntilFieldSubmission() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let probe = PreviewSource()
    let clock = PreviewClock()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in try await probe.search(query) },
        prepare: { _, _ in throw CancellationError() })
    let app = ApplicationModel(controller: controller,
        library: PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { throw CancellationError() })),
        previewDelay: { duration in await clock.wait(duration) })
    app.submitSearch("original")
    await waitUntil { app.searchState.results.count == 5 }
    app.revealMore()
    app.focusSearch()
    app.globalQuery = "draft"
    await waitUntil { await clock.count() >= 2 }
    #expect(await probe.count("draft") == 0)
    #expect(await clock.lastDuration() == .milliseconds(300))
    #expect(app.searchState.query == "original")
    #expect(app.searchState.results.count == 10)
    await clock.advance()
    await waitUntil { !app.previewLoading }
    #expect(app.previewVideos.first?.title == "draft 0")
    #expect(app.searchState.query == "original")
    app.movePreviewFocus(1)
    app.submitSearch() // Field Enter submits draft regardless of highlighted row.
    await waitUntil { app.searchState.query == "draft" && !app.searchState.isSearching }
    #expect(app.route == .search)
    #expect(app.searchState.results.count == 5)
    #expect(await probe.count("draft") == 1)
    #expect(app.libraryFilter.isEmpty)
    await controller.shutdown()
}

@Test @MainActor func failedDraftCannotMasqueradeAsMatchesAndRetryReusesFullBoundedBatch() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let probe = RetryPreviewSource()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in try await probe.search(query) },
        prepare: { _, _ in throw CancellationError() })
    let app = ApplicationModel(controller: controller,
        library: PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { throw CancellationError() })), previewDelay: { _ in })
    app.submitSearch("saved page")
    await waitUntil { app.searchState.results.count == 5 }
    app.focusSearch(); app.globalQuery = "broken"
    await waitUntil { app.previewError != nil }
    #expect(app.previewVideos.isEmpty)
    #expect(app.searchState.query == "saved page")
    #expect(app.searchState.results.first?.title == "saved page 0")
    await probe.allowRetry()
    app.retryPreview()
    await waitUntil { !app.previewLoading }
    #expect(app.previewError == nil)
    #expect(app.previewVideos.first?.title == "broken 0")
    app.submitSearch()
    await waitUntil { app.searchState.query == "broken" && !app.searchState.isSearching }
    while app.searchState.hasMore { app.revealMore() }
    #expect(app.searchState.results.count == 20)
    #expect(await probe.count("broken") == 2)
    await controller.shutdown()
}

@Test @MainActor func supersededPreviewDiscardsLateReplyAndFocusedQuerySubmitsItsOwnText() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let probe = LatePreviewSource()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in try await probe.search(query) },
        prepare: { _, _ in throw CancellationError() })
    let app = ApplicationModel(controller: controller,
        library: PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { throw CancellationError() })), previewDelay: { _ in })
    app.focusSearch(); app.globalQuery = "old"
    await waitUntil { await probe.hasPending("old") }
    app.globalQuery = "new"
    await probe.complete("old")
    await waitUntil { await probe.hasPending("new") }
    #expect(app.previewVideos.isEmpty)
    #expect(app.previewLoading)
    await probe.complete("new")
    await waitUntil { !app.previewLoading }
    #expect(app.previewVideos.first?.title == "new")
    app.globalQuery = ""
    app.setSearchSeeds(videos: [], queries: ["a focused suggestion"])
    app.movePreviewFocus(1)
    app.activateFocusedPreview()
    await waitUntil { app.searchState.query == "a focused suggestion" && !app.searchState.isSearching }
    #expect(app.globalQuery == "a focused suggestion")
    #expect(app.route == .search)
    #expect(!app.previewOpen)
    await controller.shutdown()
}

private actor LatePreviewSource {
    var pending: [String: CheckedContinuation<Void, Never>] = [:]
    func hasPending(_ query: String) -> Bool { pending[query] != nil }
    func complete(_ query: String) { pending.removeValue(forKey: query)?.resume() }
    func search(_ query: String) async throws -> [VideoSummary] {
        if query == "old" || query == "new" { await withCheckedContinuation { pending[query] = $0 } }
        return [try VideoSummary(id: "aaaaaaaaaaa", title: query, creator: "Fixture")]
    }
}

private actor RetryPreviewSource {
    var failing = true
    var calls: [String] = []
    func allowRetry() { failing = false }
    func count(_ query: String) -> Int { calls.filter { $0 == query }.count }
    func search(_ query: String) throws -> [VideoSummary] {
        calls.append(query)
        if query == "broken" && failing { throw SourceFailure.malformedResponse }
        return try (0..<24).map { try VideoSummary(id: String(format: "%011d", $0), title: "\(query) \($0)", creator: "Fixture") }
    }
}

private actor PreviewClock {
    var waits: [CheckedContinuation<Void, Never>] = []
    var durations: [Duration] = []
    func wait(_ duration: Duration) async {
        durations.append(duration)
        await withCheckedContinuation { waits.append($0) }
    }
    func count() -> Int { durations.count }
    func lastDuration() -> Duration? { durations.last }
    func advance() { let pending = waits; waits = []; pending.forEach { $0.resume() } }
}
private actor PreviewSource {
    var calls: [String] = []
    func search(_ query: String) throws -> [VideoSummary] {
        calls.append(query)
        return try (0..<12).map { try VideoSummary(id: String(format: "%011d", $0), title: "\(query) \($0)", creator: "Fixture") }
    }
    func count(_ query: String) -> Int { calls.filter { $0 == query }.count }
}
@MainActor private func waitUntil(_ condition: () async -> Bool) async {
    for _ in 0..<500 {
        if await condition() { return }
        await Task.yield()
    }
    Issue.record("Observable search state did not settle")
}
