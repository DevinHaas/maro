import Foundation

/// A finite on-demand item's actual seekable intervals, independent of metadata
/// duration and buffered ranges. An absent timeline means seeking is unavailable.
public struct PlaybackTimeline: Equatable, Sendable, Codable {
    public let duration: Double
    public let ranges: [ClosedRange<Double>]

    init?(duration: Double, ranges: [ClosedRange<Double>]) {
        guard duration.isFinite, duration > 0 else { return nil }
        let valid = ranges.compactMap { range -> ClosedRange<Double>? in
            guard range.lowerBound.isFinite, range.upperBound.isFinite else { return nil }
            let lower = max(0, range.lowerBound)
            let upper = min(duration, range.upperBound)
            return lower < upper ? lower...upper : nil
        }.sorted { $0.lowerBound < $1.lowerBound }
        guard !valid.isEmpty else { return nil }
        self.duration = duration
        self.ranges = valid
    }

    /// Gaps snap to the nearest reachable boundary; ties favor the earlier time.
    public func target(for seconds: Double) -> Double? {
        guard seconds.isFinite else { return nil }
        return ranges.map { min($0.upperBound, max($0.lowerBound, seconds)) }
            .min {
                let left = abs($0 - seconds), right = abs($1 - seconds)
                return left == right ? $0 < $1 : left < right
            }
    }
}
