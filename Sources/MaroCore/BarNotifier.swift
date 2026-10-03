import Foundation

/// Sends only the custom event. Labels, popup layout and colors stay in scripts.
@MainActor
public final class BarNotifier {
    private struct VisibleState: Equatable {
        let video: VideoSummary?
        let favorites: [VideoSummary]
        let playback: PlaybackState
        let selecting: Bool
        let sourceNeedsUpdate: Bool
        let error: String?
        let persistenceError: String?
        let artwork: [String: String]?
        let previous: Bool?
        let next: Bool?
        init(_ state: PlayerSnapshot) {
            video = state.loadedVideo?.video; favorites = state.favorites
            playback = state.playback; selecting = state.isSelecting
            sourceNeedsUpdate = state.sourceNeedsUpdate; error = state.error
            persistenceError = state.persistenceError
            artwork = state.localThumbnailPaths
            previous = state.canGoPrevious; next = state.canGoNext
        }
    }

    private var last: VisibleState?
    private var pending: Task<Void, Never>?
    private let emit: @Sendable () async -> Void

    public convenience init(executable: URL) {
        self.init {
            guard FileManager.default.isExecutableFile(atPath: executable.path) else { return }
            _ = try? await ExtractorProcess.run(executable: executable,
                arguments: ["--trigger", "maro_state_changed"], timeout: 2, stdoutLimit: 1024, stderrLimit: 1024)
        }
    }

    init(emit: @escaping @Sendable () async -> Void) { self.emit = emit }

    public func update(_ snapshot: PlayerSnapshot) {
        let visible = VisibleState(snapshot)
        guard visible != last else { return }
        last = visible
        pending?.cancel()
        pending = Task { [emit] in
            do { try await Task.sleep(for: .milliseconds(150)) }
            catch { return }
            guard !Task.isCancelled else { return }
            await emit()
        }
    }

    public func stop() async {
        pending?.cancel()
        await pending?.value
        pending = nil
        last = nil
    }

    deinit { pending?.cancel() }
}
