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
