import Foundation
import Testing
@testable import MaroCore

// Opt-in, network-dependent, muted. MARO_BENCH_TOOLS=/absolute/.build/tools
// Measures click-to-audio through the real controller, worker and AVPlayer.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["MARO_BENCH_TOOLS"] != nil))
func playbackLatencyBenchmark() async throws {
    let env = ProcessInfo.processInfo.environment
    let tools = URL(fileURLWithPath: try #require(env["MARO_BENCH_TOOLS"]))
    let ids = (env["MARO_BENCH_IDS"] ?? "dQw4w9WgXcQ,kJQP7kiw5Fk,mGQLXRTl3Z0,fJ9rUzIMcZQ,7rlIwnDh7dE,c3suauAz0zQ")
        .split(separator: ",").map(String.init)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-bench-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = YouTubeClient(executable: tools.appendingPathComponent("yt-dlp_macos"),
                               nodeExecutable: tools.appendingPathComponent("node"))
    let controller = try await MaroController.open(store: StateStore(file: directory.appendingPathComponent("state.json")),
                                                   source: client, engine: PlaybackEngine())
    controller.setVolume(0)
    await client.warmUp()
    let videos = try ids.map { try VideoSummary(id: $0, title: $0, creator: "") }
    var results: [String: [Double]] = [:]

    func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
    func untilPlaying() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while controller.snapshot.playback != .playing {
            guard ContinuousClock.now < deadline else { throw PlaybackFailure.preparationTimedOut }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func record(_ scenario: String, _ id: String, _ action: () async throws -> Void) async {
        let start = ContinuousClock.now
        do {
            try await action()
            try await untilPlaying()
            let seconds = seconds(start.duration(to: .now))
            results[scenario, default: []].append(seconds)
            print(String(format: "bench scenario=%@ id=%@ click-to-audio=%.3fs", scenario, id, seconds))
        } catch {
            print("bench scenario=\(scenario) id=\(id) failed=\(error)")
        }
        controller.pause()
    }

    let rounds = Int(env["MARO_BENCH_ROUNDS"] ?? "2") ?? 2
    for _ in 0..<rounds {
        // Extractor alone, so source-side changes are visible without player noise.
        for video in videos {
            let start = ContinuousClock.now
            do {
                _ = try await client.resolve(videoID: video.id)
                let seconds = seconds(start.duration(to: .now))
                results["resolve-only", default: []].append(seconds)
                print(String(format: "bench scenario=resolve-only id=%@ seconds=%.3fs", video.id, seconds))
            } catch { print("bench scenario=resolve-only id=\(video.id) failed=\(error)") }
        }
        // Resolution cached by the pass above, no buffered player.
        for video in videos {
            await record("cache-hit-click", video.id) { try await controller.select(video) }
        }
        // Cold click: nothing cached or warmed for this track (the pre-change path).
        for video in videos {
            await client.forget(videoID: video.id)
            await record("cold-click", video.id) { try await controller.select(video) }
        }
        // Hover dwell long enough for the warm to finish, then click.
        for video in videos {
            await client.forget(videoID: video.id)
            controller.warm(video)
            try await Task.sleep(for: .seconds(3))
            await record("hover-3s-click", video.id) { try await controller.select(video) }
        }
        // Quick hover: the click joins the warm already in flight.
        for video in videos {
            await client.forget(videoID: video.id)
            controller.warm(video)
            try await Task.sleep(for: .milliseconds(500))
            await record("hover-0.5s-click", video.id) { try await controller.select(video) }
        }
        // Playlist Next after the upcoming track had a few seconds to warm.
        for video in videos { await client.forget(videoID: video.id) }
        let items = videos.map { YouTubePlaylistItem(id: $0.id, video: $0, title: $0.id) }
        try await controller.playPlaylist(items)
        try await untilPlaying()
        for video in videos.dropFirst() {
            try await Task.sleep(for: .seconds(4))
            await record("playlist-next", video.id) {
                _ = try await controller.execute(CommandRequest(command: .next), openSearch: {})
            }
            try await controller.resume()
        }
    }

    for (scenario, values) in results.sorted(by: { $0.key < $1.key }) {
        let sorted = values.sorted()
        print(String(format: "bench summary scenario=%@ n=%d median=%.3fs min=%.3fs max=%.3fs",
                     scenario, sorted.count, sorted[sorted.count / 2], sorted.first!, sorted.last!))
    }
    await controller.shutdown()
}
