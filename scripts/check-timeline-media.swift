// Opt-in remote-media seek probe. Disposable, paused and muted throughout.
import AVFoundation
import Foundation
@testable import MaroCore

@main struct TimelineMediaCheck {
    @MainActor static func main() async {
        guard CommandLine.arguments.count == 4 else {
            print("Usage: probe Resources-directory video-ID hls|progressive")
            return
        }
        let resources = URL(fileURLWithPath: CommandLine.arguments[1])
        let client = YouTubeClient(executable: resources.appendingPathComponent("yt-dlp_macos"),
            nodeExecutable: resources.appendingPathComponent("node"))
        let engine = PlaybackEngine()
        defer { engine.stop() }
        do {
            let resolved = try await client.resolve(videoID: CommandLine.arguments[2])
            let hls = CommandLine.arguments[3] == "hls"
            guard let candidate = resolved.candidates.first(where: { $0.isHLS == hls }) else {
                print("FAIL: requested media transport unavailable"); await client.shutdown(); return
            }
            let asset = try await AudioAssetLoader.prepare(candidate)
            let prepared = try await engine.prepareAsset(asset, video: resolved.video)
            try engine.commit(prepared, autoplay: false)
            let deadline = ContinuousClock().now.advanced(by: .seconds(10))
            while engine.timeline == nil, ContinuousClock().now < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }
            guard let timeline = engine.timeline else {
                print("FAIL: no finite seekable range"); await client.shutdown(); return
            }
            let targets = hls ? [1260.0, 30.0] : [min(60, timeline.duration / 2), 5.0]
            for target in targets {
                guard timeline.target(for: target) == target else {
                    print("FAIL: target outside seekable ranges"); break
                }
                let started = ContinuousClock().now
                try await engine.seekLoaded(to: target, invalidateOnFailure: false)
                let actual = engine.positionSeconds
                let passed = abs(actual - target) < 1 && engine.isMuted && !engine.isPlaying
                print("\(passed ? "PASS" : "FAIL"): target=\(target) actual=\(actual) latency=\(started.duration(to: .now)) paused=\(!engine.isPlaying) muted=\(engine.isMuted)")
                fflush(stdout)
            }
        } catch let error as ExtractorFailure {
            print("FAIL: extractor: \(error.message)")
        } catch {
            // Never expose signed URLs, HTTP headers or NSError userInfo.
            print("FAIL: media probe error type=\(type(of: error))")
        }
        await client.shutdown()
    }
}
