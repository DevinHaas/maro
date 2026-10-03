// Silent, opt-in timing of the actual controller-to-search-result path.
import Foundation
import MaroCore

@main
struct SearchTiming {
    @MainActor static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        precondition(arguments.count == 2, "Pass extractor and Node paths")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("maro-search-timing-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let controller = try await MaroController.open(store: StateStore(file: root.appendingPathComponent("state.json")),
            source: YouTubeClient(executable: URL(fileURLWithPath: arguments[0]), nodeExecutable: URL(fileURLWithPath: arguments[1])),
            engine: PlaybackEngine())
        let clock = ContinuousClock()
        func seconds(_ start: ContinuousClock.Instant) -> Double {
            let value = start.duration(to: clock.now).components
            return Double(value.seconds) + Double(value.attoseconds) / 1e18
        }
        for query in ["Bach cello suite no 1", "ambience nordic vikings"] {
            for attempt in 1...2 {
                let start = clock.now
                await controller.search(query)
                let first = seconds(start)
                let visible = controller.searchState.results.count
                while controller.searchState.hasMore { controller.revealMoreResults() }
                print("query=\(query) attempt=\(attempt) first_five_seconds=\(first) visible=\(visible) full_list_seconds=\(seconds(start)) total=\(controller.searchState.results.count) error=\(controller.searchState.error != nil)")
                fflush(stdout)
            }
        }
        await controller.shutdown()
    }
}
