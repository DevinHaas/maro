// Compile alongside app sources excluding MaroApp.swift, linking MaroCore objects.
// Renders native views with isolated fixture state; no network or audio preparation.
import AppKit
import SwiftUI
@testable import MaroCore

@main
struct CardCheck {
    @MainActor static func main() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let artworkPath: String
        if CommandLine.arguments.count > 2 {
            artworkPath = CommandLine.arguments[2]
        } else {
            // A wide real image exercises scaledToFill clipping; a symbol cannot reveal overflow.
            let image = NSImage(size: NSSize(width: 320, height: 180))
            image.lockFocus()
            NSColor(srgbRed: 0.12, green: 0.45, blue: 0.6, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 320, height: 180).fill()
            NSColor(srgbRed: 0.57, green: 0.85, blue: 0.72, alpha: 1).setFill()
            NSRect(x: 120, y: 0, width: 80, height: 180).fill()
            image.unlockFocus()
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
            let file = output.appendingPathComponent("artwork-fixture.jpg")
            try data.write(to: file)
            artworkPath = file.path
        }
        precondition(NSImage(contentsOfFile: artworkPath) != nil, "Artwork fixture must be readable")
        let normal = try VideoSummary(id: "abcdefghijk", title: "You Know You Like It", creator: "DJ Snake · You Know You Like It", durationSeconds: 247)
        let long = try VideoSummary(id: "abcdefghijk", title: "Mischa Maisky plays Bach Cello Suite No. 1 — a long title that remains readable", creator: "Stealth banning")
        let longDuration = try VideoSummary(id: "abcdefghijk", title: "Deep Focus Lofi Mix", creator: "Chill Village", durationSeconds: 42898)
        let maximumDuration = try VideoSummary(id: "abcdefghijk", title: "Long ambience", creator: "Chill Village", durationSeconds: 359999)
        let store = StateStore(file: output.appendingPathComponent("isolated-state.json"))
        let document = StateDocument(loadedVideo: try LoadedVideo(video: normal, positionSeconds: 128))
        var preparations = 0
        let controller = try MaroController(loaded: StateLoadResult(document: document, preservedFile: nil, warning: nil),
            store: store, engine: PlaybackEngine(), search: { _ in [] }, prepare: { _, _ in
                preparations += 1
                throw SourceFailure.noCompatibleAudio
            })
        let model = ApplicationModel(controller: controller, library: PlaylistLibrary(controller: controller))
        var cardSizes: [String: NSSize] = [:]
        for (name, video, state, selecting, needsUpdate, error) in [
            ("paused", normal, PlaybackState.paused, false, false, Optional<String>.none),
            ("playing", normal, .playing, false, false, nil),
            ("ended", normal, .ended, false, false, nil),
            ("preparing", normal, .paused, true, false, nil),
            ("preparing-reduced-motion", normal, .paused, true, false, nil),
            ("preparing-first-track", normal, .paused, true, false, nil),
            ("buffering", normal, .buffering, false, false, nil),
            ("buffering-unavailable", normal, .buffering, false, false, nil),
            ("long-unknown-duration", long, .paused, false, false, nil),
            ("long-duration", longDuration, .paused, false, false, nil),
            ("maximum-duration", maximumDuration, .paused, false, false, nil),
            ("source-update", normal, .paused, false, true, nil),
            ("first-result", normal, .paused, false, false, nil),
            ("last-result", normal, .paused, false, false, nil),
            ("outside-results", normal, .paused, false, false, nil),
            ("favorites", normal, .paused, false, false, nil),
            ("error", normal, .paused, false, false, "This video is unavailable. Try another result.")
        ] {
            let position = name == "long-duration" ? 16996.829 : name == "maximum-duration" ? 359998 : 128.0
            var snapshot = PlayerSnapshot(loadedVideo: name == "preparing-first-track" ? nil : try LoadedVideo(video: video, positionSeconds: position),
                favorites: [video], playback: state, isSelecting: selecting, sourceNeedsUpdate: needsUpdate,
                error: error, persistenceError: nil,
                canGoPrevious: name != "first-result" && name != "outside-results",
                canGoNext: name != "last-result" && name != "outside-results")
            if name != "long-unknown-duration" {
                snapshot.localThumbnailPaths = [video.id: artworkPath]
            }
            if !selecting && !needsUpdate && name != "buffering-unavailable", let duration = video.durationSeconds {
                snapshot.timeline = PlaybackTimeline(duration: duration, ranges: [0...duration])
                snapshot.playbackID = UUID()
                snapshot.timelineID = UUID()
            }
            let presentation = PlayerPresentation(snapshot: snapshot)
            var actions = 0
            var volumeUpdates: [Double] = []
            let view = NSHostingView(rootView: PlayerCard(presentation: presentation, app: model,
                action: { _, _ in actions += 1 }, search: { actions += 1 },
                hide: { actions += 1 },
                setVolume: { volumeUpdates.append($0) }, favorites: name == "favorites")
                .environment(\.skeletonReduceMotionOverride, name == "preparing-reduced-motion"))
            let size = view.fittingSize
            cardSizes[name] = size
            precondition(size.width == 430 && size.height >= 90 && size.height <= 230, "Unexpected card dimensions: \(size)")
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            view.frame = NSRect(origin: .zero, size: size)
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(100))
            view.layoutSubtreeIfNeeded()
            func renderPNG() -> Data {
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No native bitmap") }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
                return data
            }
            let data = renderPNG()
            try data.write(to: output.appendingPathComponent(name + ".png"))
            if selecting {
                try await Task.sleep(for: .milliseconds(400))
                let later = renderPNG()
                try later.write(to: output.appendingPathComponent(name + "-later.png"))
                if name == "preparing-reduced-motion" {
                    precondition(data == later, "Reduced Motion must keep loading placeholders still")
                } else {
                    precondition(data != later, "Loading shimmer must animate in the native player")
                }
            }
            precondition(actions == 0, "Rendering must not trigger playback or search")
            precondition(volumeUpdates.isEmpty, "Rendering must not change volume")
            if name != "favorites" {
                func findSlider(_ node: NSView) -> NSSlider? {
                    if let slider = node as? NSSlider, !(slider is TimelineSlider) { return slider }
                    return node.subviews.lazy.compactMap { findSlider($0) }.first
                }
                let slider = findSlider(view)!
                precondition(!slider.isVertical && slider.minValue == 0 && slider.maxValue == 1)
                slider.doubleValue = 0.25
                slider.sendAction(slider.action, to: slider.target)
                precondition(volumeUpdates == [0.25], "Native volume slider must forward changes")
            }
            print("PASS: \(name) native render \(Int(size.width))×\(Int(size.height)); no actions fired")
            window.close()
        }
        precondition(cardSizes["paused"] == cardSizes["preparing"], "Preparation must not change player height")
        let player = PlayerWindow(application: model, openSearch: {})
        func waitForCard() async throws {
            for _ in 0..<100 {
                if player.window?.isVisible == true { return }
                try await Task.sleep(for: .milliseconds(20))
            }
            preconditionFailure("Player did not open")
        }
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let anchorData = Data(#"{"bounding_rects":{"display-1":{"origin":[820,5],"size":[280,35]}}}"#.utf8)
        let anchor = PlayerWindow.anchorRect(anchorData, screen: screen, desktopTop: 1080)!
        let origin = PlayerWindow.cardOrigin(size: NSSize(width: 430, height: 198), screen: screen,
            visible: screen, anchor: anchor)
        precondition(origin.x + 215 == anchor.midX && origin.y == anchor.minY - 8)
        let secondary = NSRect(x: -1920, y: 200, width: 1920, height: 1080)
        let secondaryData = Data(#"{"bounding_rects":{"display-2":{"origin":[-1100,-195],"size":[280,35]}}}"#.utf8)
        let secondaryAnchor = PlayerWindow.anchorRect(secondaryData, screen: secondary, desktopTop: 1080)!
        precondition(secondaryAnchor.midX == secondary.midX && secondaryAnchor.maxY == secondary.maxY - 5)
        precondition(PlayerWindow.anchorRect(anchorData, screen: secondary, desktopTop: 1080) == nil)
        let hiddenAnchor = Data(#"{"geometry":{"drawing":"off"},"bounding_rects":{"display-1":{"origin":[820,5],"size":[280,35]}}}"#.utf8)
        precondition(PlayerWindow.anchorRect(hiddenAnchor, screen: screen, desktopTop: 1080) == nil,
            "The card must ignore a hidden centered anchor on notched displays")
        precondition(PlayerWindow.anchorRect(Data("{}".utf8), screen: screen, desktopTop: 1080) == nil)
        precondition(PlayerWindow.cardOrigin(size: NSSize(width: 430, height: 198), screen: screen,
            visible: screen, anchor: nil).x == 745)
        player.toggle()
        player.toggle()
        try await Task.sleep(for: .milliseconds(600))
        precondition(player.window?.isVisible == false, "A second click must cancel pending opening")
        player.toggle()
        try await waitForCard()
        precondition(player.window?.isVisible == true)
        player.toggle()
        precondition(player.window?.isVisible == false)
        player.toggle()
        try await waitForCard()
        precondition(player.window?.isVisible == true)
        let card = (player.window!.contentView as! NSHostingView<PlayerCard>).rootView
        card.hide()
        precondition(player.window?.isVisible == false, "Hide button must dismiss the player")
        player.toggle()
        try await waitForCard()
        precondition(player.window?.isVisible == true, "Player must reopen after hiding")
        player.window?.cancelOperation(nil)
        precondition(player.window?.isVisible == false)
        precondition(controller.snapshot.playback == .paused && controller.snapshot.loadedVideo?.positionSeconds == 128)
        precondition(preparations == 0, "Opening or closing the player prepared audio")
        print("PASS: native window toggle/hide/reopen/Escape preserves paused state without preparing audio")
    }
}
