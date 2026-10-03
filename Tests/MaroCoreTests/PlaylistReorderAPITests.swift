import Foundation
import Testing
@testable import MaroCore

@Test @MainActor func unreadableMoveResponseRequiresRefreshAndNeverRetries() async throws {
    let api = YouTubePlaylists(token: { "fixture" }, send: { request in
        (Data("not-json".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    })
    let item = YouTubePlaylistItem(id: "occ", video: nil, title: "Private video", resourceVideoID: "abcdefghijk")
    do {
        try await api.move(item, in: "PLone", to: 0)
        Issue.record("Unreadable transmitted write must remain unconfirmed")
    } catch let error as YouTubeWriteError { #expect(error.outcome == .ambiguous) }
}

private actor MoveRequests {
    var requests: [URLRequest] = []
    func respond(_ request: URLRequest, status: Int) -> (Data, URLResponse) {
        requests.append(request)
        return (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func unavailableOccurrenceMoveSendsOneAuthenticatedMetadataPreservingPositionUpdate() async throws {
    let requests = MoveRequests()
    let api = YouTubePlaylists(token: { "fixture-token" }, send: { await requests.respond($0, status: 200) })
    let item = YouTubePlaylistItem(id: "occDuplicate", video: nil, title: "Private video",
        addedAt: Date(timeIntervalSince1970: 1_700_000_000), resourceVideoID: "abcdefghijk")
    try await api.move(item, in: "PLone", to: 7)
    let sent = await requests.requests
    #expect(sent.count == 1)
    let request = try #require(sent.first)
    #expect(request.httpMethod == "PUT")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token")
    #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "part" }?.value == "snippet")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["id"] as? String == "occDuplicate")
    let snippet = try #require(json["snippet"] as? [String: Any])
    #expect(snippet["position"] as? Int == 7)
    #expect(snippet["playlistId"] as? String == "PLone")
    #expect((snippet["resourceId"] as? [String: String])?["videoId"] == "abcdefghijk")
    #expect(snippet["publishedAt"] == nil)
    #expect(json["contentDetails"] == nil)
}

@Test(arguments: [403, 404, 500, 503]) @MainActor func moveResponseDistinguishesRejectedAndUnconfirmedOutcomes(status: Int) async throws {
    let requests = MoveRequests()
    let api = YouTubePlaylists(token: { "fixture" }, send: { await requests.respond($0, status: status) })
    let item = YouTubePlaylistItem(id: "occ", video: nil, title: "Private video", resourceVideoID: "abcdefghijk")
    do { try await api.move(item, in: "PLone", to: 0); Issue.record("Expected classified write failure") }
    catch let error as YouTubeWriteError { #expect(error.outcome == (status >= 500 ? .ambiguous : .rejected)) }
    #expect(await requests.requests.count == 1)
}

@Test @MainActor func expiredTokenRejectsMoveBeforeTransmittingAnything() async throws {
    let requests = MoveRequests()
    let api = YouTubePlaylists(token: { throw YouTubeAccountError("Expired token") }, send: { await requests.respond($0, status: 200) })
    let item = YouTubePlaylistItem(id: "occ", video: nil, title: "Private video", resourceVideoID: "abcdefghijk")
    do { try await api.move(item, in: "PLone", to: 0); Issue.record("Expected rejected preflight") }
    catch let error as YouTubeWriteError { #expect(error.outcome == .rejected) }
    #expect(await requests.requests.isEmpty)
}
