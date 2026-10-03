import Foundation
import AVFoundation
@testable import MaroCore

@main struct MeasureWorker {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let node = directory.appendingPathComponent("node")
        let extractor = directory.appendingPathComponent("yt-dlp_macos")
        func measure<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
            let start = ContinuousClock.now
            do {
                let result = try await operation()
                print("\(label) seconds=\(start.duration(to: .now))")
                fflush(stdout)
                return result
            } catch {
                print("\(label) failed=\(type(of: error)) seconds=\(start.duration(to: .now))")
                fflush(stdout)
                throw error
            }
        }
        func payload(_ data: Data) throws -> Data {
            let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            if envelope["error"] != nil { throw ExtractorFailure.failed }
            return try JSONSerialization.data(withJSONObject: envelope["result"]!)
        }
        func pid(_ worker: ExtractorWorker) async throws -> Int {
            let result = try JSONSerialization.jsonObject(with: payload(await worker.request("ping"))) as! [String: Any]
            return result["pid"] as! Int
        }
        for run in 1...3 {
            let worker = ExtractorWorker(executable: directory.appendingPathComponent("python/bin/python3"),
                arguments: ["-I", "-B", directory.appendingPathComponent("maro-extractor.py").path, node.path])
            let firstPID = try await measure("worker run=\(run) initialization") { try await pid(worker) }
            for phase in ["cold", "warm"] {
                let search = try await measure("worker run=\(run) \(phase) search") {
                    try YouTubeSource.decodeSearch(payload(await worker.request("search", value: "Bach cello suite no 1")))
                }
                print("search results=\(search.count)")
                let audio = try await measure("worker run=\(run) \(phase) resolve") {
                    try YouTubeSource.decodeResolution(payload(await worker.request("resolve", value: "c3suauAz0zQ")), expectedVideoID: "c3suauAz0zQ")
                }
                let engine = PlaybackEngine()
                _ = try await measure("worker run=\(run) \(phase) native-prepare") {
                    try await engine.prepare(audio, positionSeconds: 0)
                }
                print("hls-first=\(audio.candidates.first?.isHLS == true) runtime-reused=\(try await pid(worker) == firstPID)")
            }
            await worker.shutdown()
            _ = try await measure("baseline run=\(run) search") {
                let result = try await ExtractorProcess.run(executable: extractor,
                    arguments: YouTubeSource.searchArguments(query: "Bach cello suite no 1", nodeExecutable: node))
                guard result.exitCode == 0 else { throw ExtractorFailure.failed }
                return try YouTubeSource.decodeSearch(result.stdout)
            }
            _ = try await measure("baseline run=\(run) resolve") {
                let result = try await ExtractorProcess.run(executable: extractor,
                    arguments: YouTubeSource.resolveArguments(videoID: "c3suauAz0zQ", nodeExecutable: node))
                guard result.exitCode == 0 else { throw ExtractorFailure.failed }
                return try YouTubeSource.decodeResolution(result.stdout, expectedVideoID: "c3suauAz0zQ")
            }
        }
    }
}
