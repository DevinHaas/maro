import AVFoundation
import Foundation

public enum AudioPreparationFailure: Error, Equatable, Sendable {
    case unsupportedCodec
    case incompatible
    case timedOut
    case invalidTimeout
    case mediaLoad(domain: String, code: Int)
}

/// Prepares an asset without touching the current player or its playback state.
/// Player-item readiness remains a separate gate before committing replacement.
public enum AudioAssetLoader {
    public static func prepare(_ candidate: AudioCandidate, timeout: Duration = .seconds(20)) async throws -> AVURLAsset {
        // HLS codec metadata is often absent in extraction; native manifest loading
        // below remains the compatibility gate, followed by player-item readiness.
        guard candidate.isHLS || AVURLAsset.isPlayableExtendedMIMEType("audio/mp4; codecs=\"\(candidate.audioCodec)\"") else {
            throw AudioPreparationFailure.unsupportedCodec
        }
        let options = candidate.userAgent.map { [AVURLAssetHTTPUserAgentKey: $0] }
        return try await loadAsset(AVURLAsset(url: candidate.url, options: options), timeout: timeout)
    }

    static func loadAsset(_ asset: AVURLAsset, timeout: Duration) async throws -> AVURLAsset {
        guard timeout > .zero, timeout <= .seconds(300) else { throw AudioPreparationFailure.invalidTimeout }
        try Task.checkCancellation()
        let deadline = Task {
            try await Task.sleep(for: timeout)
            asset.cancelLoading()
        }
        defer { deadline.cancel() }
        return try await withTaskCancellationHandler {
            do {
                let playable = try await asset.load(.isPlayable)
                try Task.checkCancellation()
                guard playable else { throw AudioPreparationFailure.incompatible }
                return asset
            } catch {
                try Task.checkCancellation()
                if let known = error as? AudioPreparationFailure { throw known }
                let failure = error as NSError
                if failure.domain == AVFoundationErrorDomain && failure.code == AVError.operationCancelled.rawValue {
                    throw AudioPreparationFailure.timedOut
                }
                // Do not propagate NSError userInfo: it can contain signed URLs.
                throw AudioPreparationFailure.mediaLoad(domain: failure.domain, code: failure.code)
            }
        } onCancel: {
            asset.cancelLoading()
        }
    }
}
