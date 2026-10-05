// Interactive, silent fixture for supported computer-use checks of the real card.
import AppKit
import SwiftUI
@testable import MaroCore

@main struct TimelineUIFixture {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let video = try VideoSummary(id: "abcdefghijk", title: "Timeline interaction check", creator: "Silent fixture", durationSeconds: 300)
        var snapshot = PlayerSnapshot(loadedVideo: try LoadedVideo(video: video, positionSeconds: 60),
            favorites: [], playback: .paused, isSelecting: false, sourceNeedsUpdate: false,
            error: nil, persistenceError: nil)
        snapshot.timeline = PlaybackTimeline(duration: 300, ranges: [0...300])
        snapshot.timelineID = UUID()
        let presentation = PlayerPresentation(snapshot: snapshot)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-timeline-fixture-" + UUID().uuidString)
        let controller = try MaroController(loaded: StateLoadResult(document: StateDocument(loadedVideo: snapshot.loadedVideo), preservedFile: nil, warning: nil),
            store: StateStore(file: directory.appendingPathComponent("state.json")), engine: PlaybackEngine(),
            search: { _ in [] }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
        let model = ApplicationModel(controller: controller, library: PlaylistLibrary(controller: controller))
        let window = NSWindow(contentRect: NSRect(x: 300, y: 400, width: 430, height: 200),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Maro timeline — silent UI verification"
        window.isReleasedWhenClosed = false
        var commits = 0
        let view = NSHostingView(rootView: PlayerCard(presentation: presentation, app: model,
            action: { _, _ in }, search: {}, hide: { window.orderOut(nil); presentation.timelineEpoch += 1 },
            seek: { seconds, id in
                guard id == presentation.snapshot.timelineID else { return }
                commits += 1
                presentation.snapshot.loadedVideoForFixture(video: video, seconds: seconds)
                print("commit=\(commits) position=\(seconds)")
                fflush(stdout)
            }))
        window.contentView = view
        window.setContentSize(view.fittingSize)
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

private extension PlayerSnapshot {
    mutating func loadedVideoForFixture(video: VideoSummary, seconds: Double) {
        var updated = PlayerSnapshot(loadedVideo: try! LoadedVideo(video: video, positionSeconds: seconds),
            favorites: favorites, playback: .paused, isSelecting: false, sourceNeedsUpdate: false,
            error: nil, persistenceError: nil)
        updated.timeline = timeline
        updated.timelineID = timelineID
        self = updated
    }
}
