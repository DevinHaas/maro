import AVFoundation
import Foundation
import Testing
@testable import MaroCore

private actor CandidateProbe {
    var active = 0
    var peak = 0
    var cancelled = 0
    func begin() { active += 1; peak = max(peak, active) }
    func end(cancelled: Bool) { active -= 1; if cancelled { self.cancelled += 1 } }
}

@Test @MainActor func playerVolumeSurvivesTransportAndReplacement() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    #expect(engine.volume == 1)
    engine.volume = -1
    #expect(engine.volume == 0)
    engine.volume = 2
    #expect(engine.volume == 1)
    engine.volume = 0.25
    engine.volume = .nan
    engine.volume = .infinity
    #expect(engine.volume == 0.25)
    let prepared = try await engine.prepareAsset(AVURLAsset(url: file), video: video)
    engine.volume = 0.5
    try engine.commit(prepared, autoplay: false)
    #expect(engine.volume == 0.5)
    #expect(engine.isMuted)
    try engine.resume()
    engine.pause()
    engine.volume = 0
    #expect(engine.isMuted)
    try await engine.replay()
    #expect(engine.volume == 0)
    engine.stop()
    let replacement = try await engine.prepareAsset(AVURLAsset(url: file), video: video)
    try engine.commit(replacement, autoplay: true)
    #expect(engine.volume == 0)
}

@Test @MainActor func readyFallbackDoesNotWaitForAStalledPreferredCandidate() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    let candidates = ["slow", "ready"].map { AudioCandidate(url: URL(string: "https://fixture.test/\($0)")!,
        audioCodec: "mp4a.40.2", bitrate: 128, userAgent: nil) }
    let engine = PlaybackEngine()
    let probe = CandidateProbe()
    let start = ContinuousClock().now
    let prepared = try await engine.prepare(ResolvedAudio(video: video, candidates: candidates), positionSeconds: 0,
        loadAsset: { candidate, _ in
            await probe.begin()
            do {
                if candidate.url.lastPathComponent == "slow" { try await Task.sleep(for: .seconds(6)) }
                let asset = AVURLAsset(url: file)
                await probe.end(cancelled: false)
                return asset
            } catch {
                await probe.end(cancelled: error is CancellationError)
                throw error
            }
        })
    #expect(start.duration(to: .now) < .seconds(3), "A stalled stream must not hold up a ready fallback")
    #expect(await probe.peak == 2)
    #expect(await probe.active == 0)
    #expect(await probe.cancelled == 1)
    #expect(!engine.hasItem, "Candidate racing must not replace or play anything until committed")
    try engine.commit(prepared, autoplay: false)
    let retained = engine.playbackID
    do {
        _ = try await engine.prepare(ResolvedAudio(video: video, candidates: candidates), positionSeconds: 0,
            loadAsset: { _, _ in throw AudioPreparationFailure.incompatible })
        Issue.record("Expected all candidates to fail")
    } catch { #expect(error as? AudioPreparationFailure == .incompatible) }
    #expect(engine.playbackID == retained)
    #expect(!engine.isPlaying)
    engine.stop()
}

@Test @MainActor func playbackCommitsOnlyPreparedItemsAndPreservesCurrentOnFailure() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    let prepared = try await engine.prepareAsset(AVURLAsset(url: file), video: video, positionSeconds: 0.25)
    #expect(!engine.hasItem)
    try engine.commit(prepared, autoplay: false)
    #expect(engine.loadedVideo == video)
    #expect(!engine.isPlaying)
    #expect(abs(engine.positionSeconds - 0.25) < 0.05)
    #expect(throws: PlaybackFailure.alreadyCommitted) { try engine.commit(prepared, autoplay: false) }
    do {
        _ = try await engine.prepareAsset(AVURLAsset(url: URL(fileURLWithPath: "/missing-maro.wav")), video: video)
        Issue.record("Expected preparation failure")
    } catch {
        #expect(engine.loadedVideo == video)
        #expect(engine.hasItem)
        #expect(!engine.isPlaying)
    }
    try engine.resume()
    #expect(engine.isPlaying)
    engine.pause()
    #expect(!engine.isPlaying)
    try await engine.replay()
    #expect(engine.isPlaying)
    engine.pause()
    #expect(engine.positionSeconds < 0.1)
    // Replay always suspends for its seek; a newer pause must win on resumption.
    var replay: Task<Void, Error>?
    await withCheckedContinuation { started in
        replay = Task { @MainActor in
            started.resume()
            try await engine.replay()
        }
    }
    engine.pause()
    do { try await replay?.value }
    catch { #expect(error as? PlaybackFailure == .superseded) }
    #expect(!engine.isPlaying)
}

@Test @MainActor func timelineTimeoutAndSupersessionLeaveLoadedItemReusable() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    try engine.commit(try await engine.prepareAsset(AVURLAsset(url: file), video: video), autoplay: false)
    let identity = engine.playbackID
    do {
        try await engine.seekLoaded(to: 0.8, invalidateOnFailure: false, deadline: .now)
        Issue.record("Expired seek must fail")
    } catch { #expect(error as? PlaybackFailure == .preparationTimedOut) }
    #expect(engine.hasReadyItem)
    #expect(engine.playbackID == identity)
    let first = Task { try await engine.seekLoaded(to: 0.2, invalidateOnFailure: false) }
    await Task.yield()
    try await engine.seekLoaded(to: 0.7, invalidateOnFailure: false)
    do {
        try await first.value
        Issue.record("Older seek must be superseded")
    } catch { #expect(error as? PlaybackFailure == .superseded) }
    #expect(engine.hasReadyItem)
    #expect(engine.playbackID == identity)
    #expect(abs(engine.positionSeconds - 0.7) < 0.05)
    #expect(engine.isMuted && !engine.isPlaying)
}

@Test @MainActor func playbackRejectsInvalidPositionAndExpiredPreparation() async throws {
    let file = try makeSilentAudio()
    defer { try? FileManager.default.removeItem(at: file) }
    let engine = PlaybackEngine()
    defer { engine.stop() }
    let video = try VideoSummary(id: "01234567890", title: "Silent fixture", creator: "Test")
    #expect(throws: PlaybackFailure.noLoadedVideo) { try engine.resume() }
    do {
        _ = try await engine.prepareAsset(AVURLAsset(url: file), video: video, positionSeconds: .nan)
        Issue.record("Expected position rejection")
    } catch { #expect(error as? PlaybackFailure == .invalidPosition) }
    do {
        _ = try await engine.prepareAsset(AVURLAsset(url: file), video: video, deadline: .now)
        Issue.record("Expected expired preparation")
    } catch { #expect(error as? PlaybackFailure == .preparationTimedOut) }
    #expect(!engine.hasItem)
}
