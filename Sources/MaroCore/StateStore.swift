import Foundation

public struct StateLoadResult: Sendable {
    public let document: StateDocument
    public let preservedFile: URL?
    public let warning: String?
}

/// Serializes disk work away from the main actor; stores only the durable projection.
public actor StateStore {
    public let file: URL
    private let maximumBytes = 1_048_576

    public init(file: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Maro/state.json")) {
        self.file = file
    }

    public func load() throws -> StateLoadResult {
        let data: Data
        do {
            // Read at most one byte beyond the limit; do not allocate an unbounded file.
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil)
        }
        let document: StateDocument
        do {
            guard data.count <= maximumBytes else { throw StateError.oversizedDocument }
            document = try JSONDecoder().decode(StateDocument.self, from: data)
            try document.validate()
        } catch {
            let backup = file.deletingLastPathComponent()
                .appendingPathComponent("state-unreadable-\(UUID().uuidString).json")
            // If preservation fails, throw rather than permitting an overwrite.
            try FileManager.default.moveItem(at: file, to: backup)
            return StateLoadResult(document: StateDocument(), preservedFile: backup,
                                   warning: "Local state could not be read; the original file was preserved.")
        }
        return StateLoadResult(document: document, preservedFile: nil, warning: nil)
    }

    public func save(_ document: StateDocument) throws {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumBytes else { throw StateError.oversizedDocument }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
