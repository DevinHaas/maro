import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MaroCore

private func artworkFixture(width: Int = 640) throws -> Data {
    let context = try #require(CGContext(data: nil, width: width, height: 2, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try #require(context.makeImage())
    let output = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
}

private func artworkVideo(_ id: Int = 1, url: String = "https://i.ytimg.com/vi/abcdefghijk/default.jpg") throws -> VideoSummary {
    try VideoSummary(id: String(format: "%011d", id), title: "Fixture", creator: "Test", thumbnailURL: URL(string: url))
}

@Test @MainActor func controllerPublishesOnlyExistingArtworkAndRepairsCacheLoss() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try artworkFixture()
    let cache = ArtworkCache(directory: directory.appendingPathComponent("Artwork"), fetch: { _ in data })
    let video = try artworkVideo()
    let file = directory.appendingPathComponent("state.json")
    let controller = try MaroController(
        loaded: StateLoadResult(document: StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 2)),
            preservedFile: nil, warning: nil),
        store: StateStore(file: file), engine: PlaybackEngine(), artworkCache: cache,
        search: { _ in [] }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
    func waitForArtwork() async throws -> String {
        for _ in 0..<100 {
            if let path = controller.snapshot.localThumbnailPaths?[video.id] { return path }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw URLError(.timedOut)
    }
    let path = try await waitForArtwork()
    #expect(controller.snapshot.playback == .paused)
    try CommandResponse(id: "artwork", snapshot: controller.snapshot).validate(expectedID: "artwork")
    try FileManager.default.removeItem(atPath: path)
    #expect(controller.snapshot.localThumbnailPaths?[video.id] == nil)
    controller.refreshArtwork()
    #expect(try await waitForArtwork() == path)
    await controller.shutdown()
    let persisted = try String(contentsOf: file, encoding: .utf8)
    #expect(!persisted.contains("localThumbnailPaths"))
    #expect(!persisted.contains(directory.path))
}

@Test func artworkNormalizesCachesAndRepairsCorruption() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try artworkFixture()
    let cache = ArtworkCache(directory: directory, fetch: { _ in data })
    let file = try #require(await cache.image(for: artworkVideo()))
    let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
    #expect(CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString)
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 320)
    let offline = ArtworkCache(directory: directory, fetch: { _ in throw URLError(.notConnectedToInternet) })
    #expect(await offline.image(for: try artworkVideo()) == file)
    try Data("corrupt".utf8).write(to: file)
    #expect(await offline.image(for: try artworkVideo()) == nil)
    #expect(await cache.image(for: try artworkVideo()) == file)
}

@Test func artworkRejectsUnsafeURLsOversizedAndInvalidImages() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let forbidden = ArtworkCache(directory: directory, fetch: { _ in Issue.record("Unsafe URL fetched"); return Data() })
    #expect(await forbidden.image(for: try artworkVideo(url: "https://example.com/image.jpg")) == nil)
    for url in ["http://i.ytimg.com/a", "https://i.ytimg.com:444/a", "https://user@i.ytimg.com/a", "https://i.ytimg.com.evil.test/a"] {
        #expect(!ArtworkCache.allowedURL(URL(string: url)!))
    }
    for data in [Data("not an image".utf8), Data(repeating: 0, count: ArtworkCache.maximumBytes + 1), try artworkFixture(width: 4097)] {
        let cache = ArtworkCache(directory: directory, fetch: { _ in data })
        #expect(await cache.image(for: try artworkVideo()) == nil)
    }
}

@Test func artworkBoundsDiskGrowthAndPreservesUnrelatedFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try artworkFixture()
    let cache = ArtworkCache(directory: directory, fetch: { _ in data })
    _ = await cache.image(for: try artworkVideo())
    let unrelated = directory.appendingPathComponent("keep.txt")
    try Data("keep".utf8).write(to: unrelated)
    for id in 2...102 { _ = await cache.image(for: try artworkVideo(id)) }
    let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(files.filter { $0.hasSuffix(".jpg") }.count == 100)
    #expect(try Data(contentsOf: unrelated) == Data("keep".utf8))
    let blocked = ArtworkCache(directory: unrelated, fetch: { _ in data })
    #expect(await blocked.image(for: try artworkVideo()) == nil)
}
