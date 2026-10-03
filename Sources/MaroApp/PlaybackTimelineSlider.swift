import AppKit
import SwiftUI
import MaroCore

struct PlaybackTimelineSlider: NSViewRepresentable {
    let position: Double
    let timeline: PlaybackTimeline?
    let playbackID: UUID?
    let epoch: Int
    let preview: (Double?) -> Void
    let commit: (Double, UUID) -> Void
    var displayDuration: Double? = nil

    func makeNSView(context: Context) -> TimelineSlider { TimelineSlider() }
    func updateNSView(_ slider: TimelineSlider, context: Context) {
        slider.configure(position: position, timeline: timeline, id: playbackID,
                         epoch: epoch, displayDuration: displayDuration, preview: preview, commit: commit)
    }
    static func dismantleNSView(_ slider: TimelineSlider, coordinator: ()) { slider.cancelDraft() }
}

/// NSSlider retains native tracking, focus and accessibility. Only a finished
/// gesture reaches the controller; periodic position updates cannot move its thumb.
@MainActor final class TimelineSlider: NSSlider {
    private var timeline: PlaybackTimeline?
    private var identity: UUID?
    private var epoch = 0
    private var tracking = false
    private var invalidated = false
    private var generation = 0
    private var preview: (Double?) -> Void = { _ in }
    private var commit: (Double, UUID) -> Void = { _, _ in }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 18))
        cell = TimelineCell()
        minValue = 0
        maxValue = 1
        isContinuous = true
        target = self
        action = #selector(changed)
        controlSize = .small
        setAccessibilityLabel("Playback position")
        setAccessibilityIdentifier("playback-position")
    }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { isEnabled }

    func configure(position: Double, timeline: PlaybackTimeline?, id: UUID?, epoch: Int,
                   displayDuration: Double? = nil,
                   preview: @escaping (Double?) -> Void, commit: @escaping (Double, UUID) -> Void) {
        if identity != id || self.epoch != epoch || timeline == nil { cancelDraft() }
        self.timeline = timeline
        identity = id
        self.epoch = epoch
        self.preview = preview
        self.commit = commit
        isEnabled = timeline != nil && id != nil
        let duration = timeline?.duration ?? displayDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        maxValue = duration ?? 1
        if !tracking { doubleValue = duration == nil ? 0 : min(maxValue, max(0, position.isFinite ? position : 0)) }
        describeValue()
    }

    func cancelDraft() { generation += 1; invalidated = true }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        let token = beginTrackingGesture()
        super.mouseDown(with: event)
        endTrackingGesture(token, visible: window?.isVisible == true)
    }

    func beginTrackingGesture() -> Int {
        tracking = true
        invalidated = false
        return generation
    }

    func endTrackingGesture(_ token: Int, visible: Bool) {
        tracking = false
        preview(nil)
        guard generation == token, visible else { return }
        finish()
    }

    @objc private func changed() {
        describeValue()
        if tracking {
            if !invalidated { preview(timeline?.target(for: doubleValue)) }
        }
        else { finish() }
    }

    private func finish() {
        guard isEnabled, let identity, let target = timeline?.target(for: doubleValue) else { return }
        doubleValue = target
        describeValue()
        commit(target, identity)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 125: step(-5)
        case 124, 126: step(5)
        default: super.keyDown(with: event)
        }
    }
    private func step(_ delta: Double) {
        guard isEnabled else { return }
        doubleValue = min(maxValue, max(minValue, doubleValue + delta))
        finish()
    }
    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }; step(5); return true
    }
    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }; step(-5); return true
    }
    private func describeValue() {
        let elapsed = Int(min(359_999, max(0, doubleValue)))
        let duration = Int(min(359_999, maxValue))
        setAccessibilityValueDescription(isEnabled
            ? "\(elapsed / 60) minutes \(elapsed % 60) seconds of \(duration / 60) minutes \(duration % 60) seconds"
            : "Seeking unavailable")
    }
}

private final class TimelineCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let inset = knobRect(flipped: flipped).width / 2
        let track = NSRect(x: rect.minX + inset, y: rect.midY - 1.5,
                           width: max(0, rect.width - inset * 2), height: 3)
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()
        let fraction = maxValue > minValue ? (doubleValue - minValue) / (maxValue - minValue) : 0
        NSColor(red: 0.66, green: 0.85, blue: 0.58, alpha: isEnabled ? 1 : 0.4).setFill()
        NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY,
            width: track.width * min(1, max(0, fraction)), height: 3), xRadius: 1.5, yRadius: 1.5).fill()
    }
    override func drawKnob(_ rect: NSRect) {
        guard isEnabled else { return }
        NSColor(red: 0.66, green: 0.85, blue: 0.58, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - 3, y: rect.midY - 3, width: 6, height: 6)).fill()
    }
}
