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

    public init(executable: URL, nodeExecutable: URL) {
        self.executable = executable
        self.nodeExecutable = nodeExecutable
        let directory = executable.deletingLastPathComponent()
        worker = ExtractorWorker(executable: directory.appendingPathComponent("python/bin/python3"),
            arguments: ["-I", "-B", directory.appendingPathComponent("maro-extractor.py").path, nodeExecutable.path])
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

    public func resolve(videoID: String) async throws -> ResolvedAudio {
        _ = try YouTubeSource.resolveArguments(videoID: videoID, nodeExecutable: nodeExecutable)
        return try YouTubeSource.decodeResolution(await invoke("resolve", value: videoID), expectedVideoID: videoID)
    }

    public func warmUp() async { _ = try? await invoke("ping", value: "") }

    public func shutdown() async { await worker.shutdown() }

    private func invoke(_ operation: String, value: String) async throws -> Data {
        let directory = executable.deletingLastPathComponent()
        guard executable.isFileURL, nodeExecutable.isFileURL,
              FileManager.default.isExecutableFile(atPath: executable.path),
              FileManager.default.isExecutableFile(atPath: nodeExecutable.path),
              FileManager.default.isReadableFile(atPath: directory.appendingPathComponent("maro-extractor.py").path) else {
            throw ExtractorFailure.dependencyMissing
        }
        let data = try await worker.request(operation, value: value)
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
