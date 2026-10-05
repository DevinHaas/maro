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

    init(application: ApplicationModel, openSearch: @escaping @MainActor () -> Void) {
        self.controller = application.controller
        self.openSearch = openSearch
        presentation = application.player
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
        panel.contentView = NSHostingView(rootView: PlayerCard(presentation: presentation, app: application,
            action: { [weak self] command, id in self?.perform(command, videoID: id) },
            search: { [weak self] in self?.window?.orderOut(nil); self?.openSearch() },
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
    @ObservedObject var app: ApplicationModel
    let action: (CommandName, String?) -> Void
    let search: () -> Void
    let hide: () -> Void
    var setVolume: (Double) -> Void = { _ in }
    var seek: (Double, UUID) -> Void = { _, _ in }
    var resize: (CGSize) -> Void = { _ in }
    @State var favorites = false
    @State private var timelinePreview: Double?
    private var snapshot: PlayerSnapshot { presentation.snapshot }
    private var video: VideoSummary? { snapshot.loadedVideo?.video }
    private var playing: Bool { snapshot.playback == .playing || snapshot.playback == .buffering || snapshot.isSelecting }
    private var loadingAudio: Bool { snapshot.isSelecting || (snapshot.playback == .buffering && snapshot.timeline == nil) }
    private var problem: String? {
        snapshot.sourceNeedsUpdate ? "YouTube source needs an update." :
            presentation.actionError ?? snapshot.error ?? snapshot.persistenceError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if favorites { favoritesList }
            else {
                HStack(alignment: .center, spacing: 14) {
                    Group {
                        if loadingAudio && video == nil {
                            LoadingSkeleton(label: "Loading track artwork", identifier: "player-artwork-loading", announce: false) {
                                SkeletonBlock(cornerRadius: 5)
                            }
                        } else { artwork(video) }
                    }.frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 6) {
                        if loadingAudio && video == nil {
                            PlayerTrackDetailsSkeleton().frame(height: 37).padding(.trailing, 20)
                        } else {
                            ScrollingTitle(title: video?.title ?? "Choose a video")
                                .frame(height: 18).padding(.trailing, 20)
                            Text(video?.creator ?? "Search YouTube to start listening")
                                .font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            transport
                            Spacer(minLength: 0)
                            AppIconButton(title: "Toggle favorite",
                                symbol: snapshot.favorites.contains { $0.id == video?.id } ? "heart.fill" : "heart",
                                enabled: video != nil) {
                                if let video { action(.favoriteToggle, video.id) }
                            }
                            if let video {
                                SaveDestinationButton(app: app, video: video, rowHovered: true, iconOnly: true)
                            } else {
                                AppIconButton(title: "Add to playlist", symbol: "plus", enabled: false) {}
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                progress
                HStack(spacing: 8) {
                    PlayerNavigationButton(title: "Library", symbol: "books.vertical", action: search)
                        .help("Search YouTube or browse playlists")
                    PlayerNavigationButton(title: "Favorites (\(snapshot.favorites.count))", symbol: "heart") { favorites = true }
                    Spacer(minLength: 0)
                    volumeControl
                }
            }
            if let problem {
                Text(problem).font(.system(size: 11)).foregroundStyle(AppDesign.Status.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(width: 430).fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(AppDesign.Text.primary)
        .background(AppDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .tidalBorder(cornerRadius: 8)
        .overlay(alignment: .topTrailing) {
            Button(action: hide) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppDesign.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Hide player")
            .accessibilityLabel("Hide player").accessibilityIdentifier("hide-player")
            .padding(4)
        }
        .preferredColorScheme(.dark)
        .tint(AppDesign.Accent.primary)
        .background(GeometryReader { geometry in
            Color.clear.onAppear { resize(geometry.size) }
                .onChange(of: geometry.size) { resize($0) }
        })
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppDesign.muted).accessibilityHidden(true)
            Slider(value: Binding(get: { snapshot.volume ?? 1 }, set: { setVolume($0) }), in: 0...1)
                .frame(width: 78).controlSize(.small)
                .accessibilityLabel("Playback volume").accessibilityIdentifier("playback-volume")
        }
        .help("Playback volume: \(Int(((snapshot.volume ?? 1) * 100).rounded()))%")
    }

    private var transport: some View {
        HStack(spacing: 8) {
            transportButton("Previous", symbol: "backward.end.fill", command: .previous,
                enabled: snapshot.canGoPrevious == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate)
            transportButton(snapshot.playback == .ended ? "Replay" : playing ? "Pause" : "Play",
                symbol: snapshot.playback == .ended ? "arrow.counterclockwise" : playing ? "pause.fill" : "play.fill",
                command: snapshot.playback == .ended ? .replay : .toggle,
                enabled: video != nil && (playing || !snapshot.sourceNeedsUpdate), central: true)
            transportButton("Next", symbol: "forward.end.fill", command: .next,
                enabled: snapshot.canGoNext == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate)
        }
    }

    private func transportButton(_ name: String, symbol: String, command: CommandName,
                                 enabled: Bool, central: Bool = false) -> some View {
        AppIconButton(title: name, symbol: symbol, enabled: enabled, prominent: central) { action(command, nil) }
            .accessibilityIdentifier(name.lowercased())
    }

    @ViewBuilder private var progress: some View {
        if loadingAudio {
            PlayerTimelineSkeleton(timeWidth: 46)
        } else {
            timeline
        }
    }

    private var timeline: some View {
        let duration = snapshot.timeline?.duration ?? video?.durationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let raw = timelinePreview ?? snapshot.seekTarget ?? snapshot.loadedVideo?.positionSeconds ?? 0
        let position = raw.isFinite ? max(0, duration.map { min(raw, $0) } ?? raw) : 0
        return HStack(spacing: 8) {
            Text(Self.clock(position)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: 46, alignment: .leading)
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
            Text(duration.map(Self.clock) ?? "--:--").lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: 46, alignment: .trailing)
        }.font(.system(size: 10, design: .monospaced)).foregroundStyle(AppDesign.muted)
    }

    private static func clock(_ value: Double) -> String {
        let seconds = Int(min(max(0, value), 359_999))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func artwork(_ entry: VideoSummary?) -> some View {
        LibraryArtwork(localPath: entry.flatMap { snapshot.localThumbnailPaths?[$0.id] }, symbol: "music.note")
    }

    private var favoritesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PlayerNavigationButton(title: "Now Playing", symbol: "chevron.left") { favorites = false }
                Spacer()
                PlayerNavigationButton(title: "Search YouTube", symbol: "magnifyingglass", action: search)
            }.padding(.trailing, 16)
            if snapshot.favorites.isEmpty {
                Text("No favorites yet").font(.system(size: 13)).foregroundStyle(AppDesign.muted).padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(snapshot.favorites, id: \.id) { entry in
                            HStack(spacing: 4) {
                                Button { action(.select, entry.id); favorites = false } label: {
                                    HStack(spacing: 12) {
                                        artwork(entry).frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                            Text(entry.creator).font(.system(size: 10)).foregroundStyle(AppDesign.muted).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(snapshot.sourceNeedsUpdate)
                                .contextMenu { Button("Remove favorite") { action(.favoriteRemove, entry.id) } }
                                AppIconButton(title: "Remove \(entry.title) from favorites", symbol: "heart.fill") {
                                    action(.favoriteRemove, entry.id)
                                }.help("Remove favorite")
                            }.background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }.frame(height: min(320, CGFloat(snapshot.favorites.count) * 58))
            }
        }
    }
}

private struct PlayerNavigationButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppDesign.Text.primary)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(hovered ? AppDesign.Surface.hover : AppDesign.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .tidalBorder(cornerRadius: 6)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }.accessibilityLabel(title)
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
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(AppDesign.Text.primary)
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
