import AVFoundation
import Foundation
import Testing
@testable import MaroCore

@Test @MainActor func nativePlaybackReportsPositionAndEndWithoutUnloadingVideo() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "01234567890", title: "Silent event fixture", creator: "Test")
    let engine = PlaybackEngine()
    defer { engine.stop() }
    var events: [PlaybackEvent] = []
    engine.onEvent = { events.append($0) }
    let prepared = try await engine.prepareAsset(AVURLAsset(url: file), video: video)
    try engine.commit(prepared, autoplay: true)
    let deadline = ContinuousClock().now.advanced(by: .seconds(5))
    while !events.contains(.ended), ContinuousClock().now < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
    #expect(events.contains(.started))
    #expect(events.contains(.ended))
    #expect(events.contains { if case .position(let seconds) = $0 { seconds > 0.1 } else { false } })
    #expect(engine.loadedVideo == video)
    #expect(engine.hasItem)
    #expect(!engine.isPlaying)
    try await engine.replay()
    #expect(engine.isPlaying)
    #expect(engine.positionSeconds < 0.1)
    engine.pause()
}

@Test @MainActor func obsoleteCallbacksAndCallbacksAfterStopAreIgnored() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "01234567890", title: "Silent event fixture", creator: "Test")
    let engine = PlaybackEngine()
    defer { engine.stop() }
    try engine.commit(await engine.prepareAsset(AVURLAsset(url: file), video: video), autoplay: false)
    let previous = try #require(engine.playbackID)
    try engine.commit(await engine.prepareAsset(AVURLAsset(url: file), video: video), autoplay: false)
    let current = try #require(engine.playbackID)
    var events: [PlaybackEvent] = []
    engine.onEvent = { events.append($0) }
    engine.receive(.stalled, playbackID: previous)
    engine.receive(.failed(domain: "fixture", code: 1), playbackID: previous)
    #expect(events.isEmpty)
    engine.receive(.stalled, playbackID: current)
    #expect(events == [.stalled])
    engine.receive(.ended, playbackID: current) // premature end after replay/seek
    engine.receive(.position(.nan), playbackID: current)
    #expect(events == [.stalled])
    engine.stop()
    events.removeAll()
    engine.receive(.failed(domain: "fixture", code: 2), playbackID: current)
    #expect(events.isEmpty)
}

@Test @MainActor func releasingEngineReleasesObserversAndPlayer() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    var engine: PlaybackEngine? = PlaybackEngine()
    weak var weakEngine = engine
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    let prepared = try await engine!.prepareAsset(AVURLAsset(url: file), video: video)
    try engine!.commit(prepared, autoplay: false)
    engine = nil
    #expect(weakEngine == nil)
}
