// Isolated native acceptance fixture. No credentials, remote playlist writes, or audio.
// Compile alongside Sources/MaroApp/*.swift except MaroApp.swift, linking MaroCore.
import AppKit
import SwiftUI
import Foundation
@testable import MaroCore

@main struct RedesignUIFixture {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = RedesignFixtureDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor final class RedesignFixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var app: ApplicationModel?
    private var controller: MaroController?
    private var directory: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-redesign-fixture-" + UUID().uuidString)
                self.directory = directory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let videos = try (0..<20).map { index in
                    try VideoSummary(id: String(format: "fixture%04d", index),
                        title: index == 0 ? "Midnight jazz — a very long title to verify truncation and full accessibility labels" : "Quiet sessions \(index + 1)",
                        creator: index < 4 ? "Jazz collective" : "Creator \(index)", durationSeconds: Double(180 + index * 13))
                }
                var document = StateDocument(loadedVideo: try LoadedVideo(video: videos[0], positionSeconds: 38))
                try document.toggleFavorite(videos[0])
                let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
                    store: StateStore(file: directory.appendingPathComponent("state.json")), engine: PlaybackEngine(),
                    search: { query in
                        if query == "error" { throw SourceFailure.noCompatibleAudio }
                        if query == "loading" { try await Task.sleep(for: .seconds(2)) }
                        return query == "empty" ? [] : videos
                    }, prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
                self.controller = controller
                let responses = RedesignFixtureResponses()
                let api = YouTubePlaylists(token: { "disposable-local-fixture" }, send: { try await responses.respond($0) })
                let library = PlaylistLibrary(controller: controller, api: api)
                library.refresh()
                while library.busy { await Task.yield() }
                let model = ApplicationModel(controller: controller, library: library)
                self.app = model
                controller.onChange = { [weak model] _ in model?.render() }
                let hosting = NSHostingView(rootView: AppShellView(app: model, library: library))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                    styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
                window.title = "Maro Redesign Acceptance"
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: .darkAqua)
                window.titlebarAppearsTransparent = true
                window.minSize = NSSize(width: 800, height: 600)
                window.contentView = hosting
                self.window = window
                window.center(); window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                if CommandLine.arguments.count > 2 && CommandLine.arguments[1] == "--capture" {
                    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    for size in [NSSize(width: 1440, height: 900), NSSize(width: 1024, height: 768)] {
                        window.setContentSize(size)
                        for route in ["home", "playlist", "favorites", "results", "empty", "filter"] {
                            model.libraryFilter = ""
                            switch route {
                            case "playlist":
                                if let playlist = library.playlists.first {
                                    model.openPlaylist(playlist)
                                    while library.busy { await Task.yield() }
                                }
                            case "favorites": model.showFavorites()
                            case "results", "empty":
                                await controller.search(route == "empty" ? "empty" : "jazz")
                                model.render(); model.navigate(.search)
                            case "filter": model.showHome(); model.libraryFilter = "no matching collection"
                            default: model.showHome()
                            }
                            try await Task.sleep(for: .milliseconds(350))
                            hosting.layoutSubtreeIfNeeded()
                            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds),
                                  let data = { () -> Data? in
                                      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                                      return bitmap.representation(using: .png, properties: [:])
                                  }() else { throw CocoaError(.fileWriteUnknown) }
                            let name = "\(route)-\(Int(size.width))x\(Int(size.height)).png"
                            try data.write(to: output.appendingPathComponent(name))
                            print("Captured \(name)")
                        }
                    }
                    await controller.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                FileHandle.standardError.write(Data("Fixture failed: \(error)\n".utf8))
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

actor RedesignFixtureResponses {
    private var order = (0..<40).map { "occurrence\($0)" }

    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        let url = request.url!
        var payload: [String: Any] = [:]
        if url.path.hasSuffix("/playlistItems"), request.httpMethod == "PUT",
           let body = request.httpBody,
           let value = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           let id = value["id"] as? String,
           let snippet = value["snippet"] as? [String: Any],
           let position = snippet["position"] as? Int, let current = order.firstIndex(of: id) {
            order.remove(at: current); order.insert(id, at: min(max(0, position), order.count)); payload = value
        } else if url.path.hasSuffix("/playlistItems"), request.httpMethod == "DELETE" {
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
            order.removeAll { $0 == id }
        } else if url.path.hasSuffix("/playlists") {
            payload = ["items": (0..<9).map { index in
                ["id": "playlist\(index)", "snippet": ["title": ["Late night jazz", "Lofi focus", "Electronic discoveries", "Quiet afternoons", "Piano favourites", "Ambient journeys", "Weekend listening", "Café classics", "Long names remain readable in the library"][index],
                    "description": "A collection for unhurried listening.", "channelTitle": "Local acceptance fixture"],
                 "contentDetails": ["itemCount": order.count], "status": ["privacyStatus": "private"]] as [String: Any]
            }]
        } else {
            let requested = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
            let rows = order.enumerated().filter { requested == nil || $0.element == requested }.map { index, id -> [String: Any] in
                let originalIndex = Int(id.dropFirst("occurrence".count)) ?? 0
                let videoID = String(format: "fixture%04d", originalIndex == 1 ? 0 : originalIndex % 20)
                return ["id": id, "snippet": ["playlistId": "playlist0", "position": index,
                    "title": originalIndex == 3 ? "Deleted video" : "\(originalIndex + 1). Midnight jazz sessions — a long title to test row layout",
                    "videoOwnerChannelTitle": "Jazz collective", "publishedAt": "2026-10-01T12:00:00Z",
                    "resourceId": ["kind": "youtube#video", "videoId": originalIndex == 3 ? "" : videoID]]]
            }
            payload = ["items": rows]
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
