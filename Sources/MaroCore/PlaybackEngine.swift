import AVFoundation
import Foundation

public enum PlaybackFailure: Error, Equatable, Sendable {
    case noLoadedVideo
    case invalidPosition
    case preparationTimedOut
    case itemFailed
    case seekFailed
    case superseded
    case alreadyCommitted
}

@MainActor
public final class PreparedPlayback {
    public let video: VideoSummary
    private var player: AVPlayer?

    fileprivate init(video: VideoSummary, player: AVPlayer) {
        self.video = video
        self.player = player
    }

    fileprivate func consume() throws -> AVPlayer {
        guard let player else { throw PlaybackFailure.alreadyCommitted }
        self.player = nil
        return player
    }
}

/// Owns one audible player. Preparation uses a muted player to establish readiness;
/// commit hands over the whole player because AVPlayerItems cannot safely migrate.
@MainActor
public final class PlaybackEngine {
    private var player = AVPlayer()
    private var transportGeneration = 0
    private var playbackRequested = false
    private var seekGeneration = 0
    private var canReuseItem = true
    private var observation: PlaybackObservation?
    public private(set) var playbackID: UUID?
    public var onEvent: (@MainActor (PlaybackEvent) -> Void)?
    public private(set) var loadedVideo: VideoSummary?

    public init() {}

    public var positionSeconds: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }
    public var isPlaying: Bool { player.rate != 0 }
    /// Player gain only; never changes the system output volume.
    public var volume: Double {
        get { Double(player.volume) }
        set {
            guard newValue.isFinite else { return }
            player.volume = Float(min(1, max(0, newValue)))
        }
    }
    var isMuted: Bool { player.isMuted }
    public var hasItem: Bool { player.currentItem != nil }
    public var hasReadyItem: Bool { canReuseItem && player.currentItem?.status == .readyToPlay }

    public var timeline: PlaybackTimeline? {
        guard hasReadyItem, let item = player.currentItem else { return nil }
        let ranges = item.seekableTimeRanges.compactMap { value -> ClosedRange<Double>? in
            let range = value.timeRangeValue
            let start = range.start.seconds, end = range.end.seconds
            guard start.isFinite, end.isFinite, start < end else { return nil }
            return start...end
        }
        return PlaybackTimeline(duration: item.duration.seconds, ranges: ranges)
    }

    /// Reuse the current player for an explicit reselection. The controller applies
    /// the latest play/pause intent after the seek, just as it does after preparation.
    func seekLoaded(to seconds: Double, invalidateOnFailure: Bool = true,
                    deadline: ContinuousClock.Instant = .now.advanced(by: .seconds(10))) async throws {
        guard let item = player.currentItem, item.status == .readyToPlay else { throw PlaybackFailure.itemFailed }
        guard seconds.isFinite, seconds >= 0 else { throw PlaybackFailure.invalidPosition }
        do {
            try await seek(item, seconds: seconds, deadline: deadline)
        } catch {
            if invalidateOnFailure, !(error is CancellationError), error as? PlaybackFailure != .superseded,
               player.currentItem === item { canReuseItem = false }
            throw error
        }
        try Task.checkCancellation()
        guard player.currentItem === item else { throw PlaybackFailure.superseded }
    }

    public func prepare(_ audio: ResolvedAudio, positionSeconds: Double = 0) async throws -> PreparedPlayback {
        try await prepare(audio, positionSeconds: positionSeconds,
            loadAsset: { try await AudioAssetLoader.prepare($0, timeout: $1) })
    }

    // Two bounded attempts prevent a stalled preferred stream from withholding an
    // otherwise ready fallback. Give the preferred stream the first second.
    func prepare(_ audio: ResolvedAudio, positionSeconds: Double,
                 loadAsset: @escaping @Sendable (AudioCandidate, Duration) async throws -> AVURLAsset) async throws -> PreparedPlayback {
        guard positionSeconds.isFinite, positionSeconds >= 0 else { throw PlaybackFailure.invalidPosition }
        let deadline = ContinuousClock().now.advanced(by: .seconds(30))
        return try await withThrowingTaskGroup(of: PreparedPlayback.self) { group in
            defer { group.cancelAll() }
            var nextIndex = 0
            for index in 0..<min(2, audio.candidates.count) {
                let candidate = audio.candidates[index]
                group.addTask {
                    if index == 1 { try await Task.sleep(for: .seconds(1)) }
                    return try await self.prepareCandidate(candidate, video: audio.video,
                        position: positionSeconds, deadline: deadline, loadAsset: loadAsset)
                }
                nextIndex += 1
            }
            var lastFailure: any Error = SourceFailure.noCompatibleAudio
            while let result = await group.nextResult() {
                try Task.checkCancellation()
                switch result {
                case .success(let prepared): return prepared
                case .failure(let failure):
                    lastFailure = failure
                    if nextIndex < audio.candidates.count {
                        let candidate = audio.candidates[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            try await self.prepareCandidate(candidate, video: audio.video,
                                position: positionSeconds, deadline: deadline, loadAsset: loadAsset)
                        }
                    }
                }
            }
            throw lastFailure
        }
    }

    private func prepareCandidate(_ candidate: AudioCandidate, video: VideoSummary, position: Double,
                                  deadline: ContinuousClock.Instant,
                                  loadAsset: @Sendable (AudioCandidate, Duration) async throws -> AVURLAsset) async throws -> PreparedPlayback {
        try Task.checkCancellation()
        let remaining = ContinuousClock().now.duration(to: deadline)
        guard remaining > .zero else { throw PlaybackFailure.preparationTimedOut }
        let asset = try await loadAsset(candidate, min(.seconds(15), remaining))
        return try await prepareAsset(asset, video: video, positionSeconds: position, deadline: deadline)
    }

    func prepareAsset(_ asset: AVURLAsset, video: VideoSummary, positionSeconds: Double = 0,
                      deadline: ContinuousClock.Instant = ContinuousClock().now.advanced(by: .seconds(10))) async throws -> PreparedPlayback {
        try video.validate()
        guard positionSeconds.isFinite, positionSeconds >= 0 else { throw PlaybackFailure.invalidPosition }
        try Task.checkCancellation()
        guard ContinuousClock().now < deadline else { throw PlaybackFailure.preparationTimedOut }
        let item = AVPlayerItem(asset: asset)
        // A short native forward buffer starts long HLS recordings progressively.
        // This is a preference, not a hard memory cap; AVFoundation owns eviction.
        item.preferredForwardBufferDuration = 30
        let stagingPlayer = AVPlayer(playerItem: item)
        stagingPlayer.isMuted = true
        let clock = ContinuousClock()
        while item.status == .unknown {
            guard clock.now < deadline else { throw PlaybackFailure.preparationTimedOut }
            try await Task.sleep(for: .milliseconds(25))
        }
        try Task.checkCancellation()
        guard item.status == .readyToPlay else { throw PlaybackFailure.itemFailed }
        if positionSeconds > 0 {
            let duration = item.duration.seconds
            let position = duration.isFinite ? min(positionSeconds, max(0, duration)) : positionSeconds
            try await seek(item, seconds: position, deadline: deadline)
        }
        try Task.checkCancellation()
        return PreparedPlayback(video: video, player: stagingPlayer)
    }

    /// The controller checks its operation identity immediately before this call.
    public func commit(_ prepared: PreparedPlayback, autoplay: Bool) throws {
        let replacement = try prepared.consume()
        guard replacement.currentItem?.status == .readyToPlay else { throw PlaybackFailure.itemFailed }
        replacement.volume = player.volume
        transportGeneration += 1
        observation = nil
        let id = UUID()
        playbackID = id
        player.pause()
        player.replaceCurrentItem(with: nil)
        player = replacement
        canReuseItem = true
        playbackRequested = autoplay
        player.isMuted = !autoplay
        loadedVideo = prepared.video
        if let item = player.currentItem {
            observation = PlaybackObservation(player: player, item: item) { [weak self] event in
                Task { @MainActor in self?.receive(event, playbackID: id) }
            }
        }
        if autoplay { player.play() } else { player.pause() }
    }

    public func pause() {
        transportGeneration += 1
        playbackRequested = false
        // Request silence immediately. AVPlayer can publish delayed rate/mute
        // values after pause; observers reconcile them with this latest intent.
        player.isMuted = true
        player.pause()
    }

    public func resume() throws {
        guard player.currentItem != nil else { throw PlaybackFailure.noLoadedVideo }
        guard player.currentItem?.status != .failed else { throw PlaybackFailure.itemFailed }
        transportGeneration += 1
        playbackRequested = true
        player.isMuted = false
        player.play()
    }

    public func replay() async throws {
        try Task.checkCancellation()
        guard let item = player.currentItem else { throw PlaybackFailure.noLoadedVideo }
        transportGeneration += 1
        let generation = transportGeneration
        do {
            try await seek(item, seconds: 0, deadline: ContinuousClock().now.advanced(by: .seconds(10)))
        } catch {
            guard player.currentItem === item, transportGeneration == generation else { throw PlaybackFailure.superseded }
            throw error
        }
        try Task.checkCancellation()
        guard player.currentItem === item, transportGeneration == generation else { throw PlaybackFailure.superseded }
        playbackRequested = true
        player.isMuted = false
        player.play()
    }

    public func stop() {
        transportGeneration += 1
        playbackRequested = false
        playbackID = nil
        observation = nil
        player.isMuted = true
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedVideo = nil
    }

    func receive(_ event: PlaybackEvent, playbackID: UUID) {
        guard self.playbackID == playbackID else { return }
        if event == .rateChanged {
            if !playbackRequested {
                if !player.isMuted { player.isMuted = true }
                if player.rate != 0 { player.pause() }
            }
            return
        }
        // Ignore an end callback queued before a seek/replay on the same item.
        if event == .ended, let duration = player.currentItem?.duration.seconds,
           duration.isFinite, positionSeconds + 0.05 < duration { return }
        if event == .started, player.timeControlStatus != .playing { return }
        if case .position(let seconds) = event {
            guard seconds.isFinite, seconds >= 0 else { return }
            // A queued pre-seek sample must not roll the controller's position back.
            onEvent?(.position(positionSeconds))
            return
        }
        onEvent?(event)
    }

    private func seek(_ item: AVPlayerItem, seconds: Double, deadline: ContinuousClock.Instant) async throws {
        seekGeneration += 1
        let generation = seekGeneration
        var completed: Bool?
        item.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                  toleranceBefore: .zero, toleranceAfter: .zero) { success in
            Task { @MainActor in completed = success }
        }
        defer {
            // An older completion must not cancel a newer seek on the same item.
            if seekGeneration == generation { item.cancelPendingSeeks() }
        }
        while completed == nil {
            guard seekGeneration == generation else { throw PlaybackFailure.superseded }
            guard ContinuousClock().now < deadline else { throw PlaybackFailure.preparationTimedOut }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard seekGeneration == generation else { throw PlaybackFailure.superseded }
        guard completed == true else { throw PlaybackFailure.seekFailed }
    }
}
