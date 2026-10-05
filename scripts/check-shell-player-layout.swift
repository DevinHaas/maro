// Compile alongside app sources excluding MaroApp.swift, linking MaroCore objects.
// Isolated full-shell fixture: local responses, real wide JPEG artwork, no live account/audio.
import AppKit
import SwiftUI
@testable import MaroCore

@main struct ShellPlayerLayoutCheck {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await runChecks()
                application.terminate(nil)
            } catch {
                FileHandle.standardError.write(Data("Layout fixture failed: \(error)\n".utf8))
                exit(1)
            }
        }
        // AppKit must process launch and accessibility events, beyond Swift's
        // async main executor, before SwiftUI publishes virtual AX descendants.
        application.run()
    }

    @MainActor private static func runChecks() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let image = NSImage(size: NSSize(width: 320, height: 180))
        image.lockFocus()
        NSColor(srgbRed: 0.12, green: 0.45, blue: 0.6, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 320, height: 180).fill()
        NSColor(srgbRed: 0.57, green: 0.85, blue: 0.72, alpha: 1).setFill()
        NSRect(x: 120, y: 0, width: 80, height: 180).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
        let artwork = output.appendingPathComponent("wide-artwork.jpg")
        try jpeg.write(to: artwork)
        let thumbnail = URL(string: "https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg")!
        let cachedResponse = HTTPURLResponse(url: thumbnail, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg", "Cache-Control": "public, max-age=3600"])!
        URLCache.shared.storeCachedResponse(CachedURLResponse(response: cachedResponse, data: jpeg), for: URLRequest(url: thumbnail))
        let video = try VideoSummary(id: "abcdefghijk",
            title: "A very long track title that must yield its width to the centered player transport",
            creator: "A creator whose name is also longer than the available title column", durationSeconds: 300,
            thumbnailURL: thumbnail)
        let controller = try MaroController(
            loaded: StateLoadResult(document: StateDocument(loadedVideo: try LoadedVideo(video: video, positionSeconds: 42)), preservedFile: nil, warning: nil),
            store: StateStore(file: output.appendingPathComponent("state.json")), engine: PlaybackEngine(),
            search: { _ in [] }, prepare: { _, _ in preconditionFailure("Fixture cannot prepare audio") })
        let api = YouTubePlaylists(token: { "local-fixture" }, send: { request in
            precondition(request.httpMethod == nil || request.httpMethod == "GET", "Fixture cannot write YouTube playlists")
            let body = Data(#"{"items":[]}"#.utf8)
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let library = PlaylistLibrary(controller: controller, api: api)
        library.playlists = (0..<12).map {
            YouTubePlaylist(id: "playlist\($0)", title: "Fixture playlist \($0 + 1)", count: 42, thumbnailURL: thumbnail)
        }
        let model = ApplicationModel(controller: controller, library: library)
        model.player.snapshot.localThumbnailPaths = [video.id: artwork.path]
        model.showFavorites()
        let hosting = NSHostingView(rootView: AppShellView(app: model, library: library))
        hosting.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 760),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        // SwiftUI creates its virtual accessibility tree when the hosting window
        // joins the WindowServer; an offscreen bitmap alone does not populate it.
        window.orderFront(nil)
        for width in [760, 900, 1024, 1200, 1440] {
            for collapsed in [false, true] {
                model.libraryCollapsed = collapsed
                // A hidden expanded-library filter must not remove the compact rail's destinations.
                model.libraryFilter = collapsed ? "no matching playlist" : ""
                let size = NSSize(width: width, height: 760)
                window.setContentSize(size)
                hosting.setFrameSize(size)
                try await Task.sleep(for: .milliseconds(180))
                hosting.layoutSubtreeIfNeeded()
                let elements = accessibilityElements(in: hosting)
                let transport = elements.first(where: { string($0, "accessibilityIdentifier") == "bottom-player-transport" })
                if collapsed, transport != nil {
                    precondition(elements.contains { string($0, "accessibilityLabel") == "Show library" })
                    precondition(elements.contains { string($0, "accessibilityLabel") == "Create playlist" })
                    precondition(elements.contains { string($0, "accessibilityLabel").hasPrefix("Favorites, Saved on this Mac") })
                    precondition(elements.contains { string($0, "accessibilityLabel").hasPrefix("Fixture playlist 1,") })
                    guard let rail = elements.first(where: { string($0, "accessibilityIdentifier") == "compact-library-rail" }) else {
                        preconditionFailure("Compact rail missing")
                    }
                    precondition(abs(rect(rail).width - 72) <= 0.5, "Compact rail must retain its 72-point footprint")
                }
                let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                let name = "shell-\(width)-\(collapsed ? "compact" : "expanded")"
                try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
                // Some standalone command-line hosts expose no virtual SwiftUI AX
                // descendants. Measure the actual rendered prominent Play circle
                // in the footer; local artwork lies outside this central crop.
                let scale = CGFloat(bitmap.pixelsWide) / CGFloat(width)
                var playPixels: [(Int, Int)] = []
                for y in Int(CGFloat(bitmap.pixelsHigh) - 92 * scale)..<bitmap.pixelsHigh {
                    for x in Int((CGFloat(width) / 2 - 80) * scale)..<Int((CGFloat(width) / 2 + 80) * scale) {
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                        // Native colour management changes exact encoded RGB
                        // values, so identify the bright green accent by channel
                        // relationship and verify its circle-sized bounds below.
                        if color.greenComponent > 0.7, color.redComponent > 0.4,
                           color.greenComponent > color.redComponent + 0.12,
                           color.greenComponent > color.blueComponent + 0.06 {
                            playPixels.append((x, y))
                        }
                    }
                }
                precondition(playPixels.count > Int(200 * scale * scale), "Native Play circle missing")
                let minX = playPixels.map { $0.0 }.min()!, maxX = playPixels.map { $0.0 }.max()!
                let minY = playPixels.map { $0.1 }.min()!, maxY = playPixels.map { $0.1 }.max()!
                let circleWidth = CGFloat(maxX - minX + 1) / scale
                let circleHeight = CGFloat(maxY - minY + 1) / scale
                precondition((35...40).contains(circleWidth) && (35...40).contains(circleHeight),
                    "Native accent pixels must form the 38-point Play circle, got \(circleWidth)×\(circleHeight)")
                let offset = CGFloat(minX + maxX + 1) / (2 * scale) - CGFloat(width) / 2
                precondition(abs(offset) <= 0.5, "Transport offset \(offset) at width \(width), collapsed \(collapsed)")
                let report: [String: Any] = ["width": width, "collapsed": collapsed, "nativeTransportCenterOffset": offset,
                    "measurement": "Actual native PNG Play circle accent bounds, converted from backing pixels to logical points",
                    "playCircleBounds": ["x": CGFloat(minX) / scale, "width": circleWidth, "height": circleHeight],
                    "swiftUIAccessibilityAvailable": transport != nil]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                    .write(to: output.appendingPathComponent(name + ".json"))
                print("PASS native transport midpoint: \(width) points, \(collapsed ? "compact" : "expanded"), offset \(offset)")
            }
        }
        await controller.shutdown()
        window.close()
    }

    @MainActor private static func string(_ object: NSObject, _ key: String) -> String {
        object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) as? String ?? "" : ""
    }
    @MainActor private static func rect(_ object: NSObject) -> NSRect {
        object.responds(to: NSSelectorFromString("accessibilityFrame"))
            ? (object.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue ?? .zero : .zero
    }
    @MainActor private static func accessibilityElements(in view: NSView) -> [NSObject] {
        var result: [NSObject] = []
        var visited: Set<ObjectIdentifier> = []
        func visit(_ object: NSObject, depth: Int) {
            guard depth < 40, visited.insert(ObjectIdentifier(object)).inserted else { return }
            result.append(object)
            guard object.responds(to: NSSelectorFromString("accessibilityChildren")) else { return }
            for child in object.value(forKey: "accessibilityChildren") as? [Any] ?? [] {
                if let element = child as AnyObject as? NSObject { visit(element, depth: depth + 1) }
            }
        }
        visit(view, depth: 0)
        return result
    }
}
