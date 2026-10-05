import Foundation
import Testing
@testable import MaroCore

@Test @MainActor func searchPagingGuardsConcurrentLoadsDeduplicatesAndRetriesPartialFailure() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let source = PagingFixture()
    let controller = try pagingController(file: file, source: source)
    await controller.search("fixture")
    #expect(controller.searchState.results.count == 25)
    #expect(controller.searchState.hasMore)
    let first = Task { await controller.loadMoreResults() }
    await pagingWait { await source.pending }
    await controller.loadMoreResults()
    #expect(await source.pageCalls == 1)
    #expect(controller.searchState.isLoadingMore)
    await source.finish()
    await first.value
    #expect(controller.searchState.results.count == 49) // One overlapping source item.
    #expect(Set(controller.searchState.results.map(\.id)).count == 49)
    await source.failNext()
    await controller.loadMoreResults()
    #expect(controller.searchState.loadMoreError != nil)
    #expect(controller.searchState.results.count == 49)
    let beforeRetry = await source.pageCalls
    await controller.loadMoreResults()
    #expect(await source.pageCalls == beforeRetry, "An error must not cause automatic retries")
    await controller.loadMoreResults(retry: true)
    #expect(controller.searchState.results.count == 74)
    #expect(controller.searchState.loadMoreError == nil)
    #expect(!controller.searchState.hasMore)
    await controller.shutdown()
}

@Test @MainActor func staleContinuationCannotAppendToNewQueryAndRepeatedPageStops() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let source = PagingFixture()
    let controller = try pagingController(file: file, source: source)
    await controller.search("old")
    let oldPage = Task { await controller.loadMoreResults() }
    await pagingWait { await source.pending }
    let newSearch = Task { await controller.search("new") }
    await pagingWait { controller.searchState.query == "new" }
    await source.finish()
    await oldPage.value; await newSearch.value
    #expect(controller.searchState.results.count == 25)
    #expect(controller.searchState.results.allSatisfy { $0.title.hasPrefix("new") })
    await source.repeatPage()
    await controller.loadMoreResults()
    #expect(controller.searchState.results.count == 25)
    #expect(!controller.searchState.hasMore)
    await controller.shutdown()
}

@MainActor private func pagingController(file: URL, source: PagingFixture) throws -> MaroController {
    try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] },
        searchPage: { query, cursor in try await source.page(query, cursor) },
        prepare: { _, _ in throw CancellationError() })
}

private actor PagingFixture {
    var pageCalls = 0
    var pending = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldHold = true
    private var shouldFail = false
    private var shouldRepeat = false
    func finish() { pending = false; continuation?.resume(); continuation = nil }
    func failNext() { shouldFail = true }
    func repeatPage() { shouldRepeat = true }
    func page(_ query: String, _ cursor: String?) async throws -> SearchPage {
        guard let cursor else { return SearchPage(videos: try videos(query, start: 0), continuation: "25") }
        pageCalls += 1
        if shouldHold { shouldHold = false; pending = true; await withCheckedContinuation { continuation = $0 } }
        if shouldFail { shouldFail = false; throw ExtractorFailure.network }
        if shouldRepeat { return SearchPage(videos: try videos(query, start: 0), continuation: cursor) }
        let offset = cursor == "25" ? 24 : 49
        return SearchPage(videos: try videos(query, start: offset), continuation: cursor == "25" ? "50" : nil)
    }
    private func videos(_ query: String, start: Int) throws -> [VideoSummary] {
        try (start..<start + 25).map { try VideoSummary(id: String(format: "%011d", $0), title: "\(query) \($0)", creator: "Fixture") }
    }
}

@MainActor private func pagingWait(_ condition: () async -> Bool) async {
    for _ in 0..<1_000 { if await condition() { return }; await Task.yield() }
    Issue.record("Paging fixture did not settle")
}
