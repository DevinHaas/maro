// Compile with the app presentation sources (excluding MaroApp.swift) and MaroCore objects.
// Every service is injected; no Keychain, network, real state or audio access.
import AppKit
@testable import MaroCore

@main struct SearchStyleCheck {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/maro-search-interactive", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let video = try VideoSummary(id: "abcdefghijk", title: "Piano for a quiet afternoon — a long title without artwork", creator: "Example channel", durationSeconds: 3600)
        let controller = try MaroController(
            loaded: StateLoadResult(document: StateDocument(), preservedFile: nil, warning: nil),
            store: StateStore(file: output.appendingPathComponent("state.json")),
            engine: PlaybackEngine(), search: { query in
                if query == "error" { throw SourceFailure.noCompatibleAudio }
                return query == "empty" ? [] : [video]
            }, prepare: { _, _ in preconditionFailure("Fixture must never prepare audio") })
        let api = YouTubePlaylists(token: { throw CancellationError() },
            send: { _ in preconditionFailure("Fixture must never request YouTube") })
        let library = PlaylistLibrary(controller: controller, api: api)
        let search = SearchWindow(controller: controller, cacheDirectory: output, playlistLibrary: library)
        for name in ["initial", "results", "empty", "error"] {
            if name != "initial" { await controller.search(name) }
            search.render()
            search.present()
            try await Task.sleep(for: .milliseconds(150))
            let view = search.window!.contentView!
            view.layoutSubtreeIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            precondition(search.window!.firstResponder is NSTextView, "Opening search must focus text entry")
            search.window!.cancelOperation(nil)
            precondition(!search.window!.isVisible, "Escape/cancel must hide search")
            print("Rendered \(name); text-entry focus and close/reopen passed")
        }
        if CommandLine.arguments.contains("--interactive") {
            await controller.search("results")
            search.present()
            // Keep the isolated real UI available to supported accessibility tools.
            // No live account, external transport, or playable engine is connected.
            print("Interactive fixture ready; exits after ten minutes")
            try await Task.sleep(for: .seconds(600))
            search.window?.orderOut(nil)
        }
        await controller.shutdown()
    }
}
