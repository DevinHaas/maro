import AppKit
import SwiftUI
import MaroCore

/// Shared card colors for AppKit and SwiftUI surfaces; keep native focus treatments.
enum MaroAppearance {
    static let background = NSColor(srgbRed: 0.06, green: 0.065, blue: 0.075, alpha: 1)
    static let accent = NSColor(srgbRed: 0.66, green: 0.85, blue: 0.58, alpha: 1)
    static let border = NSColor(srgbRed: 0.71, green: 0.79, blue: 0.85, alpha: 1)
    static let ink = NSColor(srgbRed: 0.08, green: 0.13, blue: 0.10, alpha: 1)

    @MainActor static func primary(_ button: NSButton) {
        button.bezelColor = accent
        button.addSubview(PrimaryButtonAppearance(frame: .zero))
    }
}

/// Follow native window activation without overriding button drawing or actions.
@MainActor private final class PrimaryButtonAppearance: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        center.removeObserver(self)
        if window != nil {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                center.addObserver(self, selector: #selector(update), name: name, object: nil)
            }
        }
        update()
    }
    @objc private func update() {
        guard let button = superview as? NSButton else { return }
        // Aqua text is dark on active green. Inactive buttons use native dark-mode
        // light text on their gray background; disabled rendering remains native.
        button.appearance = NSAppearance(named: window?.isKeyWindow == true && NSApp.isActive ? .aqua : .darkAqua)
    }
}

/// Presentation only: every action still goes through the existing controller.
@MainActor
final class PlayerWindow: NSWindowController {
    private let controller: MaroController
    private let presentation: PlayerPresentation
    private let openSearch: @MainActor () -> Void
    private var opening: Task<Void, Never>?

    init(controller: MaroController, openSearch: @escaping @MainActor () -> Void,
         addToPlaylist: @escaping @MainActor (VideoSummary) -> Void = { _ in }) {
        self.controller = controller
        self.openSearch = openSearch
        presentation = PlayerPresentation(snapshot: controller.snapshot)
        let panel = PlayerPanel(contentRect: NSRect(x: 0, y: 0, width: 392, height: 180),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Maro · Player"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: panel)
        panel.onHide = { [weak presentation] in presentation?.timelineEpoch += 1 }
        panel.contentView = NSHostingView(rootView: PlayerCard(presentation: presentation,
            action: { [weak self] command, id in self?.perform(command, videoID: id) },
            search: { [weak self] in self?.window?.orderOut(nil); self?.openSearch() },
            addToPlaylist: { [weak self] video in self?.window?.orderOut(nil); addToPlaylist(video) },
            hide: { [weak panel] in panel?.orderOut(nil) },
            setVolume: { [weak self] volume in
                self?.controller.setVolume(volume)
                self?.render()
            },
            seek: { [weak self] seconds, id in self?.controller.seek(to: seconds, timelineID: id) },
            resize: { [weak panel] size in
                guard let panel, panel.frame.size != size else { return }
                let top = panel.frame.maxY
                let center = panel.frame.midX
                panel.setContentSize(size)
                panel.setFrameTopLeftPoint(NSPoint(x: center - size.width / 2, y: top))
            }))
    }

    required init?(coder: NSCoder) { nil }

    func toggle() {
        guard let window else { return }
        if let opening { opening.cancel(); self.opening = nil; return }
        if window.isVisible { window.orderOut(nil); return }
        render()
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        opening = Task { [weak self] in
            let executable = ProcessInfo.processInfo.environment["MARO_SKETCHYBAR"] ??
                ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"]
                    .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/sketchybar"
            var anchor: NSRect?
            if let screen {
                for name in ["maro.anchor", "maro.anchor.notched"] {
                    let result = try? await ExtractorProcess.run(executable: URL(fileURLWithPath: executable),
                        arguments: ["--query", name], timeout: 0.5, stdoutLimit: 65_536, stderrLimit: 1024)
                    anchor = result.flatMap { $0.exitCode == 0 ? Self.anchorRect($0.stdout,
                        screen: screen.frame, desktopTop: NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY) : nil }
                    if anchor != nil || Task.isCancelled { break }
                }
            }
            guard !Task.isCancelled, let self else { return }
            self.opening = nil
            if let size = window.contentView?.fittingSize { window.setContentSize(size) }
            if let screen {
                window.setFrameTopLeftPoint(Self.cardOrigin(size: window.frame.size,
                    screen: screen.frame, visible: screen.visibleFrame, anchor: anchor))
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func anchorRect(_ data: Data, screen: NSRect, desktopTop: CGFloat) -> NSRect? {
        guard let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bounds = item["bounding_rects"] as? [String: [String: [Double]]] else { return nil }
        if let geometry = item["geometry"] as? [String: Any], geometry["drawing"] as? String == "off" { return nil }
        for bound in bounds.values {
            guard let origin = bound["origin"], let size = bound["size"],
                  origin.count == 2, size.count == 2, (origin + size).allSatisfy(\.isFinite),
                  size[0] > 0, size[1] > 0 else { continue }
            // SketchyBar uses global top-left coordinates; AppKit uses bottom-left.
            let rect = NSRect(x: origin[0], y: desktopTop - origin[1] - size[1],
                              width: size[0], height: size[1])
            if screen.contains(NSPoint(x: rect.midX, y: rect.midY)) { return rect }
        }
        return nil
    }

    static func cardOrigin(size: NSSize, screen: NSRect, visible: NSRect, anchor: NSRect?) -> NSPoint {
        let center = anchor?.midX ?? screen.midX
        let x = max(visible.minX + 8, min(center - size.width / 2, visible.maxX - size.width - 8))
        return NSPoint(x: x, y: min(anchor?.minY ?? visible.maxY, visible.maxY) - 8)
    }

    func render() {
        presentation.snapshot = controller.snapshot
    }

    private func perform(_ command: CommandName, videoID: String?) {
        presentation.actionError = nil
        Task {
            do {
                let response = try await controller.execute(CommandRequest(command: command, videoID: videoID),
                    openSearch: openSearch)
                presentation.actionError = response.error?.message
            } catch { presentation.actionError = "This action is unavailable. Try again." }
            render()
        }
    }
}

private final class PlayerPanel: NSPanel {
    var onHide: (() -> Void)?
    override func orderOut(_ sender: Any?) { onHide?(); super.orderOut(sender) }
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}

@MainActor
final class PlayerPresentation: ObservableObject {
    @Published var snapshot: PlayerSnapshot
    @Published var actionError: String?
    @Published var timelineEpoch = 0
    init(snapshot: PlayerSnapshot) { self.snapshot = snapshot }
}

struct PlayerCard: View {
    @ObservedObject var presentation: PlayerPresentation
    let action: (CommandName, String?) -> Void
    let search: () -> Void
    var addToPlaylist: (VideoSummary) -> Void = { _ in }
    let hide: () -> Void
    var setVolume: (Double) -> Void = { _ in }
    var seek: (Double, UUID) -> Void = { _, _ in }
    var resize: (CGSize) -> Void = { _ in }
    @State var favorites = false
    @State private var timelinePreview: Double?
    private let green = Color(nsColor: MaroAppearance.accent)
    private let ink = Color(nsColor: MaroAppearance.ink)
    private var snapshot: PlayerSnapshot { presentation.snapshot }
    private var video: VideoSummary? { snapshot.loadedVideo?.video }
    private var playing: Bool { snapshot.playback == .playing || snapshot.playback == .buffering || snapshot.isSelecting }
    private var problem: String? {
        snapshot.sourceNeedsUpdate ? "YouTube source needs an update." :
            presentation.actionError ?? snapshot.error ?? snapshot.persistenceError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if favorites { favoritesList }
            else {
                HStack(alignment: .center, spacing: 16) {
                    HStack(spacing: 10) {
                        volumeControl
                        artwork(video).frame(width: 128, height: 128)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ScrollingTitle(title: video?.title ?? "Choose a video")
                                .frame(height: 18)
                            Button { if let video { action(.favoriteToggle, video.id) } } label: {
                                Image(systemName: snapshot.favorites.contains { $0.id == video?.id } ? "star.fill" : "star")
                                    .foregroundStyle(green).frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain).disabled(video == nil)
                            .help("Toggle favorite").accessibilityLabel("Toggle favorite")
                            Button { if let video { addToPlaylist(video) } } label: {
                                Image(systemName: "text.badge.plus").frame(width: 24, height: 24)
                            }.buttonStyle(.plain).disabled(video == nil)
                                .help("Add to playlist").accessibilityLabel("Add to playlist")
                        }
                        Text(video?.creator ?? "Search YouTube to start listening")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        progress
                        transport
                        HStack(spacing: 6) {
                            Button("Library", action: search).help("Search YouTube or browse playlists")
                            Button("Favorites (\(snapshot.favorites.count))") { favorites = true }
                        }
                        .font(.system(size: 10)).buttonStyle(.bordered).tint(green)
                    }
                    .frame(width: 224)
                }
            }
            if snapshot.isSelecting {
                Text("Preparing audio…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let problem {
                Text(problem).font(.system(size: 11)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).padding(.top, 12).frame(width: 430).fixedSize(horizontal: true, vertical: true)
        .background(Color(nsColor: MaroAppearance.background))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: MaroAppearance.border), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Button(action: hide) {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Hide player")
            .accessibilityLabel("Hide player").accessibilityIdentifier("hide-player")
            .padding(.leading, 2)
        }
        .preferredColorScheme(.dark)
        .background(GeometryReader { geometry in
            Color.clear.onAppear { resize(geometry.size) }
                .onChange(of: geometry.size) { resize($0) }
        })
    }

    private var volumeControl: some View {
        VStack(spacing: 2) {
            PillVolumeSlider(value: snapshot.volume ?? 1, onChange: setVolume)
                .frame(width: 18, height: 92)
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary).accessibilityHidden(true)
        }
        .frame(width: 28, height: 128)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .help("Playback volume: \(Int(((snapshot.volume ?? 1) * 100).rounded()))%")
    }

    private var transport: some View {
        HStack(spacing: 22) {
            transportButton("Previous", symbol: "backward.end.fill", command: .previous,
                enabled: snapshot.canGoPrevious == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate)
            transportButton(snapshot.playback == .ended ? "Replay" : playing ? "Pause" : "Play",
                symbol: snapshot.playback == .ended ? "arrow.counterclockwise" : playing ? "pause.fill" : "play.fill",
                command: snapshot.playback == .ended ? .replay : .toggle,
                enabled: video != nil && (playing || !snapshot.sourceNeedsUpdate), central: true)
            transportButton("Next", symbol: "forward.end.fill", command: .next,
                enabled: snapshot.canGoNext == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate)
        }
        .frame(maxWidth: .infinity).frame(height: 36)
        .background(Capsule().fill(green).frame(height: 26))
    }

    private func transportButton(_ name: String, symbol: String, command: CommandName,
                                 enabled: Bool, central: Bool = false) -> some View {
        Button { action(command, nil) } label: {
            Image(systemName: symbol).font(.system(size: central ? 16 : 13, weight: .semibold))
                .foregroundStyle(central ? Color.white : ink)
                .frame(width: 36, height: 36)
                .background { if central { Circle().fill(ink.opacity(0.65)) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .help(name).accessibilityLabel(name).accessibilityIdentifier(name.lowercased())
    }

    private var progress: some View {
        let duration = snapshot.timeline?.duration ?? video?.durationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let raw = timelinePreview ?? snapshot.seekTarget ?? snapshot.loadedVideo?.positionSeconds ?? 0
        let position = raw.isFinite ? max(0, duration.map { min(raw, $0) } ?? raw) : 0
        return VStack(spacing: 4) {
            PlaybackTimelineSlider(position: snapshot.seekTarget ?? snapshot.loadedVideo?.positionSeconds ?? 0,
                timeline: snapshot.timeline, playbackID: snapshot.timelineID,
                epoch: presentation.timelineEpoch, preview: { timelinePreview = $0 }, commit: seek,
                displayDuration: duration)
                .disabled(snapshot.timeline == nil || snapshot.timelineID == nil)
                .frame(height: 18)
                .onChange(of: snapshot.timelineID) { _ in timelinePreview = nil }
                .onChange(of: presentation.timelineEpoch) { _ in timelinePreview = nil }
                .onChange(of: snapshot.timeline) { if $0 == nil { timelinePreview = nil } }
                .onDisappear { timelinePreview = nil }
            HStack {
                Text(Self.clock(position))
                Spacer()
                Text(duration.map(Self.clock) ?? "--:--")
            }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private static func clock(_ value: Double) -> String {
        let seconds = Int(min(max(0, value), 359_999))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    @ViewBuilder private func artwork(_ entry: VideoSummary?) -> some View {
        if let entry, let path = snapshot.localThumbnailPaths?[entry.id], let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "music.note").font(.system(size: 32)).foregroundStyle(.secondary)
        }
    }

    private var favoritesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Now Playing") { favorites = false }
                Spacer()
                Button("Search YouTube", action: search)
            }.buttonStyle(.bordered).tint(green)
            if snapshot.favorites.isEmpty {
                Text("No favorites yet").foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(snapshot.favorites, id: \.id) { entry in
                            HStack(spacing: 8) {
                                Button { action(.select, entry.id); favorites = false } label: {
                                    HStack {
                                        artwork(entry).frame(width: 40, height: 32)
                                        VStack(alignment: .leading) {
                                            Text(entry.title).lineLimit(1)
                                            Text(entry.creator).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(snapshot.sourceNeedsUpdate)
                                .contextMenu { Button("Remove favorite") { action(.favoriteRemove, entry.id) } }
                                Button { action(.favoriteRemove, entry.id) } label: { Image(systemName: "star.fill") }
                                    .buttonStyle(.plain).foregroundStyle(green).help("Remove favorite")
                                    .accessibilityLabel("Remove \(entry.title) from favorites")
                            }
                        }
                    }
                }.frame(height: min(320, CGFloat(snapshot.favorites.count) * 44))
            }
        }
    }
}

/// Native slider retains keyboard, pointer and accessibility behavior with custom drawing.
private struct PillVolumeSlider: NSViewRepresentable {
    let value: Double
    let onChange: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(frame: NSRect(x: 0, y: 0, width: 18, height: 92))
        slider.cell = PillVolumeCell()
        slider.minValue = 0
        slider.maxValue = 1
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        slider.setAccessibilityLabel("Playback volume")
        slider.setAccessibilityIdentifier("playback-volume")
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.onChange = onChange
        slider.doubleValue = value
        slider.setAccessibilityValueDescription("\(Int((value * 100).rounded())) percent")
    }

    @MainActor final class Coordinator: NSObject {
        var onChange: (Double) -> Void
        init(onChange: @escaping (Double) -> Void) { self.onChange = onChange }
        @objc func changed(_ slider: NSSlider) { onChange(slider.doubleValue) }
    }
}

private final class PillVolumeCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        // Match the track endpoints to the native knob's center travel.
        let track = rect.insetBy(dx: 0, dy: knobRect(flipped: flipped).height / 2)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: track.midX - 1, y: track.minY,
            width: 2, height: track.height), xRadius: 1, yRadius: 1).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        NSColor(red: 0.77, green: 0.79, blue: 0.86, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: knobRect.midX - 3.5, y: knobRect.midY - 3.5,
            width: 7, height: 7)).fill()
    }
}

/// Native clipping and animation retain the full title; reduced motion uses the tooltip.
private struct ScrollingTitle: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> TitleViewport { TitleViewport() }
    func updateNSView(_ view: TitleViewport, context: Context) { view.setTitle(title) }
}

private final class TitleViewport: NSView {
    private let label = NSTextField(labelWithString: "")
    private var lastLayout = ""
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = NSColor(red: 0.77, green: 0.79, blue: 0.86, alpha: 1)
        label.wantsLayer = true
        addSubview(label)
    }
    required init?(coder: NSCoder) { nil }
    func setTitle(_ title: String) {
        guard label.stringValue != title else { return }
        label.stringValue = title
        toolTip = title
        setAccessibilityLabel(title)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        let signature = "\(label.stringValue)|\(bounds.width)|\(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)"
        guard signature != lastLayout else { return }
        lastLayout = signature
        label.sizeToFit()
        label.frame.origin = .zero
        label.layer?.removeAnimation(forKey: "scroll")
        let overflow = label.frame.width - bounds.width
        guard overflow > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -overflow, -overflow, 0]
        animation.keyTimes = [0, 0.1, 0.8, 0.9, 1]
        animation.duration = max(6, Double(overflow) / 25 + 3)
        animation.repeatCount = .infinity
        label.layer?.add(animation, forKey: "scroll")
    }
}
