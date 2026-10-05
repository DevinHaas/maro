import Foundation

public enum MetadataSearchIntent: Sendable { case foreground, discovery }

/// One metadata provider, one active exchange, and a bounded cache shared by every surface.
@MainActor final class MetadataSearchRequests {
    private struct Active {
        let id: UUID
        let query: String
        var intent: MetadataSearchIntent
        var consumers: Set<UUID>
        let task: Task<SearchPage, Error>
    }
    private var active: Active?
    private var tail: Task<SearchPage, Error>?
    private var cache: [String: (page: SearchPage, expires: ContinuousClock.Instant, used: ContinuousClock.Instant)] = [:]
    private let source: @Sendable (String, String?) async throws -> SearchPage
    private let now: () -> ContinuousClock.Instant
    var onChange: (@MainActor () -> Void)?
    init(source: @escaping @Sendable (String, String?) async throws -> SearchPage, now: @escaping () -> ContinuousClock.Instant) {
        self.source = source; self.now = now
    }
    var foregroundActive: Bool { active?.intent == .foreground }
    func cancelForeground() { if foregroundActive { cancelActive() } }
    func cancelActive() { let hadActive = active != nil; active?.task.cancel(); active = nil; if hadActive { onChange?() } }
    func clear() { cancelActive(); tail?.cancel(); cache.removeAll() }
    private func cancelConsumer(_ consumer: UUID, requestID: UUID) {
        guard var current = active, current.id == requestID else { return }
        current.consumers.remove(consumer)
        active = current
        if current.consumers.isEmpty { cancelActive() }
    }
    func request(_ query: String, continuation: String? = nil, intent: MetadataSearchIntent) async throws -> SearchPage {
        try Task.checkCancellation()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SearchPage(videos: []) }
        let key = query + "\u{0}" + (continuation ?? "")
        if intent == .discovery, foregroundActive { throw CancellationError() }
        let time = now()
        cache = cache.filter { $0.value.expires > time }
        if var cached = cache[key] {
            cached.used = time; cache[key] = cached
            return cached.page
        }
        let request: Active
        let consumer = UUID()
        if var current = active, current.query == key, !current.task.isCancelled {
            current.consumers.insert(consumer)
            if intent == .foreground { current.intent = .foreground }
            active = current; onChange?()
            request = current
        } else {
            cancelActive()
            let previous = tail
            let task = Task { @MainActor [source] in
                // A cancelled provider must finish before its successor can occupy the interpreter.
                if let previous { _ = await previous.result }
                try Task.checkCancellation()
                let page = try await source(query, continuation)
                try Task.checkCancellation()
                return SearchPage(videos: try SearchSession(query: query, results: page.videos).allResults, continuation: page.continuation)
            }
            request = Active(id: UUID(), query: key, intent: intent, consumers: [consumer], task: task)
            active = request; tail = task
            onChange?()
        }
        do {
            let videos = try await withTaskCancellationHandler { try await request.task.value } onCancel: { [weak self] in
                Task { @MainActor in self?.cancelConsumer(consumer, requestID: request.id) }
            }
            try Task.checkCancellation()
            guard active?.id == request.id else {
                if let cached = cache[key] { return cached.page }
                throw CancellationError()
            }
            let fetched = now()
            if cache.count >= 8, let oldest = cache.min(by: { $0.value.used < $1.value.used })?.key { cache.removeValue(forKey: oldest) }
            cache[key] = (videos, fetched.advanced(by: .seconds(60)), fetched)
            active = nil
            onChange?()
            return videos
        } catch {
            if Task.isCancelled { cancelConsumer(consumer, requestID: request.id) }
            else if active?.id == request.id { active = nil; onChange?() }
            throw error
        }
    }
}
