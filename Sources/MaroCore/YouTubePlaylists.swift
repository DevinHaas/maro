import Foundation

public struct YouTubePlaylist: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let count: Int
    public let thumbnailURL: URL?
    public let description: String?
    public let owner: String?
    public let privacy: String?

    public init(id: String, title: String, count: Int, thumbnailURL: URL? = nil,
                description: String? = nil, owner: String? = nil, privacy: String? = nil) {
        self.id = id; self.title = title; self.count = count
        self.thumbnailURL = thumbnailURL; self.description = description
        self.owner = owner; self.privacy = privacy
    }
}

/// The item ID identifies an occurrence: a playlist can contain a video twice.
public struct YouTubePlaylistItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let video: VideoSummary?
    public let title: String
    public let addedAt: Date?
    /// Resource identity is retained even when YouTube marks the video unavailable.
    public let resourceVideoID: String?

    public init(id: String, video: VideoSummary?, title: String, addedAt: Date? = nil, resourceVideoID: String? = nil) {
        self.id = id; self.video = video; self.title = title
        self.addedAt = addedAt; self.resourceVideoID = resourceVideoID ?? video?.id
    }
}

public struct YouTubeAccountError: LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

@MainActor
public final class YouTubePlaylists {
    private let token: () async throws -> String
    private let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private var adding: Set<String> = []

    public init(token: @escaping () async throws -> String,
                send: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
                    try await URLSession.shared.data(for: $0)
                }) {
        self.token = token; self.send = send
    }

    public func playlists() async throws -> [YouTubePlaylist] {
        try await pages("playlists", query: ["part": "snippet,contentDetails,status", "mine": "true"]).map { row in
            guard let id = row["id"] as? String,
                  let snippet = row["snippet"] as? [String: Any], let title = snippet["title"] as? String else {
                throw YouTubeAccountError("YouTube returned an incomplete playlist. Refresh to try again.")
            }
            let thumbnails = snippet["thumbnails"] as? [String: [String: Any]] ?? [:]
            let thumbnail = ["high", "medium", "default"].compactMap { thumbnails[$0]?["url"] as? String }.first
            return YouTubePlaylist(id: id, title: title,
                count: (row["contentDetails"] as? [String: Any])?["itemCount"] as? Int ?? 0,
                thumbnailURL: thumbnail.flatMap(URL.init(string:)), description: snippet["description"] as? String,
                owner: snippet["channelTitle"] as? String, privacy: (row["status"] as? [String: String])?["privacyStatus"])
        }
    }

    public func items(in playlist: String) async throws -> [YouTubePlaylistItem] {
        try validID(playlist)
        return try await pages("playlistItems", query: ["part": "snippet", "playlistId": playlist]).map { row in
            guard let id = row["id"] as? String, let snippet = row["snippet"] as? [String: Any] else {
                throw YouTubeAccountError("YouTube returned an incomplete playlist entry. Refresh to try again.")
            }
            let title = snippet["title"] as? String ?? "Unavailable video"
            let videoID = (snippet["resourceId"] as? [String: Any])?["videoId"] as? String ?? ""
            let thumbnail = ((snippet["thumbnails"] as? [String: Any])?["medium"] as? [String: Any])?["url"] as? String
            let unavailable = title == "Private video" || title == "Deleted video"
            let video = unavailable ? nil : try? VideoSummary(id: videoID, title: title,
                creator: snippet["videoOwnerChannelTitle"] as? String ?? "",
                thumbnailURL: thumbnail.flatMap(URL.init(string:)))
            let addedAt = (snippet["publishedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            return YouTubePlaylistItem(id: id, video: video, title: title, addedAt: addedAt,
                resourceVideoID: videoID.isEmpty ? nil : videoID)
        }
    }

    @discardableResult
    public func create(title: String) async throws -> YouTubePlaylist {
        let title = try validTitle(title)
        let response = try await request("playlists", method: "POST", query: ["part": "snippet,status"],
            body: ["snippet": ["title": title], "status": ["privacyStatus": "private"]])
        guard let id = response["id"] as? String else {
            throw YouTubeAccountError("YouTube saved the playlist but returned no identifier. Refresh before creating it again.")
        }
        try validID(id)
        return YouTubePlaylist(id: id, title: (response["snippet"] as? [String: Any])?["title"] as? String ?? title, count: 0)
    }

    public func delete(_ playlist: String) async throws {
        try validID(playlist)
        _ = try await request("playlists", method: "DELETE", query: ["id": playlist])
    }

    public func rename(_ playlist: String, title: String) async throws {
        try validID(playlist)
        let title = try validTitle(title)
        // YouTube replaces writable snippet fields. Preserve the description and language.
        let response = try await request("playlists", query: ["part": "snippet", "id": playlist])
        guard let first = (response["items"] as? [[String: Any]])?.first,
              let old = first["snippet"] as? [String: Any] else {
            throw YouTubeAccountError("This playlist no longer exists or cannot be accessed.")
        }
        var snippet: [String: Any] = ["title": title, "description": old["description"] as? String ?? ""]
        if let language = old["defaultLanguage"] as? String { snippet["defaultLanguage"] = language }
        _ = try await request("playlists", method: "PUT", query: ["part": "snippet"],
            body: ["id": playlist, "snippet": snippet])
    }

    public func add(_ video: VideoSummary, to playlist: String) async throws {
        try video.validate(); try validID(playlist)
        let key = playlist + ":" + video.id
        guard adding.insert(key).inserted else {
            throw YouTubeAccountError("This video is already being added to this playlist.")
        }
        defer { adding.remove(key) }
        // Compare YouTube identities, including unavailable entries and later pages.
        let existing = try await pages("playlistItems", query: ["part": "snippet", "playlistId": playlist])
        guard !existing.contains(where: {
            let snippet = $0["snippet"] as? [String: Any]
            return (snippet?["resourceId"] as? [String: Any])?["videoId"] as? String == video.id
        }) else { throw YouTubeAccountError("This video is already in this playlist.") }
        _ = try await request("playlistItems", method: "POST", query: ["part": "snippet"],
            body: ["snippet": ["playlistId": playlist,
                "resourceId": ["kind": "youtube#video", "videoId": video.id]]])
    }

    public func remove(_ item: YouTubePlaylistItem) async throws {
        try validID(item.id)
        _ = try await request("playlistItems", method: "DELETE", query: ["id": item.id])
    }

    public func move(_ item: YouTubePlaylistItem, in playlist: String, to position: Int) async throws {
        try validID(item.id); try validID(playlist)
        guard position >= 0, let video = item.video else {
            throw YouTubeAccountError("This unavailable entry cannot be reordered. You can remove it instead.")
        }
        _ = try await request("playlistItems", method: "PUT", query: ["part": "snippet"], body: [
            "id": item.id, "snippet": ["playlistId": playlist, "position": position,
                "resourceId": ["kind": "youtube#video", "videoId": video.id]]])
    }

    private func pages(_ path: String, query: [String: String]) async throws -> [[String: Any]] {
        var query = query
        query["maxResults"] = "50"
        var rows: [[String: Any]] = []
        var seen = Set<String>()
        repeat {
            try Task.checkCancellation()
            let response = try await request(path, query: query)
            guard let items = response["items"] as? [[String: Any]] else {
                throw YouTubeAccountError("YouTube returned an unreadable response. Refresh to try again.")
            }
            rows += items
            guard let next = response["nextPageToken"] as? String, !next.isEmpty else { return rows }
            guard seen.insert(next).inserted else { throw YouTubeAccountError("YouTube repeated a page. Refresh to try again.") }
            query["pageToken"] = next
        } while true
    }

    private func request(_ path: String, method: String = "GET", query: [String: String],
                         body: [String: Any]? = nil) async throws -> [String: Any] {
        var url = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(path)")!
        url.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 30
        request.httpMethod = method
        request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await send(request)
        guard let response = response as? HTTPURLResponse else { throw YouTubeAccountError("No response from YouTube.") }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(response.statusCode) else {
            let reason = (((json["error"] as? [String: Any])?["errors"] as? [[String: Any]])?.first)?["reason"] as? String
            switch reason {
            case "quotaExceeded", "dailyLimitExceeded": throw YouTubeAccountError("YouTube's daily API allowance is exhausted. Try again tomorrow.")
            case "manualSortRequired": throw YouTubeAccountError("Set this playlist's ordering to Manual on YouTube, then retry.")
            default: break
            }
            switch response.statusCode {
            case 401: throw YouTubeAccountError("Your Google connection has expired. Connect YouTube again.")
            case 403: throw YouTubeAccountError("YouTube denied access. Check that the API is enabled and you granted editing access to your own playlists.")
            case 404: throw YouTubeAccountError("This playlist or video is no longer available. Refresh the list.")
            default: throw YouTubeAccountError("YouTube could not complete the request (\(response.statusCode)). Refresh before retrying an edit.")
            }
        }
        return json
    }

    private func validID(_ id: String) throws {
        guard !id.isEmpty, id.utf8.count <= 256,
              id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            throw YouTubeAccountError("Invalid playlist or entry identifier.")
        }
    }

    private func validTitle(_ title: String) throws -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 150 else { throw YouTubeAccountError("Enter a playlist name of 1–150 characters.") }
        return title
    }
}
