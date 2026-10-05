// Compile alongside app sources excluding MaroApp.swift, linking MaroCore objects.
// Native loading-state captures with delayed local fixtures; no live account or audio.
import AppKit
import SwiftUI
@testable import MaroCore

@main struct LoadingSkeletonCheck {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let video = try VideoSummary(id: "abcdefghijk", title: "Known track remains visible", creator: "Local fixture", durationSeconds: 300)
        for mode in ["search", "search-more", "playlist", "home", "preview", "bottom-player", "bottom-first-track"] {
            let controller = try MaroController(
                loaded: StateLoadResult(document: StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 42)), preservedFile: nil, warning: nil),
                store: StateStore(file: output.appendingPathComponent(mode + "-state.json")), engine: PlaybackEngine(),
                search: { _ in try await Task.sleep(for: .seconds(30)); return [] },
                prepare: { _, _ in preconditionFailure("Loading fixture must not prepare audio") })
            let playlist = YouTubePlaylist(id: "fixture", title: "Fetching playlist tracks", count: 4)
            let api = YouTubePlaylists(token: { "local-fixture" }, send: { request in
                precondition(request.httpMethod == nil || request.httpMethod == "GET", "Loading fixture must not write playlists")
                let body: String
                if request.url!.path.hasSuffix("/playlists") {
                    body = #"{"items":[{"id":"fixture","snippet":{"title":"Fetching playlist tracks"},"contentDetails":{"itemCount":4}}]}"#
                } else {
                    try await Task.sleep(for: .seconds(1))
                    body = #"{"items":[]}"#
                }
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
            let library = PlaylistLibrary(controller: controller, api: api)
            let model = ApplicationModel(controller: controller, library: library)
            let root: AnyView
            let size: NSSize
            switch mode {
            case "search", "search-more":
                model.navigate(.search)
                var state = SearchViewState(query: "Fixture jazz", results: mode == "search-more" ? [video] : [],
                    isSearching: mode == "search", hasMore: mode == "search-more", error: nil)
                state.isLoadingMore = mode == "search-more"
                model.searchState = state
                root = AnyView(SearchResultsView(app: model))
                size = NSSize(width: 760, height: 500)
            case "playlist":
                model.openPlaylist(playlist)
                for _ in 0..<100 {
                    if library.loadingTracks { break }
                    try await Task.sleep(for: .milliseconds(5))
                }
                precondition(library.loadingTracks, "Selected playlist read must expose loading state")
                root = AnyView(PlaylistDetailView(app: model))
                size = NSSize(width: 760, height: 820)
            case "home":
                precondition(model.home.isLoading, "Home fixture must fetch initial suggestions")
                root = AnyView(HomeView(app: model))
                size = NSSize(width: 760, height: 960)
            case "preview":
                model.globalQuery = "Uncached fixture"
                model.focusSearch()
                try await Task.sleep(for: .milliseconds(350))
                precondition(model.previewLoading, "Preview fixture must expose loading state")
                root = AnyView(GlobalSearchView(app: model).frame(width: 500, height: 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
                size = NSSize(width: 540, height: 530)
            default:
                model.player.snapshot = PlayerSnapshot(loadedVideo: mode == "bottom-first-track" ? nil : controller.snapshot.loadedVideo,
                    favorites: [], playback: .paused, isSelecting: true, sourceNeedsUpdate: false, error: nil, persistenceError: nil)
                root = AnyView(BottomPlayerView(app: model, presentation: model.player))
                size = NSSize(width: 1024, height: 100)
            }
            let hosting = NSHostingView(rootView: root.preferredColorScheme(.dark)
                .environment(\.skeletonReduceMotionOverride, false).background(AppDesign.surface))
            hosting.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            hosting.setFrameSize(size)
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(180))
            hosting.layoutSubtreeIfNeeded()
            let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(mode + ".png"))
            if mode == "playlist" {
                for _ in 0..<100 {
                    if !library.busy { break }
                    try await Task.sleep(for: .milliseconds(20))
                }
                precondition(!library.loadingTracks, "Completed playlist read must clear skeleton state")
            }
            print("PASS native loading capture: \(mode); no audio or playlist writes")
            window.close()
            await controller.shutdown()
        }
    }
}
