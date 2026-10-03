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
                let artworkData = Self.fixtureArtwork()
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
                            headerFields: ["Content-Type": "image/png", "Cache-Control": "public, max-age=3600"])!
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
                    let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                        reason: "Capture settled native acceptance viewports")
                    defer { ProcessInfo.processInfo.endActivity(activity) }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    let viewportArgument = CommandLine.arguments.firstIndex(of: "--viewport").flatMap {
                        CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil
                    }
                    let routeArgument = CommandLine.arguments.firstIndex(of: "--route").flatMap {
                        CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil
                    }
                    for size in [NSSize(width: 1440, height: 900), NSSize(width: 1024, height: 768),
                                 NSSize(width: 1199, height: 900), NSSize(width: 1200, height: 900),
                                 NSSize(width: 1001, height: 900), NSSize(width: 1002, height: 900)] {
                        if let viewportArgument, viewportArgument != "\(Int(size.width))x\(Int(size.height))" { continue }
                        window.setContentSize(size)
                        for route in ["home", "preview", "playlist", "rows", "fallback", "favorites", "results", "empty", "error", "filter"] {
                            if let routeArgument, routeArgument != route { continue }
                            print("Settling \(route)-\(Int(size.width))x\(Int(size.height))")
                            fflush(stdout)
                            model.libraryFilter = ""
                            switch route {
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
                            case "favorites": model.showFavorites()
                            case "results", "empty", "error":
                                let timeout = DispatchWorkItem {
                                    FileHandle.standardError.write(Data("Fixture failed: timed out settling \(route) search\n".utf8))
                                    exit(EXIT_FAILURE)
                                }
                                DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
                                await controller.search(route == "results" ? "jazz" : route)
                                print("Search settled \(route)"); fflush(stdout)
                                timeout.cancel()
                                model.render(); print("Rendered \(route)"); fflush(stdout)
                                model.navigate(.search); print("Navigated \(route)"); fflush(stdout)
                            case "preview": model.showHome(); model.globalQuery = ""; model.focusSearch()
                            case "filter": model.showHome(); model.libraryFilter = "no matching collection"
                            default: model.showHome()
                            }
                            if route == "home" {
                                for _ in 0..<80 {
                                    if !model.home.isLoading { break }
                                    try await Task.sleep(for: .milliseconds(50))
                                }
                            }
                            try await Task.sleep(for: .milliseconds(350))
                            print("Paint ready \(route)"); fflush(stdout)
                            // Window managers may retile a fixture window; constrain the
                            // rendered content explicitly for repeatable viewport checks.
                            hosting.setFrameSize(size)
                            hosting.layoutSubtreeIfNeeded()
                            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds),
                                  let data = { () -> Data? in
                                      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                                      return bitmap.representation(using: .png, properties: [:])
                                  }() else { throw CocoaError(.fileWriteUnknown) }
                            let name = "\(route)-\(Int(size.width))x\(Int(size.height)).png"
                            try data.write(to: output.appendingPathComponent(name))
                            try Self.writeGeometry(hosting: hosting, window: window, route: route, size: size,
                                to: output.appendingPathComponent(name.replacingOccurrences(of: ".png", with: ".geometry.json")))
                            print("Captured \(name): logical content \(hosting.bounds.size), pixels \(bitmap.pixelsWide)×\(bitmap.pixelsHigh), window \(window.frame.size)")
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

    // Observe production boundaries without adding layout probes to production views.
    private static func writeGeometry(hosting: NSView, window: NSWindow, route: String, size: NSSize, to url: URL) throws {
        func frame(_ rect: NSRect) -> [Double] {
            let y = hosting.isFlipped ? rect.minY : hosting.bounds.height - rect.maxY
            return [rect.minX, y, rect.width, rect.height]
        }
        var accessibility: [[String: Any]] = []
        var visited = Set<ObjectIdentifier>()
        // Some SwiftUI AX children bridge value objects to temporary NSObject wrappers.
        // Retain each wrapper for the walk so recycled addresses cannot suppress siblings.
        var retainedElements: [AnyObject] = []
        func observe(_ object: Any, path: String) {
            let element = object as AnyObject
            guard let screenRect = element.accessibilityFrame?() else { return }
            let identifier = ObjectIdentifier(element as AnyObject)
            guard visited.insert(identifier).inserted else { return }
            retainedElements.append(element)
            let localRect = hosting.convert(window.convertFromScreen(screenRect), from: nil)
            var item: [String: Any] = ["path": path,
                "role": element.accessibilityRole?()?.rawValue ?? "unknown", "frame": frame(localRect),
                "enabled": element.isAccessibilityEnabled?() ?? false]
            if let label = element.accessibilityLabel?(), !label.isEmpty { item["label"] = label }
            if let native = object as? NSObject,
               native.responds(to: NSSelectorFromString("accessibilityValue")),
               let value = native.value(forKey: "accessibilityValue") as? String, !value.isEmpty { item["text"] = value }
            if localRect.width > 0 && localRect.height > 0 {
                item["center"] = [localRect.midX, hosting.isFlipped ? localRect.midY : hosting.bounds.height - localRect.midY]
            }
            accessibility.append(item)
            for (index, child) in (element.accessibilityChildren?() ?? []).enumerated() {
                observe(child, path: "\(path)/\(index)")
            }
        }
        observe(hosting, path: "content")
        var views: [[String: Any]] = []
        func observeView(_ view: NSView, path: String) {
            var item: [String: Any] = ["path": path, "class": String(describing: type(of: view)),
                "frame": frame(view.convert(view.bounds, to: hosting)), "hidden": view.isHidden]
            if let text = view as? NSTextField {
                item["text"] = text.stringValue
                item["firstBaselineOffsetFromTop"] = text.firstBaselineOffsetFromTop
                item["lastBaselineOffsetFromBottom"] = text.lastBaselineOffsetFromBottom
                if let font = text.font {
                    item["font"] = ["postScriptName": font.fontName, "pointSize": font.pointSize,
                        "ascender": font.ascender, "descender": font.descender, "leading": font.leading]
                }
            }
            if let control = view as? NSControl { item["enabled"] = control.isEnabled }
            views.append(item)
            for (index, child) in view.subviews.enumerated() { observeView(child, path: "\(path)/\(index)") }
        }
        observeView(hosting, path: "content")
        let value: [String: Any] = ["schemaVersion": 1, "route": route,
            "coordinateSpace": "content-top-left-logical-points", "viewport": [size.width, size.height],
            "backingScale": window.backingScaleFactor, "accessibility": accessibility, "views": views,
            "limitations": [
                "Accessibility text rectangles are exposed AX bounds, not glyph ink bounds or typographic baselines.",
                "SwiftUI Text baselines and font descriptors are not exposed by the native NSView/AX tree; measure rendered glyphs separately.",
                "AX control frames and centers do not prove custom contentShape hit regions; only native bridge view bounds are observed.",
                "SwiftUI internal spacing/columns/overlay anchors are not individually exposed; use capture and production layout constants as supplemental reconstruction evidence."]]
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
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
