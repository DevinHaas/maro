import Foundation
import Testing
@testable import MaroCore

@Test @MainActor func metadataPreviewReusesSubmissionWithoutReplacingSubmittedResults() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let probe = MetadataProbe()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in
            await probe.record(query)
            return [try VideoSummary(id: query == "first" ? "aaaaaaaaaaa" : "bbbbbbbbbbb", title: query, creator: "Fixture")]
        }, prepare: { _, _ in throw CancellationError() })
    await controller.search("first")
    let preview = try await controller.metadataSearch("second", intent: .foreground)
    #expect(preview.first?.title == "second")
    #expect(controller.searchState.query == "first")
    #expect(controller.searchState.results.first?.title == "first")
    await controller.search("second")
    #expect(controller.searchState.results == preview)
    #expect(await probe.count("second") == 1)
    await controller.shutdown()
}

@Test @MainActor func foregroundYieldsDiscoveryAndDrainsCancelledProviderBeforeNextRequest() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let source = HeldMetadataSource()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in try await source.search(query) },
        prepare: { _, _ in throw CancellationError() })
    let discovery = Task { try await controller.metadataSearch("background", intent: .discovery) }
    await metadataWait { await source.calls.contains("background") }
    let foreground = Task { try await controller.metadataSearch("foreground", intent: .foreground) }
    await metadataWait { controller.hasForegroundMetadataRequest }
    do { _ = try await controller.metadataSearch("blocked", intent: .discovery); Issue.record("Discovery must yield") }
    catch { #expect(error is CancellationError) }
    #expect(await source.calls == ["background"])
    await source.complete("background") // Provider intentionally ignores cancellation until its reply arrives.
    do { _ = try await discovery.value; Issue.record("Superseded discovery must not return late matches") }
    catch { #expect(error is CancellationError) }
    await metadataWait { await source.calls.contains("foreground") }
    let submitted = Task { await controller.search("foreground") }
    await metadataWait { controller.searchState.isSearching }
    await source.complete("foreground")
    let videos = try await foreground.value
    await submitted.value
    #expect(controller.searchState.results == videos)
    #expect(await source.calls == ["background", "foreground"])
    #expect(await source.maximumActive == 1)
    #expect(!controller.hasForegroundMetadataRequest)
    await controller.shutdown()
}

private actor HeldMetadataSource {
    var calls: [String] = []
    var active = 0
    var maximumActive = 0
    var waiting: [String: CheckedContinuation<Void, Never>] = [:]
    func search(_ query: String) async throws -> [VideoSummary] {
        calls.append(query); active += 1; maximumActive = max(maximumActive, active)
        await withCheckedContinuation { waiting[query] = $0 }
        active -= 1
        return [try VideoSummary(id: "aaaaaaaaaaa", title: query, creator: "Fixture")]
    }
    func complete(_ query: String) { waiting.removeValue(forKey: query)?.resume() }
}
@MainActor private func metadataWait(_ condition: () async -> Bool) async {
    for _ in 0..<500 { if await condition() { return }; await Task.yield() }
    Issue.record("Observable metadata state did not settle")
}

private actor MetadataProbe {
    var calls: [String] = []
    func record(_ query: String) { calls.append(query) }
    func count(_ query: String) -> Int { calls.filter { $0 == query }.count }
}
