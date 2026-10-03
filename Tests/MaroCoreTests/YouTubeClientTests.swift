import AVFoundation
import Foundation
import Testing
@testable import MaroCore

@Test func failureClassificationDoesNotTreatEveryErrorAsSourceDrift() {
    for (text, expected) in [
        ("Sign in to confirm you're not a bot; signature extraction failed", ExtractorFailure.accessRestricted),
        ("Connection timed out; nsig extraction failed", .network),
        ("Video unavailable", .videoUnavailable),
        ("No supported JavaScript runtime could be found", .runtimeUnavailable),
        ("Signature extraction failed", .sourceNeedsUpdate),
        ("unknown error https://signed.example/secret", .failed)
    ] {
        let error = ExtractorFailure.classify(stderr: Data(text.utf8))
        #expect(error == expected)
        #expect(!error.message.contains("secret"))
    }
}

@Test func clientReportsMissingDependencyWithoutLaunching() async throws {
    let client = YouTubeClient(executable: URL(fileURLWithPath: "/missing-maro-extractor"),
                               nodeExecutable: URL(fileURLWithPath: "/missing-maro-node"))
    do {
        _ = try await client.search("music")
        Issue.record("Expected a missing dependency")
    } catch { #expect(error as? ExtractorFailure == .dependencyMissing) }
}

// Explicit opt-in: network-dependent evidence is separate from deterministic tests.
@Test(.enabled(if: ProcessInfo.processInfo.environment["MARO_LIVE_EXTRACTOR"] != nil))
func liveAnonymousSearchAndAssetPreflight() async throws {
    let env = ProcessInfo.processInfo.environment
    let path = try #require(env["MARO_LIVE_EXTRACTOR"])
    let client = YouTubeClient(executable: URL(fileURLWithPath: path),
        nodeExecutable: URL(fileURLWithPath: env["MARO_LIVE_NODE"] ?? "/opt/homebrew/bin/node"))
    let videos = try await client.search("Bach cello suite no 1")
    #expect(!videos.isEmpty)
    print("Live anonymous search normalized \(videos.count) videos.")
    let video = try #require(videos.first)
    let resolved = try await client.resolve(videoID: video.id)
    print("Live resolution returned \(resolved.candidates.count) audio-only candidates.")
    let candidateIndex = Int(env["MARO_LIVE_CANDIDATE"] ?? "0") ?? 0
    try #require(resolved.candidates.indices.contains(candidateIndex))
    let candidate = resolved.candidates[candidateIndex]
    print("Candidate \(candidateIndex): codec=\(candidate.audioCodec), bitrate=\(candidate.bitrate)")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 20
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: candidate.url)
    request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
    if let agent = candidate.userAgent { request.setValue(agent, forHTTPHeaderField: "User-Agent") }
    do {
        let (bytes, response) = try await session.bytes(for: request)
        let http = try #require(response as? HTTPURLResponse)
        var count = 0
        for try await _ in bytes {
            count += 1
            if count == 1024 { break }
        }
        print("Media byte-range probe: HTTP \(http.statusCode), bytes sampled=\(count)")
        guard (200..<300).contains(http.statusCode), count > 0 else {
            Issue.record("Media transport/access failed before AVFoundation preflight")
            return
        }
    } catch {
        let failure = error as NSError
        print("Media transport failure domain=\(failure.domain), code=\(failure.code)")
        Issue.record("Media byte-range probe failed; codec compatibility remains untested")
        return
    }
    do {
        _ = try await AudioAssetLoader.prepare(candidate)
        print("AVFoundation candidate \(candidateIndex) is playable. This is preflight, not a listening-session result.")
    } catch {
        if let failure = error as? AudioPreparationFailure { print("Audio preparation failed: \(failure)") }
        Issue.record("AVFoundation preflight failed or exceeded the 20-second deadline")
    }
}
