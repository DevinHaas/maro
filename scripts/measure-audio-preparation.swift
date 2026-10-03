// Silent, opt-in network timing harness. Never commits a prepared player.
import AVFoundation
import Foundation
@testable import MaroCore

@main
struct AudioTiming {
    @MainActor static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        precondition(arguments.count >= 3, "Pass extractor, Node, and one or more public video IDs")
        let client = YouTubeClient(executable: URL(fileURLWithPath: arguments[0]), nodeExecutable: URL(fileURLWithPath: arguments[1]))
        if arguments.contains("--verify-hls") {
            let resolved = try await client.resolve(videoID: arguments.last!)
            for (index, candidate) in resolved.candidates.filter(\.isHLS).enumerated() {
                let asset = try await AudioAssetLoader.prepare(candidate)
                let engine = PlaybackEngine()
                let began = ContinuousClock().now
                do {
                    _ = try await AudioAssetLoader.loadAsset(asset, timeout: .seconds(15))
                    let tracks = try await asset.load(.tracks)
                    _ = try await engine.prepareAsset(asset, video: resolved.video, deadline: began.advanced(by: .seconds(25)))
                    print("hls candidate=\(index) ready seconds=\(began.duration(to: .now)) tracks=\(tracks.map { $0.mediaType.rawValue })")
                    let item = AVPlayerItem(asset: asset)
                    item.preferredForwardBufferDuration = 30
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = true
                    player.play()
                    try await Task.sleep(for: .seconds(3))
                    player.pause()
                    print("hls silent_progress=\(player.currentTime().seconds) duration=\(item.duration.seconds) bytes=\(item.accessLog()?.events.reduce(0) { $0 + $1.numberOfBytesTransferred } ?? 0) buffer_ends=\(item.loadedTimeRanges.map { CMTimeRangeGetEnd($0.timeRangeValue).seconds })")
                    let sought = await player.seek(to: CMTime(seconds: 1260, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                    player.play()
                    try await Task.sleep(for: .seconds(3))
                    player.pause()
                    print("hls seek_21min=\(sought) silent_position=\(player.currentTime().seconds) bytes=\(item.accessLog()?.events.reduce(0) { $0 + $1.numberOfBytesTransferred } ?? 0) buffer_ends=\(item.loadedTimeRanges.map { CMTimeRangeGetEnd($0.timeRangeValue).seconds })")
                    player.replaceCurrentItem(with: nil)
                } catch { print("hls candidate=\(index) failed type=\(type(of: error)) seconds=\(began.duration(to: .now))") }
            }
            return
        }
        let clock = ContinuousClock()
        func seconds(_ start: ContinuousClock.Instant) -> Double {
            let duration = start.duration(to: clock.now).components
            return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        }
        let direct = arguments.contains("--direct")
        let bounded = arguments.contains("--bounded")
        let ranges = arguments.contains("--ranges")
        for id in arguments.dropFirst(2) where !id.hasPrefix("--") {
            let start = clock.now
            do {
                let resolved = try await client.resolve(videoID: id)
                print("resolve id=\(id) seconds=\(seconds(start)) candidates=\(resolved.candidates.count)")
                if ranges {
                    print("duration=\(resolved.video.durationSeconds ?? 0)")
                    for (index, candidate) in resolved.candidates.filter({ !$0.isHLS }).enumerated() {
                        for range in ["bytes=0-1023", "bytes=-1024"] {
                            let configuration = URLSessionConfiguration.ephemeral
                            configuration.timeoutIntervalForRequest = 10
                            configuration.timeoutIntervalForResource = 12
                            let session = URLSession(configuration: configuration)
                            defer { session.invalidateAndCancel() }
                            var request = URLRequest(url: candidate.url)
                            request.setValue(range, forHTTPHeaderField: "Range")
                            request.setValue(candidate.userAgent, forHTTPHeaderField: "User-Agent")
                            let began = clock.now
                            do {
                                let (bytes, response) = try await session.bytes(for: request)
                                let http = response as! HTTPURLResponse
                                var count = 0
                                for try await _ in bytes { count += 1; if count >= 1024 { break } }
                                print("range candidate=\(index) bitrate=\(candidate.bitrate) request=\(range) status=\(http.statusCode) contentRange=\(http.value(forHTTPHeaderField: "Content-Range") ?? "none") length=\(http.value(forHTTPHeaderField: "Content-Length") ?? "none") read=\(count) seconds=\(seconds(began))")
                            } catch { print("range candidate=\(index) failed=\(type(of: error)) seconds=\(seconds(began))") }
                        }
                    }
                    continue
                }
                if bounded {
                    let readiness = clock.now
                    let engine = PlaybackEngine()
                    do {
                        _ = try await engine.prepare(resolved)
                        print("bounded id=\(id) prepare_seconds=\(seconds(readiness)) total_seconds=\(seconds(start)) result=ready muted=true")
                    } catch {
                        print("bounded id=\(id) prepare_seconds=\(seconds(readiness)) total_seconds=\(seconds(start)) result=failed type=\(String(describing: type(of: error)))")
                    }
                    fflush(stdout)
                    continue
                }
                for (index, candidate) in resolved.candidates.enumerated() {
                    let started = clock.now
                    do {
                        let asset: AVURLAsset
                        if direct {
                            let options = candidate.userAgent.map { [AVURLAssetHTTPUserAgentKey: $0] }
                            asset = AVURLAsset(url: candidate.url, options: options)
                        } else {
                            asset = try await AudioAssetLoader.prepare(candidate, timeout: .seconds(15))
                        }
                        let assetSeconds = seconds(started)
                        let engine = PlaybackEngine()
                        let readiness = clock.now
                        _ = try await engine.prepareAsset(asset, video: resolved.video,
                            deadline: clock.now.advanced(by: .seconds(15)))
                        print("candidate id=\(id) index=\(index) bitrate=\(candidate.bitrate) codec=\(candidate.audioCodec) direct=\(direct) asset_seconds=\(assetSeconds) ready_seconds=\(seconds(readiness)) total_seconds=\(seconds(started)) result=ready muted=true")
                    } catch {
                        // Never print NSError userInfo or signed URLs.
                        print("candidate id=\(id) index=\(index) seconds=\(seconds(started)) result=failed type=\(String(describing: type(of: error)))")
                    }
                }
            } catch { print("resolve id=\(id) seconds=\(seconds(start)) result=failed type=\(String(describing: type(of: error)))") }
            fflush(stdout)
        }
    }
}
