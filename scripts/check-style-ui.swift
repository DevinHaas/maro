// Interactive native lifecycle fixture. All data/services are disposable and local.
import AppKit
@testable import MaroCore

@main struct StyleUIFixture {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = StyleFixtureDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class StyleFixtureDelegate: NSObject, NSApplicationDelegate {
    private var search: SearchWindow?
    private var controller: MaroController?
    private var player: PlayerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let root = NSMenuItem()
        menu.addItem(root)
        let actions = NSMenu(title: "Fixture")
        root.submenu = actions
        for (title, selector, key) in [
            ("Show search", #selector(showSearch), "f"),
            ("Create dialog", #selector(createDialog), "n"),
            ("Rename dialog", #selector(renameDialog), "r"),
            ("Delete confirmation", #selector(deleteDialog), "d"),
            ("Compact window", #selector(compactWindow), "1"),
            ("Show player", #selector(showPlayer), "p"),
            ("Inspect inactive window", #selector(deactivateFixture), "i")
        ] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            actions.addItem(item)
        }
        actions.addItem(NSMenuItem(title: "Quit fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        NSApplication.shared.mainMenu = menu
        Task {
            do {
                let video = try VideoSummary(id: "abcdefghijk", title: "Piano for a quiet afternoon — a long title without artwork", creator: "Example channel", durationSeconds: 3600)
                let results = try (0..<20).map { index in
                    try VideoSummary(id: String(format: "fixture%04d", index),
                        title: "\(index + 1). \(video.title)", creator: video.creator, durationSeconds: 3600)
                }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-style-ui-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let controller = try MaroController(
                    loaded: StateLoadResult(document: StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 90)), preservedFile: nil, warning: nil),
                    store: StateStore(file: directory.appendingPathComponent("state.json")),
                    engine: PlaybackEngine(), search: { query in
                        if query == "error" { throw SourceFailure.noCompatibleAudio }
                        if query == "loading" { try await Task.sleep(for: .seconds(3)) }
                        return query == "empty" ? [] : results
                    },
                    prepare: { _, _ in throw SourceFailure.noCompatibleAudio })
                self.controller = controller
                let api = YouTubePlaylists(token: { "local-fixture" }, send: { request in
                    guard request.httpMethod == "GET" else { throw CancellationError() }
                    let body = request.url!.path.hasSuffix("/playlists")
                        ? #"{"items":[{"id":"fixture","snippet":{"title":"Quiet afternoons"},"contentDetails":{"itemCount":1}}]}"#
                        : #"{"items":[{"id":"item1","snippet":{"title":"Fixture piano","videoOwnerChannelTitle":"Example channel","resourceId":{"videoId":"abcdefghijk"}}}]}"#
                    return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                })
                let library = PlaylistLibrary(controller: controller, api: api)
                let search = SearchWindow(controller: controller, cacheDirectory: directory, playlistLibrary: library)
                self.search = search
                let player = PlayerWindow(application: search.application, openSearch: { [weak search] in search?.present() })
                self.player = player
                controller.onChange = { [weak search, weak player] in search?.render(); player?.render() }
                await controller.search("piano")
                search.present()
                print("Silent styling fixture ready")
                fflush(stdout)
            } catch { print("Fixture setup failed: \(error)"); NSApplication.shared.terminate(nil) }
        }
    }

    @objc private func showSearch() { search?.present() }
    @objc private func deactivateFixture() { NSApplication.shared.deactivate() }
    @objc private func showPlayer() { search?.window?.orderOut(nil); player?.toggle() }
    @objc private func compactWindow() {
        guard let window = search?.window, let screen = window.screen else { return }
        window.setFrame(SearchWindow.presentationFrame(size: NSSize(width: 560, height: 450),
            visible: screen.visibleFrame, anchorX: window.frame.midX), display: true)
    }
    @objc private func createDialog() { _ = PlaylistDialogs.name(title: "Create playlist", value: "").0.runModal() }
    @objc private func renameDialog() { _ = PlaylistDialogs.name(title: "Rename playlist", value: "Quiet afternoons").0.runModal() }
    @objc private func deleteDialog() { _ = PlaylistDialogs.deletion(title: "Quiet afternoons").runModal() }
}
