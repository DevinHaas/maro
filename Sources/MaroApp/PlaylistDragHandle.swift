import AppKit
import MaroCore
import SwiftUI

/// A native drag source occupies only the handle; play and action buttons never start a drag.
struct PlaylistDragHandle: NSViewRepresentable {
    let item: YouTubePlaylistItem
    let playlistID: String
    let localPath: String?
    @ObservedObject var library: PlaylistLibrary

    func makeNSView(context: Context) -> PlaylistDragHandleView { PlaylistDragHandleView() }
    static func dismantleNSView(_ view: PlaylistDragHandleView, coordinator: Void) { view.stopInputMonitoring() }
    func updateNSView(_ view: PlaylistDragHandleView, context: Context) {
        view.item = item; view.playlistID = playlistID; view.library = library
        view.enabled = library.canReorder && item.resourceVideoID != nil
        view.setAccessibilityLabel("Reorder \(item.title). Use Actions to move to a position with the keyboard.")
        view.loadArtwork(localPath: localPath, remoteURL: item.video?.thumbnailURL)
        view.needsDisplay = true
    }
}

@MainActor final class PlaylistDragHandleView: NSView, NSDraggingSource {
    var item: YouTubePlaylistItem?
    var playlistID = ""
    weak var library: PlaylistLibrary?
    var enabled = false
    private var startEvent: NSEvent?
    private var isDragging = false
    private var edgeTimer: Timer?
    private weak var sourceScrollView: NSScrollView?
    private var artwork: NSImage?
    private var artworkURL: URL?
    private var inputMonitor: Any?
    private var bridgedMouseSequence = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.image)
        toolTip = "Drag to reorder. Actions offers Move to position."
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopInputMonitoring()
        guard window != nil else { return }
        // SwiftUI can hit-test its row container ahead of an embedded NSView. Route only
        // real events inside this handle; AppKit owns the gesture once its drag starts.
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            switch event.type {
            case .leftMouseDown:
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.enabled, !self.isDragging, self.bounds.contains(point), self.visibleRect.contains(point),
                      let content = window.contentView,
                      content.hitTest(content.convert(event.locationInWindow, from: nil)) !== self else { return event }
                self.bridgedMouseSequence = true
                self.mouseDown(with: event)
                return nil
            case .leftMouseDragged:
                guard self.bridgedMouseSequence, !self.isDragging else { return event }
                self.mouseDragged(with: event)
                return nil
            case .leftMouseUp:
                guard self.bridgedMouseSequence, !self.isDragging else { return event }
                self.bridgedMouseSequence = false
                self.mouseUp(with: event)
                return nil
            default: return event
            }
        }
    }
    func stopInputMonitoring() {
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil; bridgedMouseSequence = false; startEvent = nil
        edgeTimer?.invalidate(); edgeTimer = nil
        if isDragging { library?.cancelDrag() }
        isDragging = false; sourceScrollView = nil
    }
    override func draw(_ dirtyRect: NSRect) {
        (enabled ? NSColor.secondaryLabelColor : NSColor.disabledControlTextColor).setFill()
        for x in [bounds.midX - 3, bounds.midX + 3] {
            for y in [bounds.midY - 5, bounds.midY, bounds.midY + 5] {
                NSBezierPath(ovalIn: NSRect(x: x - 1, y: y - 1, width: 2, height: 2)).fill()
            }
        }
    }
    override func mouseDown(with event: NSEvent) { startEvent = enabled ? event : nil }
    override func mouseUp(with event: NSEvent) { startEvent = nil }
    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let startEvent, let item, enabled, let library,
              hypot(event.locationInWindow.x - startEvent.locationInWindow.x, event.locationInWindow.y - startEvent.locationInWindow.y) >= 4,
              let payload = library.beginDrag(occurrenceID: item.id, in: playlistID),
              let data = try? JSONEncoder().encode(payload), let value = String(data: data, encoding: .utf8) else { return }
        let writer = NSPasteboardItem()
        writer.setString(value, forType: NSPasteboard.PasteboardType(PlaylistDragPayload.typeIdentifier))
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let image = dragImage(title: item.title)
        let point = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(NSRect(x: point.x - 20, y: point.y - 24, width: 300, height: 52), contents: image)
        isDragging = true
        sourceScrollView = enclosingScrollView
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        edgeTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scrollAtEdge() }
        }
        if let edgeTimer { RunLoop.main.add(edgeTimer, forMode: .common) }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        edgeTimer?.invalidate(); edgeTimer = nil; startEvent = nil; isDragging = false; bridgedMouseSequence = false
        library?.cancelDrag()
    }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    private func scrollAtEdge() {
        guard let library, let payload = library.dragPayload, library.acceptsDrag(payload, in: playlistID),
              let scroll = sourceScrollView, let window = scroll.window, let document = scroll.documentView else {
            edgeTimer?.invalidate(); edgeTimer = nil; return
        }
        let screen = NSEvent.mouseLocation
        let point = scroll.convert(window.convertPoint(fromScreen: screen), from: nil)
        let visible = scroll.contentView.frame
        guard point.x >= visible.minX, point.x <= visible.maxX, point.y >= visible.minY - 8, point.y <= visible.maxY + 8 else { return }
        let documentPoint = document.convert(point, from: scroll)
        let rect = scroll.documentVisibleRect
        // NSClipView document coordinates preserve the document's flippedness.
        let topDistance = document.isFlipped ? documentPoint.y - rect.minY : rect.maxY - documentPoint.y
        let bottomDistance = document.isFlipped ? rect.maxY - documentPoint.y : documentPoint.y - rect.minY
        let delta: CGFloat = topDistance < 48 ? -18 : bottomDistance < 48 ? 18 : 0
        guard delta != 0 else { return }
        let origin = scroll.contentView.bounds.origin
        let direction: CGFloat = document.isFlipped ? 1 : -1
        let maximum = max(0, document.bounds.height - rect.height)
        scroll.contentView.scroll(to: NSPoint(x: origin.x, y: min(maximum, max(0, origin.y + delta * direction))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private func dragImage(title: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 300, height: 52))
        image.lockFocus()
        NSColor(calibratedWhite: 0.16, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 300, height: 52), xRadius: 6, yRadius: 6).fill()
        let thumbRect = NSRect(x: 6, y: 6, width: 40, height: 40)
        if let artwork { artwork.draw(in: thumbRect, from: .zero, operation: .sourceOver, fraction: 1) }
        else { NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?.draw(in: thumbRect) }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: NSRect(x: 56, y: 15, width: 236, height: 24), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
        image.unlockFocus(); return image
    }

    func loadArtwork(localPath: String?, remoteURL: URL?) {
        let url = localPath.map { URL(fileURLWithPath: $0) } ?? remoteURL
        guard artworkURL != url else { return }
        artworkURL = url; artwork = nil
        guard let url else { return }
        if url.isFileURL { artwork = NSImage(contentsOf: url); return }
        guard url.scheme == "https" else { return }
        Task { [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: url), data.count <= 10_485_760,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), self?.artworkURL == url else { return }
            self?.artwork = NSImage(data: data)
        }
    }
}

struct PlaylistInsertionDrop: DropDelegate {
    let library: PlaylistLibrary
    let playlistID: String
    let insertionIndex: Int
    var splitRow = false
    func validateDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            guard info.hasItemsConforming(to: [PlaylistDragPayload.typeIdentifier]), let payload = library.dragPayload else { return false }
            return library.acceptsDrag(payload, in: playlistID)
        }
    }
    func dropEntered(info: DropInfo) { update(info) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info)
        return DropProposal(operation: validateDrop(info: info) ? .move : .cancel)
    }
    func dropExited(info: DropInfo) { MainActor.assumeIsolated { library.updateDragInsertion(nil) } }
    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            guard validateDrop(info: info), let payload = library.dragPayload else { library.cancelDrag(); return false }
            return library.drop(payload, in: playlistID, insertionIndex: destination(info))
        }
    }
    private func destination(_ info: DropInfo) -> Int { insertionIndex + (splitRow && info.location.y > 29 ? 1 : 0) }
    private func update(_ info: DropInfo) {
        MainActor.assumeIsolated { library.updateDragInsertion(validateDrop(info: info) ? destination(info) : nil) }
    }
}
