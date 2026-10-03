import AVFoundation
import Foundation

public enum PlaybackEvent: Equatable, Sendable {
    case started
    case ended
    case stalled
    case accessRejected
    case rateChanged
    case timelineChanged
    case position(Double)
    case failed(domain: String, code: Int)
}

/// Immutable ownership bag. Framework observer removal is safe during destruction;
/// no callback touches the bag, and emitted values contain no framework objects.
final class PlaybackObservation: @unchecked Sendable {
    private let player: AVPlayer
    private let notifications: [NSObjectProtocol]
    private let timeObserver: Any
    private let statusObserver: NSKeyValueObservation
    private let transportObserver: NSKeyValueObservation
    private let rateObserver: NSKeyValueObservation
    private let muteObserver: NSKeyValueObservation
    private let durationObserver: NSKeyValueObservation
    private let rangesObserver: NSKeyValueObservation

    init(player: AVPlayer, item: AVPlayerItem, emit: @escaping @Sendable (PlaybackEvent) -> Void) {
        self.player = player
        notifications = [
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                object: item, queue: nil) { _ in emit(.ended) },
            NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled,
                object: item, queue: nil) { _ in emit(.stalled) },
            NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item, queue: nil) { notification in
                    let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                    emit(Self.failure(error, httpStatus: item.errorLog()?.events.last?.errorStatusCode))
                }
        ]
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main) { time in
                if time.seconds.isFinite { emit(.position(max(0, time.seconds))) }
            }
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            emit(.timelineChanged)
            if item.status == .failed {
                let error = item.error as NSError?
                emit(Self.failure(error, httpStatus: item.errorLog()?.events.last?.errorStatusCode))
            }
        }
        transportObserver = player.observe(\.timeControlStatus, options: [.new]) { player, _ in
            if player.timeControlStatus == .playing { emit(.started) }
        }
        rateObserver = player.observe(\.rate, options: [.new]) { _, _ in emit(.rateChanged) }
        muteObserver = player.observe(\.isMuted, options: [.new]) { _, _ in emit(.rateChanged) }
        durationObserver = item.observe(\.duration, options: [.new]) { _, _ in emit(.timelineChanged) }
        rangesObserver = item.observe(\.seekableTimeRanges, options: [.new]) { _, _ in emit(.timelineChanged) }
    }

    static func failure(_ error: NSError?, httpStatus: Int?) -> PlaybackEvent {
        // Access rejection can mean an expired signed URL. Refresh once; do not
        // misclassify general network/decoder failures or stalls as expiry.
        if httpStatus == 403 || httpStatus == 410 { return .accessRejected }
        return .failed(domain: error?.domain ?? AVFoundationErrorDomain, code: error?.code ?? 0)
    }

    deinit {
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        player.removeTimeObserver(timeObserver)
        statusObserver.invalidate()
        transportObserver.invalidate()
        rateObserver.invalidate()
        muteObserver.invalidate()
        durationObserver.invalidate()
        rangesObserver.invalidate()
    }
}
