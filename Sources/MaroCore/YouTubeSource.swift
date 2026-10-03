import Foundation

public enum SourceFailure: Error, Equatable, Sendable {
    case invalidQuery
    case invalidVideoID
    case malformedResponse
    case outputTooLarge
    case noCompatibleAudio
    case unsupportedRequestContext
}

/// Ephemeral and deliberately not Codable. AVFoundation must preflight each
/// candidate before the controller can replace the currently loaded video.
public struct AudioCandidate: Sendable {
    public let url: URL
    public let audioCodec: String
    public let bitrate: Double
    public let userAgent: String?
    public let isHLS: Bool

    public init(url: URL, audioCodec: String, bitrate: Double, userAgent: String?, isHLS: Bool = false) {
        self.url = url
        self.audioCodec = audioCodec
        self.bitrate = bitrate
        self.userAgent = userAgent
        self.isHLS = isHLS
    }
}

public struct ResolvedAudio: Sendable {
    public let video: VideoSummary
    public let candidates: [AudioCandidate]
}

/// Argument construction and decoding form the extractor-specific boundary.
/// Subprocess lifetime and AVFoundation readiness are separate responsibilities.
public enum YouTubeSource {
    public static let maximumOutputBytes = 8 * 1024 * 1024

    public static func searchArguments(query: String, nodeExecutable: URL) throws -> [String] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.utf8.count <= 512,
              !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw SourceFailure.invalidQuery }
        return baseArguments(nodeExecutable: nodeExecutable)
            + ["--flat-playlist", "--playlist-end", "20", "--", "ytsearch20:\(query)"]
    }

    public static func resolveArguments(videoID: String, nodeExecutable: URL) throws -> [String] {
        guard (try? VideoSummary(id: videoID, title: "Validation", creator: "")) != nil else {
            throw SourceFailure.invalidVideoID
        }
        return baseArguments(nodeExecutable: nodeExecutable)
            + ["--no-playlist", "--", "https://www.youtube.com/watch?v=\(videoID)"]
    }

    private static func baseArguments(nodeExecutable: URL) -> [String] {
        ["--ignore-config", "--no-plugin-dirs", "--no-remote-components", "--no-cache-dir", "--no-progress",
         "--skip-download", "--dump-single-json", "--socket-timeout", "15",
         "--retries", "0", "--extractor-retries", "0", "--no-js-runtimes",
         "--js-runtimes", "node:\(nodeExecutable.path)"]
    }

    public static func decodeSearch(_ data: Data) throws -> [VideoSummary] {
        let response: RawSearch = try decode(data)
        var results: [VideoSummary] = []
        var ids = Set<String>()
        for record in response.entries.prefix(20) {
            guard let record, let video = try? record.summary() else { continue }
            if ids.insert(video.id).inserted { results.append(video) }
        }
        if !response.entries.isEmpty && results.isEmpty { throw SourceFailure.malformedResponse }
        return results
    }

    public static func decodeResolution(_ data: Data, expectedVideoID: String) throws -> ResolvedAudio {
        let response: RawVideo = try decode(data)
        guard response.id == expectedVideoID else { throw SourceFailure.malformedResponse }
        let video: VideoSummary
        do { video = try response.summary() } catch { throw SourceFailure.malformedResponse }
        var unsupportedContext = false
        // HLS lets AVFoundation fetch short segments instead of a large progressive
        // range that YouTube may throttle. Extractor formats arrive worst-to-best.
        let candidates: [AudioCandidate] = (response.formats ?? []).reversed().compactMap { format in
            let isHLS = format.protocolName == "m3u8_native" && format.ext == "mp4"
            let codec = format.acodec ?? ""
            let supportedCodec = codec == "aac" || codec.hasPrefix("mp4a.40.")
            let bitrate = format.abr ?? format.tbr ?? 0
            guard format.vcodec == "none", format.hasDRM != true,
                  (isHLS && (codec.isEmpty || supportedCodec))
                    || (format.protocolName == "https" && format.ext == "m4a" && supportedCodec),
                  let rawURL = format.url, let url = URL(string: rawURL),
                  rawURL.utf8.count <= 32768,
                  url.scheme == "https", let host = url.host?.lowercased(),
                  host.hasSuffix(".googlevideo.com"),
                  url.port == nil || url.port == 443, url.user == nil, url.password == nil,
                  bitrate.isFinite, isHLS ? bitrate >= 0 : bitrate > 0
            else { return nil }

            // Extractor defaults are merged with per-format overrides. Only
            // User-Agent is forwarded through a documented AVURLAsset option.
            var headers: [String: String] = [:]
            for (key, value) in response.httpHeaders ?? [:] { headers[key.lowercased()] = value }
            for (key, value) in format.httpHeaders ?? [:] { headers[key.lowercased()] = value }
            let harmlessDefaults = [
                "accept": ["*/*", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"],
                "accept-language": ["en-us,en;q=0.5"], "sec-fetch-mode": ["navigate"]
            ]
            guard headers.allSatisfy({ key, value in
                value.utf8.count <= 4096
                    && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
                    && (key == "user-agent" || harmlessDefaults[key]?.contains(value.lowercased()) == true)
            }) else {
                unsupportedContext = true
                return nil
            }
            return AudioCandidate(url: url, audioCodec: codec, bitrate: bitrate,
                                  userAgent: headers["user-agent"], isHLS: isHLS)
        }.sorted {
            if $0.isHLS != $1.isHLS { return $0.isHLS }
            return $0.bitrate > $1.bitrate
        }
        guard !candidates.isEmpty else {
            throw unsupportedContext ? SourceFailure.unsupportedRequestContext : .noCompatibleAudio
        }
        return ResolvedAudio(video: video, candidates: candidates)
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        guard data.count <= maximumOutputBytes else { throw SourceFailure.outputTooLarge }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw SourceFailure.malformedResponse }
    }
}

private struct RawSearch: Decodable { let entries: [RawVideo?] }

private struct RawVideo: Decodable {
    let id: String?
    let title: String?
    let channel: String?
    let uploader: String?
    let duration: Double?
    let thumbnail: String?
    let thumbnails: [RawThumbnail]?
    let formats: [RawFormat]?
    let httpHeaders: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, title, channel, uploader, duration, thumbnail, thumbnails, formats
        case httpHeaders = "http_headers"
    }

    func summary() throws -> VideoSummary {
        guard let id, let title else { throw SourceFailure.malformedResponse }
        // Missing/bad artwork is nonfatal. Only Google's thumbnail CDN is fetched.
        let thumbnailURL = ([thumbnail].compactMap { $0 } + (thumbnails ?? []).compactMap(\.url))
            .compactMap(URL.init(string:)).first { url in
                url.scheme == "https" && (url.host == "i.ytimg.com" || url.host == "img.youtube.com")
                    && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
            }
        return try VideoSummary(id: id, title: title, creator: channel ?? uploader ?? "",
                                durationSeconds: duration, thumbnailURL: thumbnailURL)
    }
}

private struct RawThumbnail: Decodable { let url: String? }

private struct RawFormat: Decodable {
    let url: String?
    let ext: String?
    let acodec: String?
    let vcodec: String?
    let abr: Double?
    let tbr: Double?
    let protocolName: String?
    let httpHeaders: [String: String]?
    let hasDRM: Bool?

    enum CodingKeys: String, CodingKey {
        case url, ext, acodec, vcodec, abr, tbr
        case protocolName = "protocol"
        case httpHeaders = "http_headers"
        case hasDRM = "has_drm"
    }
}
