// Hosted application-window check for Vim navigation (docs/specs/vim-navigation.md).
// Real key events go through AppKit's queue, local monitors and the responder chain; focus is observed
// through accessibility and the rendered bitmap. Deterministic local data, no network, no audio.
// Runs in the background: fixture windows are transparent, click-through and report key status
// themselves, so the application never activates or takes the keyboard; a sheet is checked the same way. Compile like the other hosted checks:
//   swiftc -parse-as-library -I .build/arm64-apple-macosx/debug/Modules scripts/check-vim-navigation.swift \
//     $(find Sources/MaroApp -name '*.swift' ! -name MaroApp.swift) .build/arm64-apple-macosx/debug/MaroCore.build/*.o -o /tmp/maro-vim-check
import AppKit
import SwiftUI
@testable import MaroCore

@main struct VimNavigationCheck {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await runChecks()
                print("PASS vim navigation")
                application.terminate(nil)
            } catch {
                FileHandle.standardError.write(Data("FAIL vim navigation: \(error)\n".utf8))
                exit(1)
            }
        }
        application.run()
    }

    final class FixtureWindow: NSWindow {
        var key = false
        override var isKeyWindow: Bool { key || attachedSheet != nil && false }
        override var canBecomeKey: Bool { true }
    }

    struct Failure: Error, CustomStringConvertible { let description: String }
    static func check(_ condition: Bool, _ message: @autoclosure () -> String) throws {
        if !condition { throw Failure(description: message()) }
    }

    actor Recorder {
        var ids: [String] = []
        func record(_ id: String) { ids.append(id) }
    }

    @MainActor static var window: NSWindow!
    @MainActor static var hosting: NSView!

    @MainActor private static func runChecks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("maro-vim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func videos(_ prefix: String, _ title: String, count: Int) throws -> [VideoSummary] {
            try (0..<count).map { try VideoSummary(id: prefix + String(format: "%010d", $0), title: "\(title) \($0)", creator: "Creator \($0)", durationSeconds: 200) }
        }
        let home = try videos("h", "Track", count: 12)
        let first = try videos("f", "First", count: 30)
        let second = try videos("s", "Second", count: 5)
        let prepared = Recorder()
        let controller = try MaroController(
            loaded: StateLoadResult(document: StateDocument(loadedVideo: try LoadedVideo(video: home[0], positionSeconds: 0)), preservedFile: nil, warning: nil),
            store: StateStore(file: directory.appendingPathComponent("state.json")), engine: PlaybackEngine(),
            search: { query in query == "first" ? first : query == "second" ? second : home },
            prepare: { video, _ in await prepared.record(video.id); throw CancellationError() })
        let api = YouTubePlaylists(token: { "fixture" }, send: { request in
            (Data(#"{"items":[]}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let library = PlaylistLibrary(controller: controller, api: api)
        library.playlists = (0..<30).map { YouTubePlaylist(id: "playlist\($0)", title: "Playlist \($0 + 1)", count: 3) }
        let app = ApplicationModel(controller: controller, library: library)
        app.vim.enabled = true
        hosting = NSHostingView(rootView: AppShellView(app: app, library: library))
        window = FixtureWindow(contentRect: NSRect(x: 80, y: 80, width: 1100, height: 720),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        try await makeKey(window)
        publishAccessibility()
        for _ in 0..<100 where app.home.isLoading || app.home.sections.contains(where: \.videos.isEmpty) { try await settle(50) }
        try await settle(600)
        var log: [String] = []
        func step(_ key: String, _ times: Int = 1) async throws -> String {
            for _ in 0..<times { try await press(key) }
            let label = focusedLabel()
            log.append("\(key)×\(times) → \(label)")
            return label
        }

        // First key shows focus on the first visible content target, not SwiftUI's automatic top-bar focus.
        let start = try await step("j")
        try check(start == "Open playlist", "first key focused \(start)")
        try check(highlightVisible(), "focused target must show the focus highlight")
        // Four directions over the Home shortcut grid. Its column count depends on layout, so assert the
        // observable geometry: each move lands beyond the origin in that direction and aligned with it.
        func moves(_ key: String, prefix: String) async throws {
            let from = focusedFrame()
            let label = try await step(key)
            let to = focusedFrame()
            let aligned = key == "j" || key == "k" ? to.minX < from.maxX && to.maxX > from.minX : to.minY < from.maxY && to.maxY > from.minY
            let ahead = switch key {
            case "j": to.minY >= from.maxY - 4
            case "k": to.maxY <= from.minY + 4
            case "l": to.minX >= from.maxX - 4
            default: to.maxX <= from.minX + 4
            }
            try check(label.hasPrefix(prefix) && aligned && ahead, "\(key) from \(from) to \(label) \(to): \(log)")
        }
        try await moves("j", prefix: "Open ")
        for _ in 0..<3 where !focusedLabel().hasPrefix("Play Playlist") { try await moves("l", prefix: "") }
        try await moves("h", prefix: "Open Playlist")
        try await moves("j", prefix: "Open ")
        try await moves("l", prefix: "Play ")
        try await moves("k", prefix: "Play Playlist")
        // Favorites is empty, so its disabled play button is never a destination.
        try check(!log.contains { $0.hasSuffix("Play Favorites in saved order") }, "disabled control focused: \(log)")
        // Moving never activates; Return runs the focused control's own action.
        let preparedAfterMoves = await prepared.ids
        try check(app.route == .home && preparedAfterMoves.isEmpty, "movement must not activate")

        // Horizontal album row: l reveals clipped, lazily laid out cards before leaving the row.
        for _ in 0..<6 where !focusedLabel().hasPrefix("Play Track") { _ = try await step("j") }
        func card(_ label: String) -> Int? {
            label.hasPrefix("Play Track ") ? Int(label.dropFirst(11).prefix { $0.isNumber }) : nil
        }
        let entry = try require(card(focusedLabel()), "album row entry: \(log)")
        var cards: [Int] = [entry]
        for _ in 0..<(14 - entry) { cards.append(try require(card(try await step("l")), "card: \(log)")) }
        let last = try require(cards.last, "cards")
        try check(last > entry + 2 && cards == Array(entry...last) + Array(repeating: last, count: cards.count - (last - entry + 1))
            && cards.suffix(2).allSatisfy { $0 == last }, "row order (consecutive, then held at the row's end): \(cards)")
        try check(focusedFrameVisible(), "scrolled card must be visible")
        try await press("\r"); try await settle(300)
        let preparedAfterReturn = await prepared.ids
        try check(preparedAfterReturn == [home[last].id], "Return must play the focused card, got \(preparedAfterReturn)")

        // Region crossing: h leaves content for the sidebar only at the row's real start.
        var back: [Int] = []
        for _ in 0..<last { back.append(try require(card(try await step("h")), "card: \(log)")) }
        try check(back == Array((0..<last).reversed()), "row back: \(back)")
        let sidebar = try await step("h")
        try check(sidebar.hasPrefix("Playlist ") || sidebar.hasPrefix("Favorites"), "h at content edge reaches the sidebar: \(log.suffix(3))")

        // Sidebar list: j scrolls the clipped list and stays in it until its actual end.
        var rows: [String] = []
        for _ in 0..<40 { rows.append(try await step("j")) }
        try check(rows.contains("Playlist 30, Playlist · 3 videos"), "sidebar end reached: \(rows)")
        try check(rows.last?.hasPrefix("Playlist") == false, "after the list's end j reaches another region: \(rows.suffix(3))")

        // Vertical clipped list (search results) with lazy rows; inactive Home stays excluded.
        app.submitSearch("first")
        for _ in 0..<100 where app.searchState.isSearching { try await settle(30) }
        try await settle(400)
        try await click(nil)
        var results: [String] = [try await step("j")]
        for _ in 0..<40 { results.append(try await step("j")) }
        let rowsSeen = results.filter { $0.hasPrefix("Play First ") && $0.contains(" by ") }
        let lastResult = app.searchState.results.count - 1
        try check(lastResult > 10 && rowsSeen == (0...lastResult).map { "Play First \($0) by Creator \($0)" }, "search rows in order to the end: \(results)")
        try check(!results.contains { $0.hasPrefix("Play Track") || $0 == "Explore suggestions" || $0.hasPrefix("Open ") },
            "hidden Home targets must be excluded: \(results)")
        try check(["Play", "Pause", "Toggle favorite", "Previous", "Next"].contains(results.last ?? ""),
            "j past the last result reaches the player: \(results.suffix(4))")

        // Changing content: the focused result disappears; the next key lands on a current target.
        _ = try await step("k", 3)
        app.submitSearch("second")
        for _ in 0..<100 where app.searchState.isSearching { try await settle(30) }
        try await settle(400)
        let recovered = try await step("j")
        try check(!recovered.contains("First"), "stale result focused after content change: \(recovered)")

        // Resizing: movement follows the current layout and lands on a visible target.
        window.setContentSize(NSSize(width: 820, height: 600))
        try await settle(400)
        _ = try await step("j", 2)
        try check(focusedFrameVisible(), "focus after resize must be visible")

        // Text entry keeps h/j/k/l as letters; search keeps arrows, Escape and Return.
        let field = try searchField()
        window.makeFirstResponder(field)
        try await settle()
        for key in ["h", "j", "k", "l"] { try await press(key) }
        try check(app.globalQuery == "hjkl", "search field must receive letters, got \(app.globalQuery)")
        for _ in 0..<50 where app.previewVideos.isEmpty || app.previewLoading { try await settle(50) }
        try await press("", keyCode: 125)
        try check(app.previewOpen && app.previewFocusedIndex == 0, "down arrow must move the search preview")
        try await press("", keyCode: 53)
        try check(!app.previewOpen, "Escape must close the search preview")
        window.makeFirstResponder(field); try await settle()
        try await press("\r"); try await settle(300)
        try check(app.route == .search && app.searchState.query == "hjkl", "Return must submit the search")

        // Timeline keeps arrow-key seeking.
        app.player.snapshot.timeline = PlaybackTimeline(duration: 100, ranges: [0...100])
        app.player.snapshot.timelineID = UUID()
        try await settle(300)
        let slider = try descendant(of: hosting) { $0.accessibilityIdentifier() == "playback-position" } as! NSSlider
        window.makeFirstResponder(slider)
        let before = slider.doubleValue
        try await press("", keyCode: 124)
        try check(slider.doubleValue == before + 5, "timeline arrow seek: \(before) → \(slider.doubleValue)")

        // Tab still moves focus normally.
        try await click(nil)
        try await press("\t")
        try check(!focusedLabel().isEmpty && highlightVisible(), "Tab must move visible focus")

        // Modal containment: an open sheet confines navigation, Return activates inside it.
        app.offerAdd(first[0])
        try await settle(600)
        let sheet = try require(window.attachedSheet, "sheet")
        var sheetLabels: [String] = []
        for key in ["j", "l", "h", "k", "l"] { try await press(key, in: sheet); sheetLabels.append(focusedLabel(in: sheet)) }
        try check(sheetLabels.allSatisfy { $0 == "Cancel" || $0 == "Add" }, "sheet navigation escaped: \(sheetLabels)")
        try check(focusedLabel(in: sheet) == "Cancel", "Add is disabled without a destination: \(sheetLabels)")
        try await press("\r", in: sheet); try await settle(500)
        try check(library.pendingVideo == nil && window.attachedSheet == nil, "Return must run Cancel")

        // Vim navigation can be switched off with its own control; letters then do nothing.
        try await click(nil)
        _ = try await step("j")
        for _ in 0..<6 where focusedFrame().minY > 64 { _ = try await step("k") } // Into the top bar…
        for _ in 0..<6 where focusedLabel() != "Turn off Vim navigation" { _ = try await step("l") } // …then along it.
        try check(focusedLabel() == "Turn off Vim navigation", "toggle reachable: \(log.suffix(6))")
        try await press("\r")
        try check(!app.vim.enabled, "toggle must disable Vim navigation")
        let disabledFocus = focusedLabel()
        try await press("j"); try await press("h")
        try check(focusedLabel() == disabledFocus, "disabled Vim navigation must not move focus")
        app.vim.enabled = true
        try await settle()

        // Another window keeps its input; the application window's focus does not move.
        _ = try await step("j")
        let held = focusedLabel()
        let other = FixtureWindow(contentRect: NSRect(x: 300, y: 300, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        try await makeKey(other)
        for key in ["j", "j", "l"] { try await press(key, in: other) }
        other.close()
        try await makeKey(window)
        try check(focusedLabel() == held, "other-window input moved focus: \(held) → \(focusedLabel())")

        // Adversarial alignment: a closer diagonal target loses to the aligned target in the next row.
        try await adversarialAlignment()

        await controller.shutdown()
        window.close()
    }

    /// Origin at the top-left; a closer target down-right; the corresponding target straight below.
    @MainActor private static func adversarialAlignment() async throws {
        let navigator = VimNavigator()
        navigator.enabled = true
        let view = ZStack(alignment: .topLeading) {
            Button("Origin") {}.vimTarget {}.frame(width: 120, height: 40).position(x: 80, y: 40)
            Button("Diagonal") {}.vimTarget {}.frame(width: 120, height: 40).position(x: 210, y: 100)
            Button("Below") {}.vimTarget {}.frame(width: 120, height: 40).position(x: 80, y: 180)
        }.frame(width: 360, height: 260).vimRegion("content").vimNavigation(navigator)
        let fixture = FixtureWindow(contentRect: NSRect(x: 200, y: 200, width: 360, height: 260), styleMask: [.titled], backing: .buffered, defer: false)
        fixture.isReleasedWhenClosed = false
        fixture.contentView = NSHostingView(rootView: view)
        try await makeKey(fixture)
        try await settle(300)
        try await press("j", in: fixture)
        try check(focusedLabel(in: fixture) == "Origin", "fixture start: \(focusedLabel(in: fixture))")
        try await press("j", in: fixture)
        try check(focusedLabel(in: fixture) == "Below", "alignment must beat proximity, got \(focusedLabel(in: fixture))")
        fixture.close()
    }

    // MARK: Harness

    @MainActor static func require<T>(_ value: T?, _ name: String) throws -> T {
        guard let value else { throw Failure(description: "missing \(name)") }
        return value
    }
    /// Key status without activating the application, so the check never takes the user's keyboard.
    @MainActor static func makeKey(_ target: NSWindow) async throws {
        for case let other as FixtureWindow in NSApp.windows { other.key = false }
        (target as? FixtureWindow)?.key = true
        // On screen (SwiftUI only publishes accessibility there) but behind other windows and click-through.
        target.ignoresMouseEvents = true
        target.orderBack(nil)
        try await settle(100)
    }
    @MainActor static func settle(_ milliseconds: Int = 200) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
        hosting.layoutSubtreeIfNeeded()
    }
    /// Posts a real key event into the application's queue so monitors and the responder chain see it.
    @MainActor static func press(_ characters: String, keyCode: UInt16 = 0, in target: NSWindow? = nil) async throws {
        let codes: [String: UInt16] = ["h": 4, "j": 38, "k": 40, "l": 37, "\r": 36, "\t": 48]
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: (target ?? window).windowNumber, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: codes[characters] ?? keyCode)!
        NSApp.postEvent(event, atStart: false)
        try await settle(300)
    }
    /// A real click on an empty area of the window (hides keyboard focus, as a pointer user would).
    @MainActor static func click(_ point: NSPoint?) async throws {
        let location = point ?? NSPoint(x: 6, y: 6) // Window coordinates: the empty bottom-left corner.
        window.ignoresMouseEvents = false
        defer { window.ignoresMouseEvents = true }
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            NSApp.postEvent(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!, atStart: false)
        }
        try await settle()
    }

    /// The focused target as the user sees it: the labelled control the focus highlight (#B5F3E8) surrounds.
    /// Accessibility focus is only published for an active application, which this background check avoids.
    @MainActor static func focusedElement(in target: NSWindow? = nil) -> NSObject? {
        let window = target ?? window!
        guard let root = window.contentView, let highlight = highlightRect(in: root) else { return nil }
        let labelled = accessibilityElements(in: root).filter { !string($0, "accessibilityLabel").isEmpty }
            .map { ($0, frame(of: $0, in: root, window: window)) }
        func distance(_ frame: NSRect) -> CGFloat {
            abs(frame.minX - highlight.minX) + abs(frame.minY - highlight.minY) + abs(frame.maxX - highlight.maxX) + abs(frame.maxY - highlight.maxY)
        }
        guard let best = labelled.min(by: { distance($0.1) < distance($1.1) }),
              abs(best.1.midX - highlight.midX) < 6, abs(best.1.midY - highlight.midY) < 6 else { return nil }
        return best.0
    }
    /// SwiftUI publishes its accessibility tree once an assistive client asks; an inactive app is
    /// otherwise never asked. One client request from a helper thread (the main run loop keeps serving it).
    @MainActor static func publishAccessibility() {
        let semaphore = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            var focused: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(getpid()), kAXFocusedUIElementAttribute as CFString, &focused)
            semaphore.signal()
        }
        // Keep serving accessibility requests on the main run loop while the client thread waits.
        let deadline = Date().addingTimeInterval(3)
        while semaphore.wait(timeout: .now()) == .timedOut && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }
    @MainActor static func frame(of element: NSObject, in root: NSView, window: NSWindow) -> NSRect {
        guard let screen = (element.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue else { return .zero }
        return root.convert(window.convertFromScreen(screen), from: nil)
    }
    @MainActor static func focusedLabel(in target: NSWindow? = nil) -> String { focusedElement(in: target).map { string($0, "accessibilityLabel") } ?? "" }
    @MainActor static func focusedFrame() -> NSRect { highlightRect(in: hosting) ?? .zero }
    @MainActor static func focusedFrameVisible() -> Bool {
        let frame = focusedFrame()
        return !frame.isEmpty && hosting.bounds.contains(frame)
    }
    @MainActor static func highlightVisible() -> Bool { highlightRect(in: hosting) != nil }
    /// Bounding box, in the view's flipped coordinates, of pixels drawn in the focus colour.
    @MainActor static func highlightRect(in view: NSView) -> NSRect? {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let image = bitmap.cgImage, let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let reference = NSColor(srgbRed: 0xB5 / 255, green: 0xF3 / 255, blue: 0xE8 / 255, alpha: 1).usingColorSpace(NSColorSpace(cgColorSpace: image.colorSpace!)!)!
        let target = [reference.redComponent, reference.greenComponent, reference.blueComponent].map { Int($0 * 255) }
        let alphaFirst = [.first, .premultipliedFirst, .noneSkipFirst].contains(image.alphaInfo)
        let bgr = image.byteOrderInfo == .order32Little
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1, count = 0
        for y in 0..<image.height {
            let row = bytes + y * image.bytesPerRow
            for x in 0..<image.width {
                let pixel = row + x * 4
                var channels = [Int(pixel[0]), Int(pixel[1]), Int(pixel[2]), Int(pixel[3])]
                if bgr { channels.reverse() }
                let rgb = alphaFirst ? Array(channels[1...3]) : Array(channels[0...2])
                guard abs(rgb[0] - target[0]) < 14, abs(rgb[1] - target[1]) < 14, abs(rgb[2] - target[2]) < 14 else { continue }
                count += 1
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard count > 40 else { return nil }
        let scale = CGFloat(image.width) / view.bounds.width
        return NSRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale, width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
    }
    @MainActor static func searchField() throws -> NSTextField {
        try descendant(of: hosting) { ($0 as? NSTextField)?.placeholderAttributedString?.string == "What do you want to play?" } as! NSTextField
    }
    @MainActor static func descendant(of view: NSView, where matches: (NSView) -> Bool) throws -> NSView {
        if matches(view) { return view }
        for child in view.subviews { if let found = try? descendant(of: child, where: matches) { return found } }
        throw Failure(description: "view not found")
    }

    @MainActor static func string(_ object: NSObject, _ key: String) -> String {
        object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) as? String ?? "" : ""
    }
    @MainActor static func accessibilityElements(in view: NSView) -> [NSObject] {
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
