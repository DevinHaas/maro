import Foundation
import Testing
@testable import MaroCore

private func video(_ index: Int) throws -> VideoSummary {
    try VideoSummary(id: String(format: "%011d", index), title: "Track \(index)",
                     creator: "Creator", durationSeconds: 180)
}

@Test func favoritesAreBoundedOrderedAndNeverEvicted() throws {
    var state = StateDocument()
    for i in 0..<20 { try state.toggleFavorite(video(i)) }
    let full = state.favorites
    #expect(full.first?.id == (try video(19)).id)
    #expect(throws: StateError.favoritesFull) { try state.toggleFavorite(video(20)) }
    #expect(state.favorites == full)
    #expect(try state.toggleFavorite(video(5)) == false)
    #expect(state.favorites.count == 19)
    #expect(try state.toggleFavorite(video(5)) == true)
    #expect(state.favorites.first?.id == (try video(5)).id)
    state.removeFavorite(id: try video(5).id)
    try state.validate()
}

@Test func searchShowsTwentyFiveAndDeduplicatesContinuationPages() throws {
    let results = try (0..<25).map(video)
    var session = try SearchSession(query: "test", results: results, continuation: "25")
    #expect(session.visibleResults.count == 25)
    #expect(session.hasMore)
    try session.append(SearchPage(videos: [results[0]] + results, continuation: "50"))
    #expect(!session.hasMore)
    #expect(session.visibleResults.count == 25)
    let short = try SearchSession(query: "short", results: Array(results.prefix(3)))
    #expect(short.visibleResults.count == 3)
    #expect(!short.hasMore)
    #expect(try SearchSession(query: "empty", results: []).visibleResults.isEmpty)
}

@Test func untrustedMetadataAndPositionAreRejected() throws {
    #expect(throws: StateError.invalidVideo) {
        try VideoSummary(id: "../bad/path", title: "bad", creator: "")
    }
    #expect(throws: StateError.invalidVideo) {
        try VideoSummary(id: "01234567890", title: " ", creator: "")
    }
    #expect(throws: StateError.invalidVideo) {
        try VideoSummary(id: "01234567890", title: "bad", creator: "", durationSeconds: .infinity)
    }
    #expect(throws: StateError.invalidVideo) {
        try VideoSummary(id: "01234567890", title: "bad", creator: "",
                         thumbnailURL: URL(string: "file:///etc/passwd"))
    }
    #expect(throws: StateError.invalidPosition) {
        try LoadedVideo(video: video(0), positionSeconds: -1)
    }
}

private func temporaryFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("state.json")
}

@Test func atomicPersistenceRoundTripContainsOnlyDurableState() async throws {
    let file = try temporaryFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = StateStore(file: file)
    #expect(try await store.load().document == StateDocument())
    var state = StateDocument(loadedVideo: try LoadedVideo(video: video(1), positionSeconds: 42))
    try state.toggleFavorite(video(1))
    try await store.save(state)
    #expect(try await store.load().document == state)
    state.loadedVideo = try LoadedVideo(video: video(1), positionSeconds: 43)
    try await store.save(state)
    #expect(try await store.load().document == state)
    let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(Set(json.keys) == Set(["schemaVersion", "loadedVideo", "favorites"]))
    let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
}

@Test func corruptUnsupportedAndInvalidStateArePreserved() async throws {
    let file = try temporaryFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = StateStore(file: file)
    let cases = [
        "not json",
        #"{"schemaVersion":2,"favorites":[]}"#,
        #"{"schemaVersion":1,"favorites":[],"sourceDisabledBuild":""}"#,
        #"{"schemaVersion":1,"favorites":[],"loadedVideo":{"video":{"id":"01234567890","title":"x","creator":"y"},"positionSeconds":-1}}"#,
        #"{"schemaVersion":1,"favorites":[{"id":"bad","title":"x","creator":"y"}]}"#,
        String(repeating: "x", count: 1_048_577)
    ]
    for original in cases {
        try Data(original.utf8).write(to: file)
        let result = try await store.load()
        #expect(result.document == StateDocument())
        #expect(result.warning != nil)
        let preserved = try #require(result.preservedFile)
        #expect(try Data(contentsOf: preserved) == Data(original.utf8))
        #expect(!FileManager.default.fileExists(atPath: file.path))
        try await store.save(result.document)
        #expect(try Data(contentsOf: preserved) == Data(original.utf8))
    }
}

@Test func duplicatePersistedFavoritesAreRejected() throws {
    let item = try video(0)
    let data = try JSONEncoder().encode(item)
    let text = try #require(String(data: data, encoding: .utf8))
    let document = try JSONDecoder().decode(StateDocument.self, from:
        Data("{\"schemaVersion\":1,\"favorites\":[\(text),\(text)]}".utf8))
    #expect(throws: StateError.invalidFavorites) { try document.validate() }
}
