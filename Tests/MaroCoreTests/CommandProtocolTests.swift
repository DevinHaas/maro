import Foundation
import Testing
@testable import MaroCore

@Test func commandArgumentsAndRequestsRoundTrip() throws {
    let videoID = "abcdefghijk"
    let cases: [([String], CommandName, String?)] = [
        (["status"], .status, nil), (["search"], .search, nil),
        (["player"], .player, nil),
        (["toggle"], .toggle, nil), (["replay"], .replay, nil),
        (["previous"], .previous, nil), (["next"], .next, nil),
        (["select", videoID], .select, videoID),
        (["favorite", "toggle", videoID], .favoriteToggle, videoID),
        (["favorite", "remove", videoID], .favoriteRemove, videoID)
    ]
    for (arguments, command, expectedVideo) in cases {
        let request = try CommandRequest.arguments(arguments, id: "42")
        #expect(request.command == command)
        #expect(request.videoID == expectedVideo)
        let frame = try CommandWire.encode(request)
        #expect(frame.last == 10)
        #expect(try CommandWire.request(frame) == request)
    }
    for invalid in [[], ["next", "extra"], ["toggle", "extra"], ["favorite"],
                    ["favorite", "clear", videoID], ["select", "$(touch bad)"],
                    ["search", "query"], ["favorite_toggle", videoID]] {
        #expect(throws: (any Error).self) { try CommandRequest.arguments(invalid) }
    }
}

@Test func commandFramesRejectMalformedOversizedAndUnsupportedRequests() throws {
    let valid = Data("{\"version\":1,\"id\":\"42\",\"command\":\"status\"}\n".utf8)
    #expect(throws: CommandProtocolFailure.invalidFrame) { try CommandWire.request(valid.dropLast()) }
    #expect(throws: CommandProtocolFailure.invalidFrame) { try CommandWire.request(valid + valid) }
    #expect(throws: CommandProtocolFailure.oversizedFrame) {
        try CommandWire.request(Data(repeating: 32, count: CommandWire.maximumRequestBytes + 1))
    }
    #expect(throws: CommandProtocolFailure.malformedJSON) { try CommandWire.request(Data([255, 10])) }
    #expect(throws: CommandProtocolFailure.malformedJSON) { try CommandWire.request(Data("{}\n".utf8)) }
    let invalid: [(String, CommandProtocolFailure)] = [
        (#"{"version":2,"id":"42","command":"status"}"#, .unsupportedVersion),
        (#"{"version":1,"id":"","command":"status"}"#, .invalidID),
        (#"{"version":1,"id":"bad\nid","command":"status"}"#, .invalidID),
        (#"{"version":1,"id":"42","command":"select"}"#, .invalidPayload),
        (#"{"version":1,"id":"42","command":"status","videoID":"abcdefghijk"}"#, .invalidPayload),
        (#"{"version":1,"id":"42","command":"unknown"}"#, .malformedJSON)
    ]
    for (json, failure) in invalid {
        #expect(throws: failure) { try CommandWire.request(Data((json + "\n").utf8)) }
    }
    #expect(throws: CommandProtocolFailure.invalidID) {
        try CommandRequest(id: String(repeating: "x", count: 65), command: .status)
    }
}

@Test func responseRequiresMatchingIDAndCoherentSuccessOrError() throws {
    let video = try VideoSummary(id: "abcdefghijk", title: "A \"quoted\"\ntrack", creator: "Creator")
    let snapshot = PlayerSnapshot(loadedVideo: try LoadedVideo(video: video, positionSeconds: 12),
        favorites: [video], playback: .paused, isSelecting: false, sourceNeedsUpdate: false,
        error: nil, persistenceError: nil)
    let frame = try CommandWire.encode(CommandResponse(id: "42", snapshot: snapshot))
    #expect(frame.filter { $0 == 10 }.count == 1)
    let response = try CommandWire.response(frame, expectedID: "42")
    #expect(response.ok)
    #expect(response.state == .paused)
    #expect(response.snapshot?.loadedVideo?.positionSeconds == 12)
    #expect(response.snapshot?.favorites == [video])
    #expect(throws: CommandProtocolFailure.mismatchedResponse) {
        try CommandWire.response(frame, expectedID: "43")
    }
    let error = CommandError(code: .videoUnavailable, message: "No usable audio source")
    let failure = try CommandWire.encode(CommandResponse(id: "43", error: error))
    #expect(try CommandWire.response(failure, expectedID: "43").error == error)
    for json in [
        #"{"version":1,"id":"42","ok":true,"state":"paused"}"#,
        #"{"version":1,"id":"42","ok":false}"#,
        #"{"version":1,"id":"42","ok":false,"state":"playing","error":{"code":"superseded","message":"Old request"}}"#
    ] {
        #expect(throws: CommandProtocolFailure.invalidPayload) {
            try CommandWire.response(Data((json + "\n").utf8), expectedID: "42")
        }
    }
}

@Test func commandResponseFiltersArtworkForUnrelatedDiscoveredVideos() throws {
    let loaded = try VideoSummary(id: "abcdefghijk", title: "Loaded", creator: "Creator")
    let favorite = try VideoSummary(id: "lmnopqrstuv", title: "Favorite", creator: "Creator")
    let discovered = "zyxwvutsrqp"
    let snapshot = PlayerSnapshot(loadedVideo: try LoadedVideo(video: loaded, positionSeconds: 0),
        favorites: [favorite], playback: .paused, isSelecting: false, sourceNeedsUpdate: false,
        error: nil, persistenceError: nil,
        localThumbnailPaths: [loaded.id: "/tmp/\(loaded.id).jpg", favorite.id: "/tmp/\(favorite.id).jpg",
                             discovered: "/tmp/\(discovered).jpg"])

    let responseSnapshot = snapshot.commandResponseSnapshot()
    #expect(snapshot.localThumbnailPaths?[discovered] == "/tmp/\(discovered).jpg")
    #expect(responseSnapshot.localThumbnailPaths?.keys.sorted() == [loaded.id, favorite.id].sorted())

    let frame = try CommandWire.encode(CommandResponse(id: "42", snapshot: responseSnapshot))
    let response = try CommandWire.response(frame, expectedID: "42")
    #expect(response.snapshot?.localThumbnailPaths?.keys.sorted() == [loaded.id, favorite.id].sorted())
}
