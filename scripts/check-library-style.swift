// Compile with PlaylistLibrary.swift, PlayerWindow.swift and PlaybackTimelineSlider.swift.
// Uses only disposable controller state and a rejecting in-memory API transport.
import AppKit
import SwiftUI
@testable import MaroCore

@main struct LibraryStyleCheck {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let controller = try MaroController(
            loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
            store: StateStore(file: output.appendingPathComponent("state.json")),
            engine: PlaybackEngine(), search: { _ in [] },
            prepare: { _, _ in preconditionFailure("Rendering must never prepare audio") })
        let api = YouTubePlaylists(token: { throw CancellationError() },
            send: { _ in preconditionFailure("Rendering must never request YouTube") })
        let video = try VideoSummary(id: "abcdefghijk", title: "A long video title with no artwork — piano for a quiet afternoon", creator: "Example channel")
        let playlist = YouTubePlaylist(id: "fixture", title: "Quiet afternoons", count: 12)
        for name in ["disconnected", "empty", "library", "detail", "add", "loading", "error"] {
            let library = PlaylistLibrary(controller: controller, api: api)
            library.connected = name != "disconnected"
            library.status = ""
            if !["disconnected", "empty"].contains(name) { library.playlists = [playlist] }
            if name == "disconnected" { library.status = "Connect YouTube to browse your own playlists." }
            if name == "detail" {
                library.selected = playlist
                library.items = (0..<12).map { YouTubePlaylistItem(id: "item\($0)", video: video, title: video.title) }
            }
            if name == "add" { library.pendingVideo = video; library.destination = playlist.id }
            if name == "loading" { library.busy = true; library.status = "Loading playlists…" }
            if name == "error" { library.stale = true; library.canRetry = true; library.status = "Could not refresh playlists. Try again." }
            let view = NSHostingView(rootView: PlaylistLibraryView(library: library))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = .windowBackgroundColor
            window.contentView = view
            view.frame = NSRect(x: 0, y: 0, width: 620, height: 500)
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Missing bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            print("Rendered \(name): \(Int(view.bounds.width))×\(Int(view.bounds.height))")
            window.close()
        }
        let create = PlaylistDialogs.name(title: "Create playlist", value: "").0
        let rename = PlaylistDialogs.name(title: "Rename playlist", value: "Quiet afternoons").0
        let delete = PlaylistDialogs.deletion(title: "Quiet afternoons")
        for (name, alert) in [("create", create), ("rename", rename), ("delete", delete)] {
            alert.layout()
            let window = alert.window
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            let view = window.contentView!
            view.layoutSubtreeIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            print("Rendered \(name) dialog without entering a modal loop or invoking actions")
            window.orderOut(nil)
        }
        await controller.shutdown()
    }
}
