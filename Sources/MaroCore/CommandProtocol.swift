import Foundation

public enum CommandName: String, Codable, Sendable {
    case status, search, player, toggle, replay, select, previous, next
    case favoriteToggle = "favorite_toggle"
    case favoriteRemove = "favorite_remove"
}

public enum CommandProtocolFailure: Error, Equatable, Sendable {
    case invalidArguments, invalidFrame, oversizedFrame, malformedJSON
    case unsupportedVersion, invalidID, invalidPayload, mismatchedResponse
}

public struct CommandRequest: Codable, Equatable, Sendable {
    public let version: Int
    public let id: String
    public let command: CommandName
    public let videoID: String?

    public init(id: String = UUID().uuidString, command: CommandName, videoID: String? = nil) throws {
        version = 1
        self.id = id
        self.command = command
        self.videoID = videoID
        try validate()
    }

    public func validate() throws {
        guard version == 1 else { throw CommandProtocolFailure.unsupportedVersion }
        guard Self.validID(id) else { throw CommandProtocolFailure.invalidID }
        switch command {
        case .select, .favoriteToggle, .favoriteRemove:
            guard let videoID,
                  (try? VideoSummary(id: videoID, title: "Validation", creator: "")) != nil else {
                throw CommandProtocolFailure.invalidPayload
            }
        default:
            guard videoID == nil else { throw CommandProtocolFailure.invalidPayload }
        }
    }

    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 64 && id.utf8.allSatisfy { $0 >= 33 && $0 <= 126 }
    }

    /// Arguments exclude the executable name. No shell interpretation or aliases.
    public static func arguments(_ arguments: [String], id: String = UUID().uuidString) throws -> Self {
        if arguments.count == 1, let command = CommandName(rawValue: arguments[0]),
           [.status, .search, .player, .toggle, .replay, .previous, .next].contains(command) {
            return try Self(id: id, command: command)
        }
        if arguments.count == 2, arguments[0] == "select" {
            return try Self(id: id, command: .select, videoID: arguments[1])
        }
        if arguments.count == 3, arguments[0] == "favorite" {
            let command: CommandName
            switch arguments[1] {
            case "toggle": command = .favoriteToggle
            case "remove": command = .favoriteRemove
            default: throw CommandProtocolFailure.invalidArguments
            }
            return try Self(id: id, command: command, videoID: arguments[2])
        }
        throw CommandProtocolFailure.invalidArguments
    }
}

public struct CommandError: Codable, Equatable, Sendable {
    public enum Code: String, Codable, Sendable {
        case invalidRequest = "invalid_request"
        case unsupportedVersion = "unsupported_version"
        case videoUnavailable = "video_unavailable"
        case noLoadedVideo = "no_loaded_video"
        case favoritesFull = "favorites_full"
        case sourceNeedsUpdate = "source_needs_update"
        case serviceUnavailable = "service_unavailable"
        case superseded
    }
    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }
}

public struct CommandResponse: Codable, Sendable {
    public let version: Int
    public let id: String
    public let ok: Bool
    public let state: PlaybackState?
    public let snapshot: PlayerSnapshot?
    public let error: CommandError?

    public init(id: String, snapshot: PlayerSnapshot) {
        version = 1; self.id = id; ok = true
        state = snapshot.playback; self.snapshot = snapshot; error = nil
    }

    public init(id: String, error: CommandError) {
        version = 1; self.id = id; ok = false
        state = nil; snapshot = nil; self.error = error
    }

    public func validate(expectedID: String) throws {
        guard version == 1 else { throw CommandProtocolFailure.unsupportedVersion }
        guard CommandRequest.validID(id) else { throw CommandProtocolFailure.invalidID }
        guard id == expectedID else { throw CommandProtocolFailure.mismatchedResponse }
        if ok {
            guard error == nil, let snapshot, state == snapshot.playback,
                  snapshot.favorites.count <= 20,
                  Set(snapshot.favorites.map(\.id)).count == snapshot.favorites.count else {
                throw CommandProtocolFailure.invalidPayload
            }
            do {
                try snapshot.loadedVideo?.validate()
                try snapshot.favorites.forEach { try $0.validate() }
                let identities = Set(snapshot.favorites.map(\.id) + (snapshot.loadedVideo.map { [$0.video.id] } ?? []))
                for (identity, path) in snapshot.localThumbnailPaths ?? [:] {
                    guard identities.contains(identity), path.hasPrefix("/"), path.utf8.count <= 4096,
                          !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                          URL(fileURLWithPath: path).lastPathComponent == identity + ".jpg" else {
                        throw CommandProtocolFailure.invalidPayload
                    }
                }
            } catch { throw CommandProtocolFailure.invalidPayload }
        } else {
            guard state == nil, snapshot == nil, let error, !error.message.isEmpty,
                  error.message.utf8.count <= 4096 else { throw CommandProtocolFailure.invalidPayload }
        }
    }
}

/// One UTF-8 JSON line per connection. The transport must enforce these same
/// limits while reading, before retaining or decoding an untrusted frame.
public enum CommandWire {
    public static let maximumRequestBytes = 4096
    public static let maximumResponseBytes = 1_048_576

    public static func encode(_ request: CommandRequest) throws -> Data {
        try request.validate()
        return try encodeLine(request, limit: maximumRequestBytes)
    }

    public static func encode(_ response: CommandResponse) throws -> Data {
        try response.validate(expectedID: response.id)
        return try encodeLine(response, limit: maximumResponseBytes)
    }

    public static func request(_ frame: Data) throws -> CommandRequest {
        let value = try decodeLine(CommandRequest.self, frame, limit: maximumRequestBytes)
        try value.validate()
        return value
    }

    public static func response(_ frame: Data, expectedID: String) throws -> CommandResponse {
        let value = try decodeLine(CommandResponse.self, frame, limit: maximumResponseBytes)
        try value.validate(expectedID: expectedID)
        return value
    }

    private static func encodeLine<T: Encodable>(_ value: T, limit: Int) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(10)
        guard data.count <= limit else { throw CommandProtocolFailure.oversizedFrame }
        return data
    }

    private static func decodeLine<T: Decodable>(_ type: T.Type, _ frame: Data, limit: Int) throws -> T {
        guard frame.count <= limit else { throw CommandProtocolFailure.oversizedFrame }
        guard frame.last == 10, !frame.dropLast().contains(10), !frame.contains(13) else {
            throw CommandProtocolFailure.invalidFrame
        }
        guard String(data: frame, encoding: .utf8) != nil else { throw CommandProtocolFailure.malformedJSON }
        do { return try JSONDecoder().decode(type, from: frame.dropLast()) }
        catch { throw CommandProtocolFailure.malformedJSON }
    }
}
