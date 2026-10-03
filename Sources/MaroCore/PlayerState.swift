import Foundation

public enum StateError: Error, Equatable, Sendable {
    case invalidVideo
    case invalidPosition
    case invalidFavorites
    case favoritesFull
    case unsupportedVersion(Int)
    case oversizedDocument
    case invalidSourceBuild
}

/// Stable identity and display metadata only. Media URLs never belong in state.
public struct VideoSummary: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let creator: String
    public let durationSeconds: Double?
    public let thumbnailURL: URL?

    public init(id: String, title: String, creator: String,
                durationSeconds: Double? = nil, thumbnailURL: URL? = nil) throws {
        self.id = id
        self.title = title
        self.creator = creator
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        try validate()
    }

    public func validate() throws {
        let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
        guard id.utf8.count == 11, id.allSatisfy({ allowed.contains($0) }),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.utf8.count <= 4096, creator.utf8.count <= 4096,
              durationSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true else {
            throw StateError.invalidVideo
        }
        if let url = thumbnailURL {
            guard url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil,
                  url.absoluteString.utf8.count <= 8192 else { throw StateError.invalidVideo }
        }
    }
}

public struct LoadedVideo: Codable, Equatable, Sendable {
    public let video: VideoSummary
    public let positionSeconds: Double

    public init(video: VideoSummary, positionSeconds: Double) throws {
        self.video = video
        self.positionSeconds = positionSeconds
        try validate()
    }

    public func validate() throws {
        try video.validate()
        guard positionSeconds.isFinite, positionSeconds >= 0 else {
            throw StateError.invalidPosition
        }
    }
}

public struct StateDocument: Codable, Equatable, Sendable {
    public private(set) var schemaVersion = 1
    public var loadedVideo: LoadedVideo?
    /// Durable compatibility gate, not a transient network/video error.
    public var sourceDisabledBuild: String?
    public private(set) var favorites: [VideoSummary] = []

    public init(loadedVideo: LoadedVideo? = nil) { self.loadedVideo = loadedVideo }

    public func validate() throws {
        guard schemaVersion == 1 else { throw StateError.unsupportedVersion(schemaVersion) }
        try loadedVideo?.validate()
        if let build = sourceDisabledBuild {
            guard !build.isEmpty, build.utf8.count <= 128 else { throw StateError.invalidSourceBuild }
        }
        guard favorites.count <= 20, Set(favorites.map(\.id)).count == favorites.count else {
            throw StateError.invalidFavorites
        }
        try favorites.forEach { try $0.validate() }
    }

    /// Returns true when added, false when removed. Capacity never evicts a record.
    @discardableResult
    public mutating func toggleFavorite(_ video: VideoSummary) throws -> Bool {
        try video.validate()
        if let index = favorites.firstIndex(where: { $0.id == video.id }) {
            favorites.remove(at: index)
            return false
        }
        guard favorites.count < 20 else { throw StateError.favoritesFull }
        favorites.insert(video, at: 0)
        return true
    }

    public mutating func removeFavorite(id: String) {
        favorites.removeAll { $0.id == id }
    }
}

/// An ephemeral result batch; revealing more performs no source request.
public struct SearchSession: Sendable {
    public let query: String
    private let results: [VideoSummary]
    private var visibleCount = 5

    public init(query: String, results: [VideoSummary]) throws {
        self.query = query
        var ids = Set<String>()
        var unique: [VideoSummary] = []
        for video in results {
            try video.validate()
            if ids.insert(video.id).inserted { unique.append(video) }
            if unique.count == 20 { break }
        }
        self.results = unique
    }

    public var visibleResults: [VideoSummary] { Array(results.prefix(visibleCount)) }
    public var hasMore: Bool { visibleCount < results.count }
    public func neighbor(of id: String, offset: Int) -> VideoSummary? {
        guard offset == -1 || offset == 1,
              let index = results.firstIndex(where: { $0.id == id }),
              results.indices.contains(index + offset) else { return nil }
        return results[index + offset]
    }
    public mutating func revealMore() { visibleCount = min(visibleCount + 5, results.count) }
}
