import AppKit
import Testing
@testable import MaroApp

@Test @MainActor func searchPlacementFitsEachDisplayAndRetainsPracticalSize() {
    for visible in [NSRect(x: 0, y: 0, width: 1440, height: 850),
                    NSRect(x: -1920, y: 200, width: 1920, height: 1050),
                    NSRect(x: 1440, y: -900, width: 500, height: 400)] {
        for x in [visible.minX, visible.midX, visible.maxX] {
            let frame = SearchWindow.presentationFrame(size: NSSize(width: 640, height: 572),
                visible: visible, anchorX: x)
            #expect(visible.contains(frame))
            #expect(frame.maxY == visible.maxY - 8)
            #expect(frame.width == min(640, visible.width - 16))
            #expect(frame.height == min(572, visible.height - 16))
        }
    }
}

@Test @MainActor func searchPlacementStaysBelowTopBarCoveringScreen() {
    let screen = NSRect(x: 0, y: 0, width: 1920, height: 1200)
    func window(_ y: Double, _ width: Double, _ height: Double, layer: Int = 25, pid: Int = 1) -> [String: Any] {
        [kCGWindowLayer as String: layer, kCGWindowOwnerPID as String: pid,
         kCGWindowBounds as String: CGRect(x: 0, y: y, width: width, height: height).dictionaryRepresentation]
    }
    #expect(SearchWindow.topBarBottom(screen: screen, windows: [window(0, 1920, 40)], desktopTop: 1200) == 1160)
    // Floating bar offset from the edge; the lowest qualifying bar wins.
    #expect(SearchWindow.topBarBottom(screen: screen, windows: [window(-1, 1920, 31), window(5, 1900, 35)],
                                      desktopTop: 1200) == 1160)
    // Normal app windows, narrow popups, full-screen overlays and our own windows are ignored.
    for ignored in [window(0, 1920, 40, layer: 0), window(0, 300, 40), window(0, 1920, 1200),
                    window(0, 1920, 40, pid: 99), window(1160, 1920, 40)] {
        #expect(SearchWindow.topBarBottom(screen: screen, windows: [ignored], desktopTop: 1200, ownPID: 99) == nil)
    }
}
