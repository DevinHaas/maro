import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor ArtworkCache {
    static let maximumBytes = 2_097_152
    private let directory: URL
    private let fetch: @Sendable (URL) async throws -> Data

    public init(directory: URL) {
        self.directory = directory
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: ArtworkRedirects(), delegateQueue: nil)
        fetch = { url in
            let (bytes, response) = try await session.bytes(from: url)
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.expectedContentLength <= Self.maximumBytes,
                  response.url.map(Self.allowedURL) == true else { throw ArtworkFailure.invalidImage }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < Self.maximumBytes else { throw ArtworkFailure.invalidImage }
                data.append(byte)
            }
            return data
        }
    }

    init(directory: URL, fetch: @escaping @Sendable (URL) async throws -> Data) {
        self.directory = directory; self.fetch = fetch
    }

    /// Only returns existing normalized files. Cache failure is never playback failure.
    public func image(for video: VideoSummary) async -> URL? {
        do {
            try video.validate()
            try Task.checkCancellation()
            let file = directory.appendingPathComponent(video.id + ".jpg")
            if let handle = try? FileHandle(forReadingFrom: file) {
                defer { try? handle.close() }
                if let data = try handle.read(upToCount: Self.maximumBytes + 1),
                   (try? Self.normalized(data)) != nil {
                    try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
                    return file
                }
            }
            guard let url = video.thumbnailURL, Self.allowedURL(url) else { return nil }
            let downloaded = try await fetch(url)
            try Task.checkCancellation()
            let image = try Self.normalized(downloaded)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try image.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            try trim()
            return FileManager.default.fileExists(atPath: file.path) ? file : nil
        } catch { return nil }
    }

    nonisolated static func allowedURL(_ url: URL) -> Bool {
        url.scheme == "https" && ["i.ytimg.com", "img.youtube.com"].contains(url.host ?? "")
            && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
            && url.absoluteString.utf8.count <= 8192
    }

    private static func normalized(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 4096, height <= 4096,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320
              ] as CFDictionary) else { throw ArtworkFailure.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ArtworkFailure.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= maximumBytes else { throw ArtworkFailure.invalidImage }
        return output as Data
    }

    private func trim() throws {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
            .filter { $0.pathExtension == "jpg" && (try? VideoSummary(id: $0.deletingPathExtension().lastPathComponent,
                title: "Validation", creator: "")) != nil }
            .compactMap { url -> (URL, Int, Date)? in
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true,
                      values.isSymbolicLink != true else { return nil }
                return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
            }.sorted { $0.2 > $1.2 }
        var bytes = 0
        for (index, entry) in files.enumerated() {
            bytes += entry.1
            if index >= 100 || bytes > 20 * 1_048_576 { try FileManager.default.removeItem(at: entry.0) }
        }
    }
}

private enum ArtworkFailure: Error { case invalidImage }

private final class ArtworkRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(request.url.map(ArtworkCache.allowedURL) == true ? request : nil)
    }
}
