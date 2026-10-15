import AVFoundation
import Foundation
import Testing
@testable import MaroCore

private func warmTrack(_ id: Int) throws -> VideoSummary {
    try VideoSummary(id: String(format: "w%010d", id), title: "Warm \(id)", creator: "Test")
}

private func resolved(_ video: VideoSummary, urls: [String]) -> ResolvedAudio {
    ResolvedAudio(video: video, candidates: urls.map {
        AudioCandidate(url: URL(string: $0)!, audioCodec: "mp4a.40.2", bitrate: 128, userAgent: nil, isHLS: $0.contains("manifest"))
    })
}

@Test func resolutionCacheHonorsSignedExpiryCapacityAndEviction() async throws {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let clock = LockedDate(start)
    let cache = ResolutionCache(now: { clock.value })
    let video = try warmTrack(1)
    // Earliest of query and HLS path expiry wins, minus the ten-minute margin.
    let audio = resolved(video, urls: [
        "https://rr1.googlevideo.com/videoplayback?expire=\(Int(start.timeIntervalSince1970) + 3600)&ip=1",
        "https://manifest.googlevideo.com/api/manifest/hls_playlist/expire/\(Int(start.timeIntervalSince1970) + 1800)/ip/1/file/index.m3u8"])
    #expect(ResolutionCache.expiry(of: audio, now: start) == start.addingTimeInterval(1200))
    // Unsigned URLs fall back to a short lifetime; long signatures are capped at two hours.
    #expect(ResolutionCache.expiry(of: resolved(video, urls: ["https://rr1.googlevideo.com/a"]), now: start) == start.addingTimeInterval(900))
    #expect(ResolutionCache.expiry(of: resolved(video, urls: ["https://rr1.googlevideo.com/a?expire=9999999999"]), now: start)
            == start.addingTimeInterval(7200))

    await cache.store(audio)
    #expect(await cache.lookup(video.id)?.video == video)
    clock.value = start.addingTimeInterval(1199)
    #expect(await cache.lookup(video.id) != nil)
    clock.value = start.addingTimeInterval(1200)
    #expect(await cache.lookup(video.id) == nil, "Entries expire before the signed URL does")

    clock.value = start
    await cache.store(audio)
    await cache.remove(video.id)
    #expect(await cache.lookup(video.id) == nil)

    for index in 0..<ResolutionCache.capacity + 5 {
        clock.value = start.addingTimeInterval(TimeInterval(index))
        await cache.store(resolved(try warmTrack(100 + index), urls: ["https://rr1.googlevideo.com/a"]))
    }
    #expect(await cache.lookup(try warmTrack(100).id) == nil, "The soonest-expiring entry is evicted at capacity")
    #expect(await cache.lookup(try warmTrack(100 + ResolutionCache.capacity + 4).id) != nil)
}

private final class LockedDate: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Date
    init(_ value: Date) { stored = value }
    var value: Date {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

@MainActor
private func warmController(engine: PlaybackEngine, audio: URL, file: URL, warmDelay: Duration = .zero,
                            counts: @escaping @MainActor (String) -> Void) throws -> MaroController {
    try MaroController(loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: engine, search: { _ in [] },
        prepare: { video, position in
            counts("prepare")
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video, positionSeconds: position)
        },
        warm: { video in
            counts("warm:\(video.id)")
            try await Task.sleep(for: warmDelay)
            return try await engine.prepareAsset(AVURLAsset(url: audio), video: video)
        })
}

@Test @MainActor func warmedAndInFlightWarmsReplaceForegroundPreparation() async throws {
    let audio = try makeSilentAudio()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: folder) }
    let engine = PlaybackEngine()
    var calls: [String] = []
    let controller = try warmController(engine: engine, audio: audio, file: folder.appendingPathComponent("state.json"),
                                        warmDelay: .milliseconds(150)) { calls.append($0) }
    let first = try warmTrack(1), second = try warmTrack(2)

    // Completed warm: the click commits the buffered player without preparing.
    controller.warm(first)
    controller.warm(first)
    while !calls.contains("warm:\(first.id)") { await Task.yield() }
    try await Task.sleep(for: .milliseconds(400))
    try await controller.select(first)
    controller.pause()
    #expect(calls == ["warm:\(first.id)"], "Duplicate warms coalesce and a warmed click skips preparation")
    #expect(engine.loadedVideo?.id == first.id)

    // In-flight warm: the click joins it instead of starting a second resolve.
    calls = []
    controller.warm(second)
    while calls.isEmpty { await Task.yield() }
    try await controller.select(second)
    controller.pause()
    #expect(calls == ["warm:\(second.id)"])
    #expect(engine.loadedVideo?.id == second.id)
    await controller.shutdown()
}

@Test @MainActor func startedPlaylistTrackWarmsTheNextPlayableItem() async throws {
    let audio = try makeSilentAudio()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: audio); try? FileManager.default.removeItem(at: folder) }
    let engine = PlaybackEngine()
    engine.volume = 0
    var calls: [String] = []
    let controller = try warmController(engine: engine, audio: audio, file: folder.appendingPathComponent("state.json")) {
        calls.append($0)
    }
    let first = try warmTrack(1), third = try warmTrack(3)
    try await controller.playPlaylist([
        YouTubePlaylistItem(id: "a", video: first, title: first.title),
        YouTubePlaylistItem(id: "b", video: nil, title: "Unavailable"),
        YouTubePlaylistItem(id: "c", video: third, title: third.title)])
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !calls.contains("warm:\(third.id)"), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    #expect(calls == ["prepare", "warm:\(third.id)"], "Unavailable items are skipped when choosing the warm target")
    try await Task.sleep(for: .milliseconds(300))
    _ = try await controller.execute(CommandRequest(command: .next), openSearch: {})
    #expect(engine.loadedVideo?.id == third.id)
    #expect(!calls.dropFirst(2).contains("prepare"), "Next commits the warmed player")
    controller.pause()
    await controller.shutdown()
}
