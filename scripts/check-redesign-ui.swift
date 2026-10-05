// Isolated native acceptance fixture. Local API responses and muted local audio.
// Compile alongside Sources/MaroApp/*.swift except MaroApp.swift, linking MaroCore.
import AppKit
import AVFoundation
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
    private var search: SearchWindow?
    private var app: ApplicationModel?
    private var controller: MaroController?
    private var directory: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let applicationMenu = NSMenu()
        item.submenu = applicationMenu
        applicationMenu.addItem(NSMenuItem(title: "Quit acceptance fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        NSApplication.shared.mainMenu = menu
        Task {
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-redesign-fixture-" + UUID().uuidString)
                self.directory = directory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let audio = try Self.silentAudio(in: directory)
                let engine = PlaybackEngine()
                engine.volume = 0
                let artworkData: Data
                if let index = CommandLine.arguments.firstIndex(of: "--artwork"), CommandLine.arguments.indices.contains(index + 1) {
                    artworkData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                } else {
                    artworkData = Self.fixtureArtwork()
                }
                let artwork = ArtworkCache(directory: directory.appendingPathComponent("artwork"), fetch: { _ in artworkData })
                let videos = try (0..<20).map { index in
                    try VideoSummary(id: String(format: "fixture%04d", index),
                        title: index == 0 ? "Midnight jazz — a very long title to verify truncation and full accessibility labels" : "Quiet sessions \(index + 1)",
                        creator: index < 4 ? "Jazz collective" : "Creator \(index)", durationSeconds: 300,
                        thumbnailURL: URL(string: String(format: "https://i.ytimg.com/vi/fixture%04d/hqdefault.jpg", index)))
                }
                for video in videos {
                    _ = await artwork.image(for: video)
                    if let url = video.thumbnailURL {
                        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                            headerFields: ["Content-Type": CommandLine.arguments.contains("--artwork") ? "image/jpeg" : "image/png", "Cache-Control": "public, max-age=3600"])!
                        URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: artworkData), for: URLRequest(url: url))
                    }
                }
                let failedCoverURL = URL(string: "https://i.ytimg.com/vi/failed-fixture-cover/hqdefault.jpg")!
                let failedResponse = HTTPURLResponse(url: failedCoverURL, statusCode: 404, httpVersion: nil,
                    headerFields: ["Cache-Control": "public, max-age=3600"])!
                URLCache.shared.storeCachedResponse(CachedURLResponse(response: failedResponse, data: Data()), for: URLRequest(url: failedCoverURL))
                var document = StateDocument(loadedVideo: try LoadedVideo(video: videos[0], positionSeconds: 38))
                try document.toggleFavorite(videos[0])
                let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
                    store: StateStore(file: directory.appendingPathComponent("state.json")), engine: engine, artworkCache: artwork,
                    search: { query in
                        if query == "error" { throw SourceFailure.noCompatibleAudio }
                        if query == "loading" { try await Task.sleep(for: .seconds(2)) }
                        return query == "empty" ? [] : videos
                    }, prepare: { video, position in
                        try await engine.prepareAsset(AVURLAsset(url: audio), video: video, positionSeconds: position)
                    })
                self.controller = controller
                let responses = RedesignFixtureResponses()
                let api = YouTubePlaylists(token: { "disposable-local-fixture" }, send: { try await responses.respond($0) })
                let library = PlaylistLibrary(controller: controller, api: api)
                if CommandLine.arguments.contains("--playlist-cleanup") { library.configured = true }
                library.refresh()
                while library.busy { await Task.yield() }
                let search = SearchWindow(controller: controller, cacheDirectory: directory, playlistLibrary: library)
                self.search = search
                let model = search.application
                self.app = model
                controller.onChange = { [weak model] in model?.render() }
                guard let window = search.window,
                      let hosting = window.contentView as? NSHostingView<AppShellView> else { throw CocoaError(.coderInvalidValue) }
                window.title = "Maro Redesign Acceptance"
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: .darkAqua)
                window.titlebarAppearsTransparent = true
                self.window = window
                if CommandLine.arguments.contains("--trace-input") {
                    _ = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
                        if event.window === window {
                            let point = hosting.convert(event.locationInWindow, from: nil)
                            let target = hosting.hitTest(point).map { String(describing: type(of: $0)) } ?? "none"
                            print("Fixture input: \(event.type.rawValue) \(point) target \(target), pointer \(NSEvent.mouseLocation), event screen \(window.convertPoint(toScreen: event.locationInWindow))")
                            @MainActor func inspect(_ view: NSView) {
                                if let handle = view as? PlaylistDragHandleView {
                                    let rect = handle.convert(handle.bounds, to: hosting)
                                    if abs(rect.midY - point.y) < 50 {
                                        print("Fixture handle: \(handle.item?.id ?? "") \(rect) enabled \(handle.enabled)")
                                    }
                                }
                                for child in view.subviews { inspect(child) }
                            }
                            inspect(hosting)
                            fflush(stdout)
                        }
                        return event
                    }
                }
                search.present()
                if CommandLine.arguments.count > 2 && CommandLine.arguments[1] == "--capture" {
                    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    if CommandLine.arguments.contains("--tidal-baseline") {
                        try artworkData.write(to: output.appendingPathComponent("fixture-artwork.png"))
                    }
                    // Tidal baseline mode adds both responsive boundaries without
                    // changing the production views or the original acceptance run.
                    let tidalBaseline = CommandLine.arguments.contains("--tidal-baseline")
                    let improvements = CommandLine.arguments.contains("--improvements")
                    let playlistCleanup = CommandLine.arguments.contains("--playlist-cleanup")
                    let sizes = improvements || playlistCleanup
                        ? [NSSize(width: 760, height: 720), NSSize(width: 1024, height: 768), NSSize(width: 1440, height: 900)]
                        : tidalBaseline
                        ? [NSSize(width: 1440, height: 900), NSSize(width: 1024, height: 768),
                           NSSize(width: 1199, height: 900), NSSize(width: 1200, height: 900),
                           NSSize(width: 1001, height: 900), NSSize(width: 1002, height: 900)]
                        : [NSSize(width: 1440, height: 900), NSSize(width: 1024, height: 768)]
                    for size in sizes {
                        window.setContentSize(size)
                        let routes = playlistCleanup ? ["playlist", "playlist-rows", "playlist-hovered", "playlist-rail", "playlist-rail-hovered", "playlist-stale"]
                            : improvements ? ["home", "home-rail", "results", "results-rail"] : tidalBaseline
                            ? (size.width < 1024 ? ["home"]
                               : size.width == 1440 || size.width == 1024 ? ["home", "preview", "playlist", "rows", "results"]
                               : ["home", "preview", "playlist"])
                            : ["home", "preview", "playlist", "rows", "fallback", "favorites", "results", "empty", "error", "filter"]
                        for route in routes {
                            print("Preparing \(route) at \(Int(size.width))×\(Int(size.height))")
                            fflush(stdout)
                            model.libraryFilter = ""
                            library.stale = false
                            model.libraryCollapsed = route.contains("-rail")
                            let destination = route.replacingOccurrences(of: "-rail", with: "").replacingOccurrences(of: "-stale", with: "").replacingOccurrences(of: "-hovered", with: "").replacingOccurrences(of: "-rows", with: "")
                            switch destination {
                            case "playlist", "rows", "fallback":
                                if let playlist = route == "fallback" ? library.playlists.last : library.playlists.first {
                                    model.openPlaylist(playlist)
                                    while library.busy { await Task.yield() }
                                    if route == "rows" {
                                        library.play(occurrenceID: "occurrence1", in: playlist.id)
                                        try await Task.sleep(for: .milliseconds(200))
                                        controller.pause()
                                    }
                                }
                                if route.hasSuffix("-stale") {
                                    library.stale = true
                                    library.status = "Your YouTube library may be out of date."
                                }
                            case "favorites": model.showFavorites()
                            case "results", "empty", "error":
                                await controller.search(destination == "results" ? "jazz" : destination)
                                model.render(); model.navigate(.search)
                            case "preview": model.showHome(); model.globalQuery = ""; model.focusSearch()
                            case "filter": model.showHome(); model.libraryFilter = "no matching collection"
                            default: model.showHome()
                            }
                            if destination == "home" {
                                for _ in 0..<80 {
                                    if !model.home.isLoading { break }
                                    try await Task.sleep(for: .milliseconds(50))
                                }
                            }
                            try await Task.sleep(for: .milliseconds(350))
                            // Window managers may retile a fixture window; constrain the
                            // rendered content explicitly for repeatable viewport checks.
                            hosting.setFrameSize(size)
                            hosting.layoutSubtreeIfNeeded()
                            if playlistCleanup {
                                Self.scrollFixturePlaylist(in: hosting, sidebarWidth: model.libraryCollapsed ? 72 : size.width < 1200 ? 280 : 320,
                                                           offset: route.hasSuffix("-rows") ? 360 : 0)
                                Self.setFixtureSidebarHover(in: hosting, hovered: route.hasSuffix("-hovered"))
                                try await Task.sleep(for: .milliseconds(80))
                                hosting.layoutSubtreeIfNeeded()
                            }
                            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds),
                                  let data = { () -> Data? in
                                      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                                      return bitmap.representation(using: .png, properties: [:])
                                  }() else { throw CocoaError(.fileWriteUnknown) }
                            let name = "\(route)-\(Int(size.width))x\(Int(size.height)).png"
                            try data.write(to: output.appendingPathComponent(name))
                            if tidalBaseline || improvements || playlistCleanup {
                                let observations = Self.accessibilityObservations(hosting: hosting, window: window)
                                let report: [String: Any] = [
                                    "productionRevision": "working-tree", "route": route,
                                    "coordinateSpace": "logical content points, origin top-left",
                                    "contentSize": ["width": size.width, "height": size.height],
                                    "backingScale": window.backingScaleFactor,
                                    "pixelSize": ["width": bitmap.pixelsWide, "height": bitmap.pixelsHigh],
                                    "accessibility": observations,
                                    "playlistDatedItems": library.items.filter { $0.addedAt != nil }.count,
                                    "nativeScrollers": Self.scrollerObservations(in: hosting, sidebarWidth: model.libraryCollapsed ? 72 : size.width < 1200 ? 280 : 320,
                                                                                 expectedSidebarHover: playlistCleanup ? route.hasSuffix("-hovered") : nil),
                                    "limits": "AX frames expose controls and combined text, not every SwiftUI glyph baseline. Source-resolved geometry is separately recorded; no inferred frame is labeled native-measured."
                                ]
                                let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                                try json.write(to: output.appendingPathComponent(name.replacingOccurrences(of: ".png", with: ".json")))
                            }
                            print("Captured \(name): logical content \(hosting.bounds.size), pixels \(bitmap.pixelsWide)×\(bitmap.pixelsHigh), window \(window.frame.size)")
                            fflush(stdout)
                        }
                    }
                    if playlistCleanup {
                        for (name, alert) in [("rename-playlist-dialog", PlaylistDialogs.name(title: "Rename playlist", value: "Late night jazz").0),
                                               ("remove-playlist-dialog", PlaylistDialogs.deletion(title: "Late night jazz"))] {
                            alert.layout()
                            alert.window.makeKeyAndOrderFront(nil)
                            try await Task.sleep(for: .milliseconds(100))
                            if let content = alert.window.contentView,
                               let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                                content.cacheDisplay(in: content.bounds, to: bitmap)
                                try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
                                print("Captured \(name) without invoking an account action")
                            }
                            alert.window.orderOut(nil)
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

    private static func setFixtureSidebarHover(in view: NSView, hovered: Bool) {
        if let anchor = view as? ScrollbarStyleAnchor {
            anchor.sidebarHovered = hovered
            anchor.scheduleUpdate()
        }
        for child in view.subviews { setFixtureSidebarHover(in: child, hovered: hovered) }
    }

    private static func scrollFixturePlaylist(in hosting: NSView, sidebarWidth: CGFloat, offset: CGFloat) {
        var candidates: [NSScrollView] = []
        func visit(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let frame = scroll.convert(scroll.bounds, to: hosting)
                if frame.midX > 8 + sidebarWidth && frame.height > 200 { candidates.append(scroll) }
            }
            for child in view.subviews { visit(child) }
        }
        visit(hosting)
        guard let scroll = candidates.last, let document = scroll.documentView else { return }
        let maximum = max(0, document.bounds.height - scroll.contentView.bounds.height)
        let y = document.isFlipped ? min(offset, maximum) : max(0, maximum - offset)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private static func scrollerObservations(in hosting: NSView, sidebarWidth: CGFloat, expectedSidebarHover: Bool?) -> [[String: Any]] {
        var observations: [[String: Any]] = []
        func visit(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let frame = scroll.convert(scroll.bounds, to: hosting)
                let sidebar = frame.midX < 8 + sidebarWidth
                if let expectedSidebarHover {
                    precondition(scroll.scrollerStyle == .overlay, "Scroller must not reserve a gutter")
                    if sidebar { precondition(scroll.hasVerticalScroller == expectedSidebarHover, "Sidebar scroller hover visibility mismatch") }
                }
                observations.append(["sidebar": sidebar, "overlay": scroll.scrollerStyle == .overlay,
                    "verticalVisible": scroll.hasVerticalScroller, "autoHides": scroll.autohidesScrollers,
                    "verticalClass": scroll.verticalScroller.map { String(describing: type(of: $0)) } ?? "none",
                    "frame": ["x": frame.minX, "width": frame.width]])
            }
            for child in view.subviews { visit(child) }
        }
        visit(hosting)
        return observations
    }

    private static func accessibilityObservations(hosting: NSView, window: NSWindow) -> [[String: Any]] {
        let contentScreen = window.convertToScreen(hosting.convert(hosting.bounds, to: nil))
        var observations: [[String: Any]] = []
        var visited = Set<ObjectIdentifier>()
        func visit(_ object: AnyObject, path: String, depth: Int) {
            guard depth < 40, visited.insert(ObjectIdentifier(object)).inserted,
                  let element = object as? NSObject else { return }
            // SwiftUI virtual accessibility objects implement the selectors but
            // do not all declare NSAccessibilityProtocol conformance. KVC boxes
            // NSRect safely; selector guards avoid undefined-key exceptions.
            func value(_ key: String) -> Any? {
                element.responds(to: NSSelectorFromString(key)) ? element.value(forKey: key) : nil
            }
            let frame = (value("accessibilityFrame") as? NSValue)?.rectValue ?? .zero
            let text = (value("accessibilityLabel") as? String) ?? (value("accessibilityTitle") as? String) ??
                (value("accessibilityValue") as? String) ?? ""
            let row: [String: Any] = [
                "path": path, "role": (value("accessibilityRole") as? String) ?? "unknown",
                "text": text, "enabled": (value("accessibilityEnabled") as? Bool) ?? false,
                "frame": ["x": frame.minX - contentScreen.minX,
                          "y": contentScreen.maxY - frame.maxY,
                          "width": frame.width, "height": frame.height]
            ]
            observations.append(row)
            for (index, child) in ((value("accessibilityChildren") as? [Any]) ?? []).enumerated() {
                visit(child as AnyObject, path: path + "." + String(index), depth: depth + 1)
            }
        }
        visit(hosting, path: "content", depth: 0)
        return observations
    }

    private static func silentAudio(in directory: URL) throws -> URL {
        // Five minutes of silent PCM enables real native pause/seek/queue checks.
        let bytes = UInt32(8000 * 2 * 300)
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func number<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        text("RIFF"); number(bytes + 36); text("WAVEfmt "); number(UInt32(16))
        number(UInt16(1)); number(UInt16(1)); number(UInt32(8000)); number(UInt32(16000))
        number(UInt16(2)); number(UInt16(16)); text("data"); number(bytes)
        data.append(Data(repeating: 0, count: Int(bytes)))
        let file = directory.appendingPathComponent("silent.wav")
        try data.write(to: file)
        return file
    }

    private static func fixtureArtwork() -> Data {
        // Deterministic test artwork exercises decoding, caching, and cover colors.
        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<128 {
            for x in 0..<128 {
                let line = Double((x + y) % 32) / 32
                image.setColor(NSColor(calibratedRed: 0.18 + line * 0.12,
                    green: 0.28 + Double(y) / 256, blue: 0.52 + Double(x) / 512, alpha: 1), atX: x, y: y)
            }
        }
        return image.representation(using: .png, properties: [:])!
    }
}

actor RedesignFixtureResponses {
    private var order = (0..<40).map { "occurrence\($0)" }

    func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        let url = request.url!
        if request.httpMethod != "GET" {
            print("Fixture API write: \(request.httpMethod ?? "") \(url.lastPathComponent)")
        }
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
                    "description": "A collection for unhurried listening.", "channelTitle": "Local acceptance fixture",
                    "thumbnails": ["medium": ["url": index == 8 ? "https://i.ytimg.com/vi/failed-fixture-cover/hqdefault.jpg" : "https://i.ytimg.com/vi/fixture0000/hqdefault.jpg"]]],
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
                    "thumbnails": ["medium": ["url": "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"]],
                    "resourceId": ["kind": "youtube#video", "videoId": videoID]]]
            }
            payload = ["items": rows]
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
