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
    now: @escaping () -> Date = Date.init) throws -> (ApplicationModel, URL) {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let controller = try MaroController(loaded: StateLoadResult(document: state, preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { try await source.search($0) },
        prepare: { _, _ in throw CancellationError() })
    let library = PlaylistLibrary(controller: controller, api: YouTubePlaylists(token: { "fixture" },
        send: { _ in Issue.record("Home must not load playlist contents for personalization"); throw CancellationError() }))
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
