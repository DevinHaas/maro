import AVFoundation
import Foundation
import Testing
@testable import MaroCore

private actor SearchCallProbe {
    var calls: [String: Int] = [:]
    func record(_ query: String) { calls[query, default: 0] += 1 }
    func count(_ query: String) -> Int { calls[query, default: 0] }
}

@Test @MainActor func searchCacheExpiresEvictsAndDoesNotCacheFailures() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let video = try track(1)
    let probe = SearchCallProbe()
    var now = ContinuousClock().now
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), searchNow: { now }, search: { query in
            await probe.record(query)
            if query == "failure" { throw SourceFailure.malformedResponse }
            return [video]
        }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    await controller.search("  first \n")
    await controller.search("first")
    #expect(await probe.count("first") == 1)
    now = now.advanced(by: .seconds(60))
    await controller.search("first")
    #expect(await probe.count("first") == 2)
    for index in 0..<8 {
        now = now.advanced(by: .milliseconds(1))
        await controller.search("query\(index)")
    }
    await controller.search("first")
    #expect(await probe.count("first") == 3, "Oldest batch must be evicted at eight cached queries")
    for _ in 0..<2 { await controller.search("failure") }
    #expect(await probe.count("failure") == 2)
    #expect(controller.searchState.error != nil)
    await controller.shutdown()
}

@Test @MainActor func repeatedSearchReusesTheFullResultBatchAndResetsReveal() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let videos = try (0..<20).map(track)
    let probe = SearchCallProbe()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in
            await probe.record(query)
            return videos
        }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    await controller.search("fixture")
    controller.revealMoreResults()
    #expect(controller.searchState.results.count == 10)
    await controller.search("fixture")
    #expect(await probe.count("fixture") == 1, "A repeated search should reuse its fresh metadata batch")
    #expect(controller.searchState.results.count == 5)
    while controller.searchState.hasMore { controller.revealMoreResults() }
    #expect(controller.searchState.results == videos)
    await controller.shutdown()
}

@Test @MainActor func concurrentIdenticalSearchesShareCompletedResults() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let videos = [try track(1)]
    let probe = SearchCallProbe()
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in
            await probe.record(query)
            try await Task.sleep(for: .milliseconds(30))
            return videos
        }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    let first = Task { await controller.search("same") }
    while !controller.searchState.isSearching { await Task.yield() }
    await controller.search("same")
    #expect(controller.searchState.results == videos)
    #expect(!controller.searchState.isSearching)
    #expect(await probe.count("same") == 1)
    await first.value
    await controller.shutdown()
}

@Test @MainActor func repeatedResumeAndReselectionReuseTheLoadedPlayer() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [video] }, prepare: { requested, position in
            preparations += 1
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    try await controller.select(video)
    controller.pause()
    let identity = engine.playbackID
    for _ in 0..<20 {
        let position = engine.positionSeconds
        try await controller.resume()
        controller.pause()
        #expect(engine.playbackID == identity)
        #expect(engine.positionSeconds >= position - 0.05)
        #expect(controller.snapshot.playback == .paused)
    }
    #expect(preparations == 1)
    try await controller.select(video)
    controller.pause()
    #expect(preparations == 1, "Reselecting a healthy loaded video must not resolve/prepare it again")
    #expect(engine.playbackID == identity)
    #expect(engine.positionSeconds < 0.1, "Explicit reselection still restarts the track")
    let reselection = Task { try await controller.select(video) }
    while !controller.snapshot.isSelecting { await Task.yield() }
    controller.pause()
    try await reselection.value
    #expect(controller.snapshot.playback == .paused)
    #expect(preparations == 1)
    engine.stop() // A lost item must be rebuilt rather than treated as a cache hit.
    try await controller.resume()
    controller.pause()
    #expect(preparations == 2)
    await controller.shutdown()
}

@Test @MainActor func duplicateSelectionsSharePreparationAndItsOutcome() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [video] }, prepare: { requested, position in
            preparations += 1
            try await Task.sleep(for: .milliseconds(100))
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    await controller.search("fixture")
    let first = Task { try await controller.select(video) }
    while preparations == 0 { await Task.yield() }
    let duplicate = try await controller.execute(CommandRequest(command: .select, videoID: video.id), openSearch: {})
    try await first.value
    #expect(duplicate.ok)
    #expect(preparations == 1)
    #expect(controller.snapshot.loadedVideo?.video.id == video.id)
    controller.pause()
    await controller.shutdown()
}

@Test @MainActor func timelineSeeksKeepLatestTargetPauseAndSavedPosition() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    let store = StateStore(file: file)
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: store, engine: engine, search: { _ in [] }, prepare: { requested, position in
            preparations += 1
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    #expect(controller.snapshot.timeline == nil)
    try await controller.select(video)
    controller.pause()
    let identity = try #require(controller.snapshot.playbackID)
    let timelineID = try #require(controller.snapshot.timelineID)
    let deadline = ContinuousClock().now.advanced(by: .seconds(3))
    while controller.snapshot.timeline == nil, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    _ = try #require(controller.snapshot.timeline)
    controller.seek(to: 0.2, timelineID: timelineID)
    await Task.yield()
    controller.seek(to: 0.4, timelineID: timelineID)
    controller.seek(to: 0.7, timelineID: timelineID)
    #expect(controller.snapshot.seekTarget == 0.7)
    controller.pause()
    while abs((controller.snapshot.loadedVideo?.positionSeconds ?? 0) - 0.7) > 0.05,
          ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(abs(engine.positionSeconds - 0.7) < 0.05)
    #expect(controller.snapshot.playback == .paused)
    #expect(!engine.isPlaying)
    #expect(engine.playbackID == identity)
    #expect(preparations == 1)
    controller.seek(to: 0.1, timelineID: UUID())
    await controller.flush()
    #expect(abs((try await store.load().document.loadedVideo?.positionSeconds ?? 0) - 0.7) < 0.05)
    await controller.shutdown()
}

@Test(.serialized, arguments: ["failure", "replacement", "shutdown"])
@MainActor func timelineCancellationDoesNotApplyLateState(_ scenario: String) async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    let replacement = try track(2)
    let store = StateStore(file: file)
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: store, engine: engine, search: { _ in [] }, prepare: { requested, position in
            preparations += 1
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    try await controller.select(video)
    controller.pause()
    let oldPlayer = try #require(engine.playbackID)
    controller.seek(to: 0.8, timelineID: try #require(controller.snapshot.timelineID))
    await Task.yield()
    #expect(controller.snapshot.seekTarget == 0.8)
    switch scenario {
    case "failure":
        engine.receive(.failed(domain: "fixture", code: 1), playbackID: oldPlayer)
        #expect(controller.snapshot.error == "Could not seek to that position. Try again.")
        #expect(controller.snapshot.playback == .paused)
        #expect(engine.hasItem)
        #expect(preparations == 1, "Seek failure must not start extraction/recovery")
    case "replacement":
        try await controller.select(replacement)
        controller.pause()
        engine.receive(.position(0.8), playbackID: oldPlayer)
        engine.receive(.ended, playbackID: oldPlayer)
        #expect(controller.snapshot.loadedVideo?.video == replacement)
        #expect(controller.snapshot.loadedVideo?.positionSeconds ?? 1 < 0.2)
        #expect(controller.snapshot.error == nil)
    default:
        await controller.shutdown()
        #expect(!engine.hasItem)
    }
    try await Task.sleep(for: .milliseconds(60))
    #expect(controller.snapshot.seekTarget == nil)
    #expect(controller.snapshot.playback == .paused)
    #expect(!engine.isPlaying)
    await controller.flush()
    #expect(try await store.load().document.loadedVideo == controller.snapshot.loadedVideo)
    await controller.shutdown()
}

private func controllerStateFile() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent("state.json")
}

private func track(_ id: Int) throws -> VideoSummary {
    try VideoSummary(id: String(format: "%011d", id), title: "Silent \(id)", creator: "Test")
}

@Test @MainActor func searchNavigationPreservesPauseAndBoundsAndFailedTrack() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let videos = try (1...7).map(track)
    let session = try SearchSession(query: "results", results: videos)
    #expect(session.neighbor(of: videos[0].id, offset: -1) == nil)
    #expect(session.neighbor(of: videos[6].id, offset: 1) == nil)
    #expect(session.neighbor(of: videos[0].id, offset: 2) == nil)
    let controller = try MaroController(loaded: StateLoadResult(
        document: StateDocument(loadedVideo: try LoadedVideo(video: videos[0], positionSeconds: 0)),
        preservedFile: nil, warning: nil), store: StateStore(file: file), engine: engine,
        search: { query in query == "empty" ? [] : videos }, prepare: { video, position in
            if video == videos[6] { throw SourceFailure.noCompatibleAudio }
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video, positionSeconds: position)
        })
    #expect(controller.snapshot.canGoNext == false)
    await controller.search("results")
    #expect(controller.snapshot.canGoPrevious == false)
    #expect(controller.snapshot.canGoNext == true)
    let first = try await controller.execute(CommandRequest(command: .previous), openSearch: {})
    #expect(!first.ok)
    for index in 1...5 {
        let response = try await controller.execute(CommandRequest(command: .next), openSearch: {})
        #expect(response.ok)
        #expect(controller.snapshot.loadedVideo?.video == videos[index])
        #expect(controller.snapshot.playback == .paused)
        #expect(!engine.isPlaying)
    }
    // Navigation includes fetched results beyond the five currently revealed rows.
    #expect(controller.searchState.results.count == 5)
    let failed = try await controller.execute(CommandRequest(command: .next), openSearch: {})
    #expect(!failed.ok)
    #expect(controller.snapshot.loadedVideo?.video == videos[5])
    #expect(controller.snapshot.playback == .paused)
    let previous = try await controller.execute(CommandRequest(command: .previous), openSearch: {})
    #expect(previous.ok)
    #expect(controller.snapshot.loadedVideo?.video == videos[4])
    try await controller.resume()
    let playingNext = try await controller.execute(CommandRequest(command: .next), openSearch: {})
    #expect(playingNext.ok)
    #expect(controller.snapshot.playback == .buffering || controller.snapshot.playback == .playing)
    controller.pause()
    await controller.search("empty")
    #expect(controller.snapshot.canGoPrevious == false)
    #expect(controller.snapshot.canGoNext == false)
    await controller.shutdown()
}

@Test @MainActor func controllerRestoresPausedAndPersistsFavoritesAndPosition() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let store = StateStore(file: file)
    let video = try track(1)
    let document = StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 0.25))
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: store, engine: engine, search: { _ in [] }, prepare: { video, position in
            preparations += 1
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video, positionSeconds: position)
        })
    #expect(controller.snapshot.playback == .paused)
    #expect(!engine.hasItem)
    #expect(preparations == 0)
    try controller.toggleFavorite(video)
    try await controller.resume()
    controller.pause()
    await controller.flush()
    #expect(preparations == 1)
    #expect(controller.snapshot.playback == .paused)
    let saved = try await store.load().document
    #expect(saved.favorites == [video])
    #expect(abs((saved.loadedVideo?.positionSeconds ?? 0) - 0.25) < 0.1)
}

@Test @MainActor func failedSelectionPreservesPausedVideoAndFavorites() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try track(1)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, _ in
            guard requested.id == video.id else { throw SourceFailure.noCompatibleAudio }
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested)
        })
    try await controller.select(video)
    controller.pause()
    try controller.toggleFavorite(video)
    do { try await controller.select(track(2)); Issue.record("Expected failed selection") }
    catch { #expect(error as? SourceFailure == .noCompatibleAudio) }
    #expect(controller.snapshot.loadedVideo?.video == video)
    #expect(controller.snapshot.playback == .paused)
    #expect(controller.snapshot.favorites == [video])
    #expect(controller.snapshot.error != nil)
    await controller.flush()
}

@Test @MainActor func staleSearchCannotReplaceNewerResults() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let first = try track(1), second = try track(2)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { query in
            if query == "slow" { try? await Task.sleep(for: .milliseconds(100)); return [first] }
            return [second]
        }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    let old = Task { await controller.search("slow") }
    while controller.searchState.query != "slow" { await Task.yield() }
    await controller.search("new")
    await old.value
    #expect(controller.searchState.results == [second])
    #expect(controller.searchState.query == "new")
    #expect(!controller.searchState.isSearching)
}

@Test(.serialized, arguments: 0..<20) @MainActor func pauseDuringPreparationWinsAndSupersededSelectionCannotCommit(_ iteration: Int) async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let first = try track(1), second = try track(2)
    var release: CheckedContinuation<Void, Never>?
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { video, _ in
            let prepared = try await engine.prepareAsset(AVURLAsset(url: audio), video: video)
            if video.id == first.id { await withCheckedContinuation { release = $0 } }
            return prepared
        })
    let old = Task { try await controller.select(first) }
    while release == nil { try await Task.sleep(for: .milliseconds(5)) }
    try await controller.select(second)
    controller.pause()
    release?.resume()
    do { try await old.value; Issue.record("Expected superseded selection") }
    catch { #expect(error as? PlaybackFailure == .superseded) }
    #expect(controller.snapshot.loadedVideo?.video == second)
    let pausedPosition = engine.positionSeconds
    #expect(controller.snapshot.playback == .paused)
    // Native observable values can lag commands; verify convergence and stability.
    let deadline = ContinuousClock().now.advanced(by: .milliseconds(250))
    while (engine.isPlaying || !engine.isMuted), ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!engine.isPlaying, "iteration \(iteration)")
    try await Task.sleep(for: .milliseconds(50))
    #expect(!engine.isPlaying)
    #expect(engine.isMuted)
    #expect(abs(engine.positionSeconds - pausedPosition) < 0.05)
    release = nil
    let pending = Task { try await controller.select(first) }
    while release == nil { try await Task.sleep(for: .milliseconds(5)) }
    controller.pause()
    release?.resume()
    try await pending.value
    #expect(controller.snapshot.loadedVideo?.video == first)
    #expect(controller.snapshot.playback == .paused)
    #expect(!engine.isPlaying)
    await controller.flush()
}

@Test @MainActor func persistenceFailureKeepsInMemoryFavoritesAndReportsError() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try Data("existing file".utf8).write(to: file)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file.appendingPathComponent("impossible.json")), engine: PlaybackEngine(),
        search: { _ in [] }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    try controller.toggleFavorite(track(1))
    await controller.flush()
    #expect(controller.snapshot.favorites.count == 1)
    #expect(controller.snapshot.persistenceError != nil)
    #expect(try Data(contentsOf: file) == Data("existing file".utf8))
}

private actor SourceAttempts {
    private(set) var count = 0
    func fail() throws -> [VideoSummary] {
        count += 1
        throw ExtractorFailure.sourceNeedsUpdate
    }
}

@Test(arguments: [AudioPreparationFailure.unsupportedCodec, .incompatible, .timedOut])
@MainActor func audioPreparationFailuresHaveDistinctSafeMessages(_ failure: AudioPreparationFailure) async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let video = try track(1)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(
        loadedVideo: try LoadedVideo(video: video, positionSeconds: 12)), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in throw failure })
    do { try await controller.select(video); Issue.record("Expected preparation failure") }
    catch { #expect(error as? AudioPreparationFailure == failure) }
    let message = try #require(controller.snapshot.error)
    switch failure {
    case .unsupportedCodec: #expect(message.contains("format"))
    case .incompatible: #expect(message.contains("native playback check"))
    case .timedOut: #expect(message.contains("timed out"))
    default: Issue.record("Unexpected fixture")
    }
    #expect(controller.snapshot.loadedVideo?.positionSeconds == 12)
    #expect(controller.snapshot.playback == .paused)
    await controller.shutdown()
}

@Test @MainActor func commandsUseAuthoritativeStateAndReturnCorrelatedErrors() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    var opened = 0
    var playerOpened = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [video] }, prepare: { requested, position in
            try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    func send(_ arguments: [String]) async throws -> CommandResponse {
        let response = try await controller.execute(CommandRequest.arguments(arguments, id: "command-42"),
            openSearch: { opened += 1 }, openPlayer: { playerOpened += 1 })
        return try CommandWire.response(CommandWire.encode(response), expectedID: "command-42")
    }
    #expect(try await send(["status"]).snapshot?.playback == .idle)
    #expect(try await send(["toggle"]).error?.code == .noLoadedVideo)
    #expect(try await send(["search"]).ok)
    #expect(opened == 1)
    #expect(try await send(["select", video.id]).error?.code == .videoUnavailable)
    await controller.search("fixture")
    #expect(try await send(["favorite", "toggle", video.id]).snapshot?.favorites == [video])
    #expect(try await send(["select", video.id]).snapshot?.loadedVideo?.video == video)
    #expect(try await send(["toggle"]).snapshot?.playback == .paused)
    let retained = controller.snapshot.loadedVideo
    #expect(try await send(["player"]).ok)
    #expect(try await send(["player"]).ok)
    #expect(playerOpened == 2)
    #expect(controller.snapshot.playback == .paused)
    #expect(controller.snapshot.loadedVideo == retained)
    #expect(try await send(["replay"]).error?.code == .invalidRequest)
    #expect(try await send(["toggle"]).ok)
    #expect(try await send(["toggle"]).snapshot?.playback == .paused)
    #expect(try await send(["favorite", "remove", video.id]).snapshot?.favorites.isEmpty == true)
    await controller.shutdown()
    #expect(try await send(["status"]).error?.code == .serviceUnavailable)
    #expect(try await send(["search"]).error?.code == .serviceUnavailable)
    #expect(try await send(["player"]).error?.code == .serviceUnavailable)
    #expect(playerOpened == 2)
    #expect(opened == 1)
}

@Test @MainActor func commandFavoriteCapacityAndSourceGateDoNotLoseSavedData() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let extra = try track(21)
    var document = StateDocument(loadedVideo: try LoadedVideo(video: extra, positionSeconds: 10))
    for id in 0..<20 { try document.toggleFavorite(track(id)) }
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), search: { _ in throw ExtractorFailure.sourceNeedsUpdate },
        prepare: { _, _ in throw ExtractorFailure.videoUnavailable })
    let full = try await controller.execute(CommandRequest(command: .favoriteToggle, videoID: extra.id), openSearch: {})
    #expect(full.error?.code == .favoritesFull)
    await controller.search("trigger source gate")
    let blocked = try await controller.execute(CommandRequest(command: .toggle), openSearch: {})
    #expect(blocked.error?.code == .sourceNeedsUpdate)
    let removed = try await controller.execute(CommandRequest(command: .favoriteRemove, videoID: track(0).id), openSearch: {})
    #expect(removed.ok)
    #expect(removed.snapshot?.favorites.count == 19)
    #expect(removed.snapshot?.loadedVideo?.positionSeconds == 10)
    await controller.shutdown()
}

@Test @MainActor func accessRecoveryIsBoundedAndPreservesPausedPosition() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    let document = StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 0.3))
    var positions: [Double] = []
    var release: CheckedContinuation<Void, Never>?
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, position in
            positions.append(position)
            let prepared = try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
            if positions.count == 2 { await withCheckedContinuation { release = $0 } }
            return prepared
        })
    try await controller.resume()
    let oldID = try #require(engine.playbackID)
    engine.receive(.accessRejected, playbackID: oldID)
    engine.receive(.accessRejected, playbackID: oldID)
    controller.pause()
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while release == nil, ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(release != nil)
    release?.resume()
    while controller.snapshot.isSelecting, ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!controller.snapshot.isSelecting)
    #expect(positions.count == 2)
    #expect(abs(positions[1] - 0.3) < 0.1)
    #expect(controller.snapshot.playback == .paused)
    #expect(!engine.isPlaying)
    engine.receive(.accessRejected, playbackID: try #require(engine.playbackID))
    #expect(!controller.snapshot.isSelecting)
    #expect(!engine.hasItem)
    #expect(controller.snapshot.error != nil)
    #expect(positions.count == 2)
    // An explicit retry starts a new attempt after the automatic budget is spent.
    try await controller.resume()
    #expect(positions.count == 3)
    await controller.shutdown()
}

@Test @MainActor func newerSelectionWinsOverRecoveryAndUnknownFailureDoesNotRetry() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    var count = 0
    var release: CheckedContinuation<Void, Never>?
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, position in
            count += 1
            let prepared = try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
            if count == 2 { await withCheckedContinuation { release = $0 } }
            return prepared
        })
    try await controller.select(track(1))
    engine.receive(.accessRejected, playbackID: try #require(engine.playbackID))
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while release == nil, ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(release != nil)
    try await controller.select(track(2))
    controller.pause()
    release?.resume()
    try await Task.sleep(for: .milliseconds(30))
    #expect(controller.snapshot.loadedVideo?.video == (try track(2)))
    #expect(!engine.isPlaying)
    engine.receive(.failed(domain: "decoder", code: 1), playbackID: try #require(engine.playbackID))
    #expect(count == 3)
    #expect(!engine.hasItem)
    #expect(controller.snapshot.error != nil)
    #expect(PlaybackObservation.failure(nil, httpStatus: 403) == .accessRejected)
    #expect(PlaybackObservation.failure(nil, httpStatus: 410) == .accessRejected)
    #expect(PlaybackObservation.failure(NSError(domain: "network", code: 1), httpStatus: 500)
        == .failed(domain: "network", code: 1))
    await controller.shutdown()
}

@Test @MainActor func failedAccessRefreshRetainsMetadataAndStopsRetrying() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    var count = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, _ in
            count += 1
            if count > 1 { throw ExtractorFailure.network }
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested)
        })
    try await controller.select(video)
    try controller.toggleFavorite(video)
    engine.receive(.accessRejected, playbackID: try #require(engine.playbackID))
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while controller.snapshot.isSelecting, ContinuousClock().now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!controller.snapshot.isSelecting)
    #expect(count == 2)
    #expect(controller.snapshot.loadedVideo?.video == video)
    #expect(controller.snapshot.favorites == [video])
    #expect(controller.snapshot.playback == .paused)
    #expect(controller.snapshot.error == ExtractorFailure.network.message)
    #expect(!engine.hasItem)
    await controller.shutdown()
}

@Test @MainActor func sourceUpdateStopsFurtherRequestsAndQueuedSavesKeepNewestFavorites() async throws {
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = StateStore(file: file)
    let attempts = SourceAttempts()
    let document = StateDocument(loadedVideo: try LoadedVideo(video: track(1), positionSeconds: 12))
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: store, engine: PlaybackEngine(), search: { _ in try await attempts.fail() },
        prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    for index in 0..<10 { try controller.toggleFavorite(track(index)) }
    await controller.search("first")
    await controller.search("again")
    #expect(await attempts.count == 1)
    #expect(controller.snapshot.sourceNeedsUpdate)
    #expect(controller.snapshot.loadedVideo?.positionSeconds == 12)
    #expect(!controller.searchState.isSearching)
    do { try await controller.resume(); Issue.record("Expected source-update gate") }
    catch { #expect(error as? ExtractorFailure == .sourceNeedsUpdate) }
    await controller.flush()
    let saved = try await store.load().document
    #expect(saved.favorites.count == 10)
    #expect(saved.favorites.first?.id == (try track(9)).id)
    #expect(saved.loadedVideo?.positionSeconds == 12)
    #expect(saved.sourceDisabledBuild != nil)
    let restored = try MaroController(loaded: await store.load(), store: store, engine: PlaybackEngine(),
        search: { _ in try await attempts.fail() }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    await restored.search("after relaunch")
    #expect(restored.snapshot.sourceNeedsUpdate)
    #expect(await attempts.count == 1)
    let updated = try MaroController(loaded: await store.load(), store: store, engine: PlaybackEngine(),
        sourceBuild: "compatible-next-build", search: { _ in [] }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    #expect(!updated.snapshot.sourceNeedsUpdate)
    await updated.search("explicit user request")
    #expect(updated.searchState.error == nil)
    await updated.flush()
    #expect(try await store.load().document.sourceDisabledBuild == nil)
}

@Test @MainActor func shutdownFlushesAndRejectsLateSelectionAndFurtherCommands() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let store = StateStore(file: file)
    let video = try track(1)
    let document = StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 12))
    var release: CheckedContinuation<Void, Never>?
    let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
        store: store, engine: engine, search: { _ in [] }, prepare: { requested, _ in
            let prepared = try await engine.prepareAsset(AVURLAsset(url: audio), video: requested)
            await withCheckedContinuation { release = $0 }
            return prepared
        })
    try controller.toggleFavorite(video)
    let pending = Task { try await controller.select(track(2)) }
    while release == nil { try await Task.sleep(for: .milliseconds(5)) }
    await controller.shutdown()
    await controller.shutdown()
    release?.resume()
    do { try await pending.value; Issue.record("Expected obsolete selection") }
    catch { #expect(error as? PlaybackFailure == .superseded) }
    #expect(!engine.hasItem)
    #expect(!controller.snapshot.isSelecting)
    #expect(controller.snapshot.playback == .paused)
    #expect(try await store.load().document.loadedVideo?.positionSeconds == 12)
    #expect(try await store.load().document.favorites == [video])
    do { try await controller.resume(); Issue.record("Expected shutdown rejection") }
    catch { #expect(error as? ControllerFailure == .shutDown) }
    #expect(throws: ControllerFailure.shutDown) { try controller.toggleFavorite(video) }
}

@Test @MainActor func controllerKeepsEndedTrackAndReplaysIt() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try track(1)
    let store = StateStore(file: file)
    var preparations = 0
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: store, engine: engine, search: { _ in [] }, prepare: { requested, position in
            preparations += 1
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    try await controller.select(video)
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while controller.snapshot.playback != .ended, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(controller.snapshot.playback == .ended)
    #expect(controller.snapshot.loadedVideo?.video == video)
    await controller.flush()
    #expect(try await store.load().document.loadedVideo?.positionSeconds ?? 0 > 0.9)
    try await controller.resume()
    #expect(preparations == 1)
    #expect(engine.positionSeconds < 0.1)
    #expect(engine.isPlaying)
    await controller.shutdown()
    #expect(!engine.hasItem)
    #expect(try await store.load().document.loadedVideo?.positionSeconds ?? 1 < 0.1)
}

@Test @MainActor func seekingBackwardFromEndedStaysPausedAndResumeKeepsTarget() async throws {
    let audio = try makeSilentAudio()
    let file = try controllerStateFile()
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let engine = PlaybackEngine()
    let video = try track(1)
    let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] }, prepare: { requested, position in
            try await engine.prepareAsset(AVURLAsset(url: audio), video: requested, positionSeconds: position)
        })
    try await controller.select(video)
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while controller.snapshot.playback != .ended, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(controller.snapshot.playback == .ended)
    let id = try #require(engine.playbackID)
    controller.seek(to: 0.4, timelineID: try #require(controller.snapshot.timelineID))
    while controller.snapshot.playback != .paused, ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(controller.snapshot.playback == .paused)
    #expect(abs(engine.positionSeconds - 0.4) < 0.05)
    try await controller.resume()
    controller.pause()
    #expect(engine.positionSeconds >= 0.35)
    #expect(engine.playbackID == id)
    await controller.shutdown()
}
