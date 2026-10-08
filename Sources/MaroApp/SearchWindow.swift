import AppKit
import MaroCore
import SwiftUI

/// Persistent native application window; the compact player shares this controller.
@MainActor final class SearchWindow: NSWindowController {
    let application: ApplicationModel
    private let library: PlaylistLibrary
    init(controller: MaroController, cacheDirectory: URL, playlistLibrary: PlaylistLibrary? = nil) {
        library = playlistLibrary ?? PlaylistLibrary(controller: controller)
        application = ApplicationModel(controller: controller, library: library)
        let panel = ApplicationPanel(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        panel.title = "Maro"
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = .black
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 760, height: 560)
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        let hosting = NSHostingView(rootView: AppShellView(app: application, library: library))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.center()
    }
    required init?(coder: NSCoder) { nil }
    func offerAdd(_ video: VideoSummary) { application.offerAdd(video); present() }
    func render() { application.render() }
    func present() {
        if let window, !window.isVisible {
            let mouse = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
                var visible = screen.visibleFrame
                let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                    as? [[String: Any]] ?? []
                if let bottom = Self.topBarBottom(screen: screen.frame, windows: windows,
                        desktopTop: NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY) {
                    visible.size.height = max(0, min(visible.maxY, bottom) - visible.minY)
                }
                let available = visible.size
                window.minSize = NSSize(width: min(760, available.width - 16), height: min(560, available.height - 16))
                window.setFrame(Self.presentationFrame(size: window.frame.size, visible: visible, anchorX: mouse.x), display: false)
            }
        }
        showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if library.connected && library.playlists.isEmpty && !library.busy { library.refresh() }
        render()
    }
    static func presentationFrame(size: NSSize, visible: NSRect, anchorX: CGFloat) -> NSRect {
        let inset = visible.insetBy(dx: min(8, visible.width / 4), dy: min(8, visible.height / 4))
        let width = min(size.width, inset.width), height = min(size.height, inset.height)
        return NSRect(x: max(inset.minX, min(anchorX - width / 2, inset.maxX - width)),
            y: inset.maxY - height, width: width, height: height)
    }
    /// Bottom edge of an always-on-top bar (e.g. SketchyBar) across the top of `screen`.
    /// `visibleFrame` ignores such bars, which would otherwise cover the title bar and block dragging.
    static func topBarBottom(screen: NSRect, windows: [[String: Any]], desktopTop: CGFloat,
                             ownPID: Int = Int(ProcessInfo.processInfo.processIdentifier)) -> CGFloat? {
        windows.compactMap { info -> CGFloat? in
            guard (info[kCGWindowLayer as String] as? Int ?? 0) > 0,
                  info[kCGWindowOwnerPID as String] as? Int != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: bounds) else { return nil }
            // Window server uses global top-left coordinates; AppKit uses bottom-left.
            let rect = NSRect(x: cg.minX, y: desktopTop - cg.maxY, width: cg.width, height: cg.height)
            // Bars may float a few points below the edge (SketchyBar y_offset), so accept any in the top quarter.
            guard rect.minY >= screen.maxY - screen.height / 4, rect.minY < screen.maxY,
                  rect.intersection(screen).width >= screen.width / 2 else { return nil }
            return rect.minY
        }.min()
    }
}
private final class ApplicationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}
