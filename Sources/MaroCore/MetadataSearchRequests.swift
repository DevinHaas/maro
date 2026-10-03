import Foundation

public enum MetadataSearchIntent: Sendable { case foreground, discovery }

/// One metadata provider, one active exchange, and a bounded cache shared by every surface.
@MainActor final class MetadataSearchRequests {
    private struct Active {
        let id: UUID
        let query: String
        var intent: MetadataSearchIntent
        let task: Task<[VideoSummary], Error>
    }
    private var active: Active?
    private var tail: Task<[VideoSummary], Error>?
    private var cache: [String: (videos: [VideoSummary], expires: ContinuousClock.Instant, used: ContinuousClock.Instant)] = [:]
    private let source: @Sendable (String) async throws -> [VideoSummary]
    private let now: () -> ContinuousClock.Instant
    var onChange: (@MainActor () -> Void)?
    init(source: @escaping @Sendable (String) async throws -> [VideoSummary], now: @escaping () -> ContinuousClock.Instant) {
        self.source = source; self.now = now
    }
    var foregroundActive: Bool { active?.intent == .foreground }
    func cancelForeground() { if foregroundActive { cancelActive() } }
    func cancelActive() { let hadActive = active != nil; active?.task.cancel(); active = nil; if hadActive { onChange?() } }
    func clear() { cancelActive(); tail?.cancel(); cache.removeAll() }
    func request(_ query: String, intent: MetadataSearchIntent) async throws -> [VideoSummary] {
        try Task.checkCancellation()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        if intent == .discovery, foregroundActive { throw CancellationError() }
        let time = now()
        cache = cache.filter { $0.value.expires > time }
        if var cached = cache[query] {
            cached.used = time; cache[query] = cached
            return cached.videos
        }
        let request: Active
        if var current = active, current.query == query, !current.task.isCancelled {
            if intent == .foreground { current.intent = .foreground; active = current; onChange?() }
            request = current
        } else {
            cancelActive()
            let previous = tail
            let task = Task { @MainActor [source] in
                // A cancelled provider must finish before its successor can occupy the interpreter.
                if let previous { _ = await previous.result }
                try Task.checkCancellation()
                let videos = try await source(query)
                try Task.checkCancellation()
                return try SearchSession(query: query, results: videos).allResults
            }
            request = Active(id: UUID(), query: query, intent: intent, task: task)
            active = request; tail = task
            onChange?()
        }
        do {
            let videos = try await withTaskCancellationHandler { try await request.task.value } onCancel: { request.task.cancel() }
            try Task.checkCancellation()
            guard active?.id == request.id else {
                if let cached = cache[query] { return cached.videos }
                throw CancellationError()
            }
            let fetched = now()
            if cache.count >= 8, let oldest = cache.min(by: { $0.value.used < $1.value.used })?.key { cache.removeValue(forKey: oldest) }
            cache[query] = (videos, fetched.advanced(by: .seconds(60)), fetched)
            active = nil
            onChange?()
            return videos
        } catch {
            if active?.id == request.id { active = nil; onChange?() }
            throw error
        }
    }
}
