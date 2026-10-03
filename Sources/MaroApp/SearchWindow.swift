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
                let available = screen.visibleFrame.size
                window.minSize = NSSize(width: min(760, available.width - 16), height: min(560, available.height - 16))
                window.setFrame(Self.presentationFrame(size: window.frame.size, visible: screen.visibleFrame, anchorX: mouse.x), display: false)
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
}
private final class ApplicationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}
