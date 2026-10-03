import AppKit
import Foundation
import Testing
@testable import MaroApp
@testable import MaroCore

@Test @MainActor func unavailableTimelineDisplaysMetadataProgressWithoutEnablingSeeking() {
    let slider = TimelineSlider()
    var commits = 0
    func configure(_ duration: Double?) {
        slider.configure(position: 90, timeline: nil, id: nil, epoch: 0,
            displayDuration: duration, preview: { _ in }, commit: { _, _ in commits += 1 })
    }
    configure(3600)
    #expect(slider.maxValue == 3600 && slider.doubleValue == 90)
    #expect(!slider.isEnabled && !slider.accessibilityPerformIncrement())
    #expect(slider.accessibilityValueDescription() == "Seeking unavailable")
    for duration: Double? in [nil, 0, -.infinity, .nan] {
        configure(duration)
        #expect(slider.doubleValue == 0 && slider.maxValue == 1)
    }
    #expect(commits == 0)
}

@Test @MainActor func timelineDraftIgnoresTicksAndCancelsOnIdentityOrHide() throws {
    let slider = TimelineSlider()
    let timeline = try #require(PlaybackTimeline(duration: 100, ranges: [0...100]))
    let id = UUID()
    var commits: [Double] = []
    var previews: [Double?] = []
    func configure(_ position: Double, _ identity: UUID, _ epoch: Int, available: Bool = true) {
        slider.configure(position: position, timeline: available ? timeline : nil, id: identity, epoch: epoch,
            preview: { previews.append($0) }, commit: { seconds, _ in commits.append(seconds) })
    }
    configure(10, id, 0)
    var token = slider.beginTrackingGesture()
    slider.doubleValue = 45
    _ = slider.sendAction(slider.action, to: slider.target)
    #expect(previews.last! == 45)
    #expect(commits.isEmpty)
    configure(12, id, 0)
    #expect(slider.doubleValue == 45, "A playback tick cannot replace a drag draft")
    slider.endTrackingGesture(token, visible: true)
    #expect(commits == [45], "Only release commits")
    for mode in ["identity", "hide", "unavailable"] {
        configure(10, id, 0)
        token = slider.beginTrackingGesture()
        slider.doubleValue = 80
        configure(20, mode == "identity" ? UUID() : id, mode == "hide" ? 1 : 0,
                  available: mode != "unavailable")
        slider.endTrackingGesture(token, visible: true)
        #expect(commits == [45])
    }
    #expect(previews.last! == nil)
}

@Test @MainActor func timelineAccessibilityCommitsFiveSecondsAndDisablesUnavailableRanges() throws {
    let slider = TimelineSlider()
    let id = UUID()
    let timeline = try #require(PlaybackTimeline(duration: 100, ranges: [0...100]))
    var commits: [(Double, UUID)] = []
    slider.configure(position: 30, timeline: timeline, id: id, epoch: 0,
        preview: { _ in }, commit: { commits.append(($0, $1)) })
    #expect(slider.accessibilityLabel() == "Playback position")
    #expect(slider.acceptsFirstResponder)
    #expect(slider.accessibilityPerformIncrement())
    #expect(commits.last?.0 == 35)
    #expect(commits.last?.1 == id)
    #expect(slider.accessibilityPerformDecrement())
    #expect(commits.last?.0 == 30)
    let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124))
    slider.keyDown(with: event)
    #expect(commits.last?.0 == 35)
    slider.configure(position: 35, timeline: nil, id: id, epoch: 1,
        preview: { _ in }, commit: { commits.append(($0, $1)) })
    #expect(!slider.isEnabled)
    #expect(!slider.acceptsFirstResponder)
    #expect(!slider.accessibilityPerformIncrement())
    #expect(commits.count == 3)
}
