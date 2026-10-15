import Foundation

public enum ExtractorFailure: String, Error, Equatable, Sendable {
    case dependencyMissing
    case videoUnavailable
    case accessRestricted
    case network
    case runtimeUnavailable
    case sourceNeedsUpdate
    case failed

    public var message: String {
        switch self {
        case .dependencyMissing: "The YouTube extractor or JavaScript runtime is missing."
        case .videoUnavailable: "This video is unavailable. Choose another video."
        case .accessRestricted: "YouTube requires account access or an access check for this request."
        case .network: "YouTube could not be reached. Try again later."
        case .runtimeUnavailable: "The YouTube JavaScript runtime is unavailable or incompatible."
        case .sourceNeedsUpdate: "YouTube source needs an update."
        case .failed: "YouTube extraction failed. Try another video or check for an app update."
        }
    }

    /// Conservative diagnostics: access/network errors take priority over parser
    /// symptoms. An unknown exit never globally disables the source.
    static func classify(stderr: Data) -> Self {
        let text = String(decoding: stderr, as: UTF8.self).lowercased()
        if ["sign in", "sign-in", "not a bot", "age-restricted", "members-only", "private video"]
            .contains(where: text.contains) { return .accessRestricted }
        if ["timed out", "temporary failure", "unable to resolve", "connection refused", "network is unreachable",
            "certificate verify failed", "http error 429", "http error 403"]
            .contains(where: text.contains) { return .network }
        if ["video unavailable", "video has been removed", "not available in your country"]
            .contains(where: text.contains) { return .videoUnavailable }
        if ["no supported javascript runtime", "javascript runtime is not supported", "unable to find a supported javascript"]
            .contains(where: text.contains) { return .runtimeUnavailable }
        if ["signature extraction failed", "nsig extraction failed"]
            .contains(where: text.contains) { return .sourceNeedsUpdate }
        return .failed
    }
}

public struct YouTubeClient: Sendable {
    public let executable: URL
    public let nodeExecutable: URL
    private let worker: ExtractorWorker
    /// Speculative resolutions run in a second interpreter so they never queue
    /// ahead of, or get killed by, an explicit selection or search.
    private let prefetchWorker: ExtractorWorker
    private let resolutions = ResolutionCache()

    public init(executable: URL, nodeExecutable: URL) {
        self.executable = executable
        self.nodeExecutable = nodeExecutable
        let directory = executable.deletingLastPathComponent()
        let python = directory.appendingPathComponent("python/bin/python3")
        let arguments = ["-I", "-B", directory.appendingPathComponent("maro-extractor.py").path, nodeExecutable.path]
        worker = ExtractorWorker(executable: python, arguments: arguments)
        prefetchWorker = ExtractorWorker(executable: python, arguments: arguments)
    }

    public func search(_ query: String) async throws -> [VideoSummary] {
        try await searchPage(query).videos
    }

    public func searchPage(_ query: String, continuation: String? = nil) async throws -> SearchPage {
        _ = try YouTubeSource.searchArguments(query: query, nodeExecutable: nodeExecutable)
        let offset = continuation.flatMap(Int.init) ?? 0
        guard continuation == nil || (offset > 0 && offset < YouTubeSource.maximumSearchResults) else {
            throw SourceFailure.invalidQuery
        }
        let request = try JSONSerialization.data(withJSONObject: ["query": query.trimmingCharacters(in: .whitespacesAndNewlines), "offset": offset], options: [.sortedKeys])
        return try YouTubeSource.decodeSearchPage(await invoke("search", value: String(decoding: request, as: UTF8.self)))
    }

    /// Always fetches fresh signed sources and remembers them for `cachedResolution`.
    public func resolve(videoID: String, speculative: Bool = false) async throws -> ResolvedAudio {
        _ = try YouTubeSource.resolveArguments(videoID: videoID, nodeExecutable: nodeExecutable)
        let audio = try YouTubeSource.decodeResolution(
            await invoke("resolve", value: videoID, on: speculative ? prefetchWorker : worker), expectedVideoID: videoID)
        await resolutions.store(audio)
        return audio
    }

    public func cachedResolution(videoID: String) async -> ResolvedAudio? { await resolutions.lookup(videoID) }

    /// Drop a source that AVFoundation rejected so the next attempt re-resolves.
    public func forget(videoID: String) async { await resolutions.remove(videoID) }

    public func warmUp() async { _ = try? await invoke("ping", value: "") }

    public func shutdown() async {
        await worker.shutdown()
        await prefetchWorker.shutdown()
    }

    private func invoke(_ operation: String, value: String, on worker: ExtractorWorker? = nil) async throws -> Data {
        let directory = executable.deletingLastPathComponent()
        guard executable.isFileURL, nodeExecutable.isFileURL,
              FileManager.default.isExecutableFile(atPath: executable.path),
              FileManager.default.isExecutableFile(atPath: nodeExecutable.path),
              FileManager.default.isReadableFile(atPath: directory.appendingPathComponent("maro-extractor.py").path) else {
            throw ExtractorFailure.dependencyMissing
        }
        let data = try await (worker ?? self.worker).request(operation, value: value)
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SourceFailure.malformedResponse
        }
        if let error = envelope["error"] as? String {
            if error == "outputLimit" { throw ProcessFailure.outputLimit }
            throw ExtractorFailure(rawValue: error) ?? .failed
        }
        guard let result = envelope["result"], JSONSerialization.isValidJSONObject(result) else {
            throw SourceFailure.malformedResponse
        }
        return try JSONSerialization.data(withJSONObject: result)
    }
}

/// In-memory only: signed URLs are bound to the requesting IP and expire, so they
/// are never persisted. Failed playback from a cached entry evicts it (`forget`).
actor ResolutionCache {
    static let capacity = 50
    private var entries: [String: (audio: ResolvedAudio, expires: Date)] = [:]
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = Date.init) { self.now = now }

    func lookup(_ videoID: String) -> ResolvedAudio? {
        guard let entry = entries[videoID] else { return nil }
        guard entry.expires > now() else { entries[videoID] = nil; return nil }
        return entry.audio
    }

    func store(_ audio: ResolvedAudio) {
        let current = now()
        entries = entries.filter { $0.value.expires > current }
        // ponytail: O(n) eviction of the soonest-expiring entry; n is capped at 50.
        if entries.count >= Self.capacity, let oldest = entries.min(by: { $0.value.expires < $1.value.expires })?.key {
            entries[oldest] = nil
        }
        entries[audio.video.id] = (audio, Self.expiry(of: audio, now: current))
    }

    func remove(_ videoID: String) { entries[videoID] = nil }

    /// Googlevideo signs `expire` (unix seconds) into a query item or, for HLS
    /// manifests, a path segment. Keep a margin so playback never starts on a dying URL.
    static func expiry(of audio: ResolvedAudio, now: Date) -> Date {
        let stamps = audio.candidates.compactMap { candidate -> TimeInterval? in
            let components = URLComponents(url: candidate.url, resolvingAgainstBaseURL: false)
            if let value = components?.queryItems?.first(where: { $0.name == "expire" })?.value { return TimeInterval(value) }
            let path = candidate.url.pathComponents
            guard let index = path.firstIndex(of: "expire"), path.indices.contains(index + 1) else { return nil }
            return TimeInterval(path[index + 1])
        }
        guard let earliest = stamps.min() else { return now.addingTimeInterval(15 * 60) }
        return min(Date(timeIntervalSince1970: earliest - 10 * 60), now.addingTimeInterval(2 * 60 * 60))
    }
}
