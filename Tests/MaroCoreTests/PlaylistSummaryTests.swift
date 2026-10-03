import Foundation
import Testing
@testable import MaroCore

@Test @MainActor func ownedPlaylistSummariesIncludeArtworkOwnerDescriptionPrivacyAcrossPages() async throws {
    let api = YouTubePlaylists(token: { "fixture" }, send: { request in
        let url = request.url!
        let second = url.query!.contains("pageToken=second")
        let body = second
            ? #"{"items":[{"id":"PLtwo","snippet":{"title":"Second"},"contentDetails":{"itemCount":0}}]}"#
            : #"{"items":[{"id":"PLone","snippet":{"title":"Piano","description":"Quiet afternoons","channelTitle":"My channel","thumbnails":{"medium":{"url":"https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg"}}},"status":{"privacyStatus":"private"},"contentDetails":{"itemCount":12}}],"nextPageToken":"second"}"#
        #expect(url.query!.contains("status"))
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    })
    let playlists = try await api.playlists()
    #expect(playlists.map(\.id) == ["PLone", "PLtwo"])
    #expect(playlists[0].description == "Quiet afternoons")
    #expect(playlists[0].owner == "My channel")
    #expect(playlists[0].privacy == "private")
    #expect(playlists[0].thumbnailURL?.absoluteString == "https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg")
    #expect(playlists[1].thumbnailURL == nil)
    #expect(playlists[1].owner == nil)
}
