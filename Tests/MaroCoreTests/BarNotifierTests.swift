import Foundation
import Testing
@testable import MaroCore

private actor BarEvents {
    var count = 0
    func send() { count += 1 }
}

@Test @MainActor func barEventsCoalesceAndIgnorePositionOnlyChanges() async throws {
    let events = BarEvents()
    let notifier = BarNotifier { await events.send() }
    let video = try VideoSummary(id: "abcdefghijk", title: "Title", creator: "Creator")
    func state(_ position: Double, playback: PlaybackState = .playing, error: String? = nil) throws -> PlayerSnapshot {
        PlayerSnapshot(loadedVideo: try LoadedVideo(video: video, positionSeconds: position), favorites: [],
            playback: playback, isSelecting: false, sourceNeedsUpdate: false, error: error, persistenceError: nil)
    }
    notifier.update(try state(1))
    notifier.update(try state(2))
    notifier.update(try state(3, playback: .paused))
    try await Task.sleep(for: .milliseconds(250))
    #expect(await events.count == 1)
    notifier.update(try state(4, playback: .paused))
    try await Task.sleep(for: .milliseconds(200))
    #expect(await events.count == 1)
    notifier.update(try state(4, playback: .paused, error: "Source needs an update"))
    try await Task.sleep(for: .milliseconds(250))
    #expect(await events.count == 2)
    notifier.update(try state(5))
    await notifier.stop()
    try await Task.sleep(for: .milliseconds(200))
    #expect(await events.count == 2)
}
