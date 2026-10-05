import AppKit
import SwiftUI

/// Styles the native scroll views inside the shell without taking space from their content.
/// Keeping native scrollers preserves wheel, keyboard, accessibility, and thumb dragging.
struct SubtleScrollbars: NSViewRepresentable {
    let sidebarWidth: CGFloat
    let sidebarHovered: Bool

    func makeNSView(context: Context) -> ScrollbarStyleAnchor {
        ScrollbarStyleAnchor()
    }

    func updateNSView(_ view: ScrollbarStyleAnchor, context: Context) {
        view.sidebarWidth = sidebarWidth
        view.sidebarHovered = sidebarHovered
        view.scheduleUpdate()
    }
}

final class ScrollbarStyleAnchor: NSView {
    var sidebarWidth: CGFloat = 0
    var sidebarHovered = false
    private var updateScheduled = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleUpdate()
    }

    override func layout() {
        super.layout()
        scheduleUpdate()
    }

    func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.styleScrollViews()
        }
    }

    private func styleScrollViews() {
        guard let root = window?.contentView else { return }
        let shellFrame = convert(bounds, to: root)
        guard !shellFrame.isEmpty else { return }
        styleDescendants(of: root, in: shellFrame, root: root)
    }

    private func styleDescendants(of view: NSView, in shellFrame: NSRect, root: NSView) {
        if let scrollView = view as? NSScrollView {
            let frame = scrollView.convert(scrollView.bounds, to: root)
            guard shellFrame.contains(NSPoint(x: frame.midX, y: frame.midY)) else { return }
            // Shell content starts after its 8-point outer inset. Overlay scrollers never
            // reserve a gutter, so the compact artwork remains centered in the full rail.
            let isSidebar = frame.midX < shellFrame.minX + 8 + sidebarWidth
            let showScroller = !isSidebar || sidebarHovered
            if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
            if scrollView.hasVerticalScroller != showScroller { scrollView.hasVerticalScroller = showScroller }
            if scrollView.autohidesScrollers == isSidebar { scrollView.autohidesScrollers = !isSidebar }
            if scrollView.hasVerticalScroller, !(scrollView.verticalScroller is SubtleScroller) {
                let scroller = SubtleScroller(frame: scrollView.verticalScroller?.frame ?? .zero)
                scroller.scrollerStyle = .overlay
                scrollView.verticalScroller = scroller
            }
            (scrollView.verticalScroller as? SubtleScroller)?.rendersKnob = !isSidebar
            if isSidebar {
                let thumb: SidebarScrollThumb
                if let existing = scrollView.subviews.compactMap({ $0 as? SidebarScrollThumb }).first {
                    thumb = existing
                } else {
                    thumb = SidebarScrollThumb(scrollView: scrollView)
                    scrollView.addSubview(thumb, positioned: .above, relativeTo: nil)
                }
                thumb.frame = scrollView.bounds
                thumb.isHidden = !sidebarHovered
                thumb.needsDisplay = true
            }
            if scrollView.hasHorizontalScroller, !(scrollView.horizontalScroller is SubtleScroller) {
                let scroller = SubtleScroller(frame: scrollView.horizontalScroller?.frame ?? .zero)
                scroller.scrollerStyle = .overlay
                scrollView.horizontalScroller = scroller
            }
        }
        for child in view.subviews { styleDescendants(of: child, in: shellFrame, root: root) }
    }
}

private final class SubtleScroller: NSScroller {
    var rendersKnob = true
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        guard rendersKnob else { return }
        var knob = rect(for: .knob)
        guard !knob.isEmpty else { return }
        let vertical = bounds.height > bounds.width
        if vertical {
            knob.origin.x = knob.midX - 2.5
            knob.size.width = 5
            knob = knob.insetBy(dx: 0, dy: 2)
        } else {
            knob.origin.y = knob.midY - 2.5
            knob.size.height = 5
            knob = knob.insetBy(dx: 2, dy: 0)
        }
        NSColor(AppDesign.Text.secondary).withAlphaComponent(0.4).setFill()
        NSBezierPath(roundedRect: knob, xRadius: 2.5, yRadius: 2.5).fill()
    }
}

/// AppKit's overlay animator can hide a native thumb even while autohiding is disabled.
/// This paint-only overlay keeps the sidebar thumb visible throughout a hover; the
/// native scroller underneath still handles dragging and accessibility.
private final class SidebarScrollThumb: NSView {
    private weak var scrollView: NSScrollView?
    override var isFlipped: Bool { true }

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: scrollView.bounds)
        autoresizingMask = [.width, .height]
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(viewportChanged),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        if let document = scrollView.documentView {
            document.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(viewportChanged),
                                                   name: NSView.frameDidChangeNotification, object: document)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    @objc private func viewportChanged(_ notification: Notification) { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let viewport = scrollView.contentView
        let visible = document.convert(viewport.bounds, from: viewport)
        let contentHeight = document.bounds.height
        guard contentHeight > visible.height, visible.height > 0 else { return }
        let track = convert(viewport.bounds, from: viewport).insetBy(dx: 0, dy: 3)
        let thumbHeight = min(track.height, max(32, track.height * visible.height / contentHeight))
        let offset = document.isFlipped ? visible.minY - document.bounds.minY : document.bounds.maxY - visible.maxY
        let progress = min(1, max(0, offset / (contentHeight - visible.height)))
        let knob = NSRect(x: bounds.maxX - 8, y: track.minY + progress * (track.height - thumbHeight),
                          width: 5, height: thumbHeight)
        NSColor(AppDesign.Text.secondary).withAlphaComponent(0.4).setFill()
        NSBezierPath(roundedRect: knob, xRadius: 2.5, yRadius: 2.5).fill()
    }
}
