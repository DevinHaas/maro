import Foundation
import Testing
@testable import MaroCore

private let node = URL(fileURLWithPath: "/example path/node")
private let testID = "01234567890"

private func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

private func format(_ bitrate: Double = 128, changes: [String: Any] = [:]) -> [String: Any] {
    var result: [String: Any] = ["url": "https://rr1.example.googlevideo.com/videoplayback?expire=1",
        "ext": "m4a", "acodec": "mp4a.40.2", "vcodec": "none", "abr": bitrate, "protocol": "https"]
    result.merge(changes) { _, new in new }
    return result
}

private func resolution(_ formats: [[String: Any]], headers: [String: String] = [:]) throws -> Data {
    try json(["id": testID, "title": "Track", "uploader": "Creator", "duration": 42,
              "formats": formats, "http_headers": headers])
}

@Test func extractorArgumentsKeepUserInputLiteralAndBoundRequests() throws {
    let query = "  --exec $(touch /tmp/nope); music  "
    let args = try YouTubeSource.searchArguments(query: query, nodeExecutable: node)
    #expect(args.suffix(2) == ["--", "ytsearch25:--exec $(touch /tmp/nope); music"])
    #expect(args.contains("node:/example path/node"))
    #expect(args.contains("--ignore-config"))
    #expect(args.contains("--skip-download"))
    #expect(!args.contains("--exec"))
    #expect(throws: SourceFailure.invalidQuery) { try YouTubeSource.searchArguments(query: " \n", nodeExecutable: node) }
    #expect(throws: SourceFailure.invalidQuery) { try YouTubeSource.searchArguments(query: String(repeating: "a", count: 513), nodeExecutable: node) }
    #expect(throws: SourceFailure.invalidVideoID) { try YouTubeSource.resolveArguments(videoID: "--exec=bad", nodeExecutable: node) }
    #expect(try YouTubeSource.resolveArguments(videoID: testID, nodeExecutable: node).last == "https://www.youtube.com/watch?v=01234567890")
}

@Test func searchNormalizesBoundsAndIgnoresInvalidArtwork() throws {
    var entries: [[String: Any]] = (0..<25).map {
        ["id": String(format: "%011d", $0), "title": "Track \($0)", "uploader": "Creator",
         "thumbnail": "https://localhost/private"]
    }
    entries[1] = entries[0]
    let videos = try YouTubeSource.decodeSearch(json(["entries": entries]))
    #expect(videos.count == 24)
    #expect(videos.first?.creator == "Creator")
    #expect(videos.allSatisfy { $0.thumbnailURL == nil })
    #expect(try YouTubeSource.decodeSearch(json(["entries": []])).isEmpty)
    #expect(throws: SourceFailure.malformedResponse) {
        try YouTubeSource.decodeSearch(json(["entries": [["id": "channel", "title": "bad"]]]))
    }
}

@Test func sourceRejectsMalformedOversizedAndWrongIdentity() throws {
    #expect(throws: SourceFailure.malformedResponse) { try YouTubeSource.decodeSearch(Data("broken".utf8)) }
    #expect(throws: SourceFailure.outputTooLarge) {
        try YouTubeSource.decodeSearch(Data(repeating: 0, count: YouTubeSource.maximumOutputBytes + 1))
    }
    #expect(throws: SourceFailure.malformedResponse) {
        try YouTubeSource.decodeResolution(resolution([format()]), expectedVideoID: "otherID1234")
    }
}

@Test func audioCandidatesAreAudioOnlyAndSortedByQuality() throws {
    let resolved = try YouTubeSource.decodeResolution(resolution([
        format(96), format(256), format(512, changes: ["vcodec": "avc1"]),
        format(512, changes: ["ext": "webm", "acodec": "opus"]),
        format(512, changes: ["has_drm": true]), format(512, changes: ["protocol": "m3u8_native"]),
        format(512, changes: ["acodec": "mp4a.6b"])
    ]), expectedVideoID: testID)
    #expect(resolved.candidates.map(\.bitrate) == [256, 96])
    #expect(resolved.video.creator == "Creator")
    #expect(throws: SourceFailure.noCompatibleAudio) {
        try YouTubeSource.decodeResolution(resolution([format(changes: ["vcodec": "avc1"])]), expectedVideoID: testID)
    }
}

@Test func sourceRejectsUnsafeMediaURLsAndRequiredHeaders() throws {
    for url in ["http://rr.googlevideo.com/audio", "https://googlevideo.com.evil.test/audio",
                "https://localhost/audio", "file:///etc/passwd", "https://user:pass@rr.googlevideo.com/audio"] {
        #expect(throws: SourceFailure.noCompatibleAudio) {
            try YouTubeSource.decodeResolution(resolution([format(changes: ["url": url])]), expectedVideoID: testID)
        }
    }
    for headers in [["Authorization": "secret"], ["Cookie": "session=secret"], ["User-Agent": "bad\r\ninjection"]] {
        #expect(throws: SourceFailure.unsupportedRequestContext) {
            try YouTubeSource.decodeResolution(resolution([format()], headers: headers), expectedVideoID: testID)
        }
    }
    let resolved = try YouTubeSource.decodeResolution(resolution([
        format(changes: ["http_headers": ["user-agent": "format agent"]])
    ], headers: ["User-Agent": "global agent",
                 "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                 "Accept-Language": "en-us,en;q=0.5",
                 "Sec-Fetch-Mode": "navigate"]), expectedVideoID: testID)
    #expect(resolved.candidates.first?.userAgent == "format agent")
}

@Test func audioOnlyHLSPrefersNativeSegmentsAndKeepsProgressiveFallback() throws {
    let hls: [String: Any] = ["url": "https://manifest.googlevideo.com/api/manifest/hls/test",
        "protocol": "m3u8_native", "ext": "mp4", "vcodec": "none"]
    var video = hls
    video["vcodec"] = "avc1"
    var drm = hls
    drm["has_drm"] = true
    var unsafe = hls
    unsafe["url"] = "https://localhost/manifest"
    let resolved = try YouTubeSource.decodeResolution(resolution([format(), hls, video, drm, unsafe]), expectedVideoID: testID)
    #expect(resolved.candidates.count == 2)
    #expect(resolved.candidates[0].isHLS)
    #expect(resolved.candidates[0].audioCodec.isEmpty, "Native HLS checks manifest compatibility when codec metadata is absent")
    #expect(!resolved.candidates[1].isHLS)
}
