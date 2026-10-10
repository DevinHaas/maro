import AppKit
import SwiftUI

enum VimDirection { case left, down, up, right }

/// Vim navigation for the application window: `h`/`j`/`k`/`l` move real keyboard focus between
/// navigation targets, Return activates the focused target. Targets report their current frames;
/// each movement is a linear scan over them (no persistent graph to invalidate).
@MainActor final class VimNavigator: ObservableObject {
    private static let defaultsKey = "MaroVimNavigation"
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.defaultsKey); if !enabled { focused = nil } }
    }
    /// The target that movement starts from and Return activates.
    @Published fileprivate(set) var focused: UUID?
    /// Like CSS `:focus-visible`: the highlight shows after keyboard focus changes, not after clicks.
    @Published fileprivate(set) var showsFocus = false
    /// Defers to another keyboard owner, such as the open search preview.
    var isSuspended: () -> Bool = { false }

    fileprivate struct Target {
        var scope: String
        var region: [String]
        var frame: CGRect
        let box: VimTargetBox
    }
    fileprivate var targets: [UUID: Target] = [:]
    fileprivate var anchors: [String: VimAnchorView] = [:]
    fileprivate var presentations: [String] = []
    private var resumeFocus: [String: UUID] = [:]
    private var monitor: Any?
    private var retrying = false

    init() { enabled = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true }

    private var scope: String { presentations.last ?? Self.mainScope }
    nonisolated static let mainScope = "main"
    nonisolated fileprivate static func key(_ scope: String, _ path: [String]) -> String { scope + "|" + path.joined(separator: "/") }

    // MARK: Event routing

    fileprivate func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }
    fileprivate func removeMonitor() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // SwiftUI may keep a dismissed sheet's view alive; a presentation ends when its window is gone.
        for scope in presentations {
            if let anchor = anchors[Self.key(scope, [])], anchor.window?.isVisible != true { present(scope, false) }
        }
        guard let window = event.window, owns(window) else { return event }
        if event.type != .keyDown { showsFocus = false; return event }
        if event.keyCode == 48 { showsFocus = true; return event } // Tab moves real focus; show it.
        guard enabled, !isSuspended(),
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              !(window.firstResponder is NSText) else { return event }
        if event.keyCode == 36 || event.keyCode == 76 {
            guard showsFocus, let id = focused, let target = targets[id], target.scope == scope else { return event }
            target.box.run()
            return nil
        }
        let direction: VimDirection
        switch event.charactersIgnoringModifiers {
        case "h": direction = .left
        case "j": direction = .down
        case "k": direction = .up
        case "l": direction = .right
        default: return event
        }
        if !retrying { move(direction) }
        return nil
    }

    /// Only the application window and its active presentation; other windows keep their input.
    private func owns(_ window: NSWindow) -> Bool {
        if window === anchors[Self.key(Self.mainScope, [])]?.window { return true }
        guard let presentation = presentations.last else { return false }
        return window === anchors[Self.key(presentation, [])]?.window
    }

    // MARK: Movement

    func move(_ direction: VimDirection, attempt: Int = 0) {
        let scope = scope
        let pool = targets.filter { $0.value.scope == scope }
        guard showsFocus, let id = focused, let origin = pool[id] else {
            // Nothing visibly focused (first use, after a click, or the target disappeared): start at the
            // first visible content target. Hidden focus, such as SwiftUI's automatic initial focus, is ignored.
            let first = pool.filter { isVisible($0.value, except: nil) }.min { lhs, rhs in
                let a = lhs.value, b = rhs.value
                let aContent = a.region.first == "content", bContent = b.region.first == "content"
                if aContent != bContent { return aContent }
                return (a.frame.minY, a.frame.minX) < (b.frame.minY, b.frame.minX)
            }
            if let first { focus(first.key) }
            return
        }
        for depth in stride(from: origin.region.count, through: 0, by: -1) {
            let region = Array(origin.region.prefix(depth))
            let candidates = pool.filter { candidate in
                candidate.key != id && candidate.value.region.starts(with: region)
                    && isVisible(candidate.value, except: depth > 0 ? region : nil)
            }.map { ($0.key, $0.value.frame) }
            // Irregular layouts may use unaligned targets inside the origin's own region only.
            if let next = Self.best(from: origin.frame, direction, among: candidates, alignedOnly: depth < origin.region.count) {
                focus(next); return
            }
            // Reveal further (possibly not yet materialized) targets before leaving the region.
            if depth > 0, attempt < 100, let anchor = anchors[Self.key(scope, region)], anchor.scroll(direction) {
                retrying = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.retrying = false
                    self?.move(direction, attempt: attempt + 1)
                }
                return
            }
        }
        let visible = pool.filter { $0.key != id && isVisible($0.value, except: nil) }.map { ($0.key, $0.value.frame) }
        if let next = Self.best(from: origin.frame, direction, among: visible, alignedOnly: false) { focus(next) }
        // Otherwise there is no destination: focus stays put (no wraparound).
    }

    /// Alignment first: targets overlapping the origin across the movement axis win over closer
    /// diagonal ones. Among aligned targets the nearest row/column wins, then the closest centre.
    static func best(from origin: CGRect, _ direction: VimDirection, among candidates: [(UUID, CGRect)],
                     alignedOnly: Bool) -> UUID? {
        let vertical = direction == .up || direction == .down
        // Beyond the origin's edge, not just its centre: a wide row does not lead to controls above it.
        func ahead(_ r: CGRect) -> Bool {
            switch direction {
            case .down: r.minY >= origin.maxY - 4
            case .up: r.maxY <= origin.minY + 4
            case .right: r.minX >= origin.maxX - 4
            case .left: r.maxX <= origin.minX + 4
            }
        }
        func along(_ r: CGRect) -> CGFloat { vertical ? abs(r.midY - origin.midY) : abs(r.midX - origin.midX) }
        func across(_ r: CGRect) -> CGFloat { vertical ? abs(r.midX - origin.midX) : abs(r.midY - origin.midY) }
        func aligned(_ r: CGRect) -> Bool {
            vertical ? r.minX < origin.maxX && r.maxX > origin.minX : r.minY < origin.maxY && r.maxY > origin.minY
        }
        // Deterministic ties regardless of dictionary order.
        func earlier(_ a: (UUID, CGRect), _ b: (UUID, CGRect), _ score: (CGRect) -> CGFloat) -> Bool {
            (score(a.1), a.1.minY, a.1.minX, a.0.uuidString) < (score(b.1), b.1.minY, b.1.minX, b.0.uuidString)
        }
        let ahead = candidates.filter { ahead($0.1) }
        let alignedTargets = ahead.filter { aligned($0.1) }
        if let nearest = alignedTargets.map({ along($0.1) }).min() {
            // ponytail: fixed 8-point tolerance groups one visual row; derive from row height if layouts need it.
            return alignedTargets.filter { along($0.1) <= nearest + 8 }.min { earlier($0, $1, across) }?.0
        }
        return alignedOnly ? nil : ahead.min { earlier($0, $1) { along($0) + 2 * across($0) } }?.0
    }

    /// Visible through every scroll region on the target's path, except `region`, which may scroll to reveal it.
    private func isVisible(_ target: Target, except region: [String]?) -> Bool {
        (1...max(1, target.region.count)).allSatisfy { depth in
            let path = Array(target.region.prefix(depth))
            guard path != region, let visible = anchors[Self.key(target.scope, path)]?.scrollVisibleRect else { return true }
            return visible.intersects(target.frame)
        }
    }

    private func focus(_ id: UUID) {
        guard let target = targets[id] else { return }
        focused = id
        showsFocus = true
        anchors[Self.key(target.scope, [])]?.window?.makeKey()
        for depth in stride(from: target.region.count, to: 0, by: -1) {
            anchors[Self.key(target.scope, Array(target.region.prefix(depth)))]?.reveal(target.frame)
        }
    }

    // MARK: Registration

    fileprivate func register(_ id: UUID, _ target: Target?) {
        targets[id] = target
        if target == nil, focused == id { focused = nil }
    }
    fileprivate func focusChanged(_ id: UUID, _ isFocused: Bool) {
        if isFocused {
            guard targets[id] != nil else { return }
            focused = id
        } else if focused == id { focused = nil }
    }
    fileprivate func attach(_ anchor: VimAnchorView, key: String) {
        anchors[key] = anchor
        if key == Self.key(Self.mainScope, []) { installMonitor() }
    }
    fileprivate func detach(_ anchor: VimAnchorView, key: String) {
        guard anchors[key] === anchor else { return }
        anchors[key] = nil
        if key == Self.key(Self.mainScope, []) { removeMonitor() }
    }
    /// A presentation takes over navigation; closing it resumes focus where it was before.
    fileprivate func present(_ scope: String, _ shown: Bool) {
        presentations.removeAll { $0 == scope }
        if shown {
            presentations.append(scope)
            resumeFocus[scope] = focused
        } else if let resumed = resumeFocus.removeValue(forKey: scope), targets[resumed] != nil {
            focused = resumed
        }
    }
}

/// The target's latest action and placement. `onChange` callbacks see a stale copy of the modifier,
/// so registration and Return read this box, which every body evaluation refreshes.
private final class VimTargetBox {
    var run: () -> Void = {}
    var eligible = false
    var scope = ""
    var region: [String] = []
}

struct VimContext {
    let navigator: VimNavigator
    var scope = VimNavigator.mainScope
    var region: [String] = []
    var eligible = true
}
private struct VimContextKey: EnvironmentKey { static let defaultValue: VimContext? = nil }
extension EnvironmentValues {
    var vimContext: VimContext? {
        get { self[VimContextKey.self] }
        set { self[VimContextKey.self] = newValue }
    }
}

extension View {
    /// Root of the application window's navigation; views outside it (e.g. the compact player) stay inert.
    func vimNavigation(_ navigator: VimNavigator) -> some View {
        environment(\.vimContext, VimContext(navigator: navigator))
            .background(VimAnchor(navigator: navigator, key: VimNavigator.key(VimNavigator.mainScope, [])))
    }
    /// A navigation target. Movement focuses it; Return runs `action`, the control's own action.
    func vimTarget(enabled: Bool = true, focusable: Bool = true, cornerRadius: CGFloat = 6,
                   action: @escaping () -> Void) -> some View {
        modifier(VimTargetModifier(enabled: enabled, focusable: focusable, cornerRadius: cornerRadius, action: action))
    }
    /// A navigation region. Apply inside a `ScrollView` with `scrolls` so movement can scroll it.
    func vimRegion(_ name: String, scrolls: Bool = false) -> some View { modifier(VimRegionModifier(name: name, scrolls: scrolls)) }
    /// Mounted-but-hidden content (inactive routes) must not receive navigation.
    func vimEligible(_ eligible: Bool) -> some View { modifier(VimEligibleModifier(eligible: eligible)) }
    /// Root of a sheet or popover: navigation stays inside it while it is shown.
    func vimPresentation() -> some View { modifier(VimPresentationModifier()) }
}

private struct VimTargetModifier: ViewModifier {
    let enabled: Bool
    let focusable: Bool
    let cornerRadius: CGFloat
    let action: () -> Void
    @Environment(\.vimContext) private var context
    func body(content: Content) -> some View {
        if let context {
            content.modifier(ActiveVimTarget(context: context, navigator: context.navigator, enabled: enabled,
                focusable: focusable, cornerRadius: cornerRadius, action: action))
        } else {
            content
        }
    }
}

private struct ActiveVimTarget: ViewModifier {
    let context: VimContext
    @ObservedObject var navigator: VimNavigator
    let enabled: Bool
    let focusable: Bool
    let cornerRadius: CGFloat
    let action: () -> Void
    @State private var id = UUID()
    @State private var box = VimTargetBox()
    @State private var frame = CGRect.null
    @FocusState private var focused: Bool
    private var eligible: Bool { enabled && context.eligible }

    func body(content: Content) -> some View {
        box.run = action
        box.eligible = eligible
        box.scope = context.scope
        box.region = context.region
        return content
            .focusable(focusable && eligible && navigator.enabled)
            .focused($focused)
            .overlay {
                if navigator.focused == id && navigator.showsFocus {
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(AppDesign.Border.focus, lineWidth: 2)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .background(GeometryReader { proxy in
                Color.clear.onAppear { frame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { frame = $0 }
            })
            .onChange(of: frame) { _ in register() }
            .onChange(of: eligible) { _ in register() }
            .onChange(of: context.region) { _ in register() }
            // Only ever claim focus: also clearing the previous target's state in the same update can drop focus entirely.
            .onChange(of: navigator.focused) { if $0 == id && !focused { focused = true } }
            .onChange(of: focused) { navigator.focusChanged(id, $0) }
            .onDisappear { navigator.register(id, nil) }
    }

    private func register() {
        navigator.register(id, box.eligible && !frame.isNull
            ? VimNavigator.Target(scope: box.scope, region: box.region, frame: frame, box: box) : nil)
    }
}

private struct VimRegionModifier: ViewModifier {
    let name: String
    let scrolls: Bool
    @Environment(\.vimContext) private var context
    func body(content: Content) -> some View {
        if let context = context.map({ VimContext(navigator: $0.navigator, scope: $0.scope, region: $0.region + [name], eligible: $0.eligible) }) {
            content.environment(\.vimContext, context)
                .background { if scrolls { VimAnchor(navigator: context.navigator, key: VimNavigator.key(context.scope, context.region)) } }
        } else {
            content
        }
    }
}

private struct VimEligibleModifier: ViewModifier {
    let eligible: Bool
    @Environment(\.vimContext) private var context
    func body(content: Content) -> some View {
        content.environment(\.vimContext, context.map {
            VimContext(navigator: $0.navigator, scope: $0.scope, region: $0.region, eligible: $0.eligible && eligible)
        })
    }
}

private struct VimPresentationModifier: ViewModifier {
    @Environment(\.vimContext) private var context
    @State private var scope = UUID().uuidString
    func body(content: Content) -> some View {
        if let context {
            content.environment(\.vimContext, VimContext(navigator: context.navigator, scope: scope))
                .background(VimAnchor(navigator: context.navigator, key: VimNavigator.key(scope, [])))
                .onAppear { context.navigator.present(scope, true) }
                .onDisappear { context.navigator.present(scope, false) }
        } else {
            content
        }
    }
}

/// Measures a region's content (or a window root) in SwiftUI's global space and links it to AppKit,
/// so movement can read the window, the visible part of a scroll view, and scroll it.
private struct VimAnchor: View {
    let navigator: VimNavigator
    let key: String
    var body: some View {
        GeometryReader { proxy in VimAnchorRepresentable(navigator: navigator, key: key, frame: proxy.frame(in: .global)) }
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct VimAnchorRepresentable: NSViewRepresentable {
    let navigator: VimNavigator
    let key: String
    let frame: CGRect
    func makeNSView(context: Context) -> VimAnchorView { VimAnchorView() }
    func updateNSView(_ view: VimAnchorView, context: Context) {
        view.global = frame
        view.navigator = navigator
        view.key = key
        navigator.attach(view, key: key)
    }
    static func dismantleNSView(_ view: VimAnchorView, coordinator: ()) {
        MainActor.assumeIsolated { view.navigator?.detach(view, key: view.key) }
    }
    func makeCoordinator() {}
}

final class VimAnchorView: NSView {
    fileprivate weak var navigator: VimNavigator?
    fileprivate var key = ""
    /// This view's frame in SwiftUI's global coordinate space (top-left origin).
    fileprivate var global = CGRect.zero
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Converts a global SwiftUI rect into `view`'s coordinates through this anchor.
    private func convert(global rect: CGRect, to view: NSView) -> CGRect {
        let local = CGRect(x: rect.minX - global.minX,
            y: isFlipped ? rect.minY - global.minY : global.maxY - rect.maxY, width: rect.width, height: rect.height)
        return view.convert(local, from: self)
    }
    private func convert(_ rect: CGRect, toGlobalFrom view: NSView) -> CGRect {
        let local = convert(rect, from: view)
        return CGRect(x: global.minX + local.minX,
            y: isFlipped ? global.minY + local.minY : global.maxY - local.maxY, width: local.width, height: local.height)
    }

    /// The scroll view's visible area in global coordinates, or nil outside a scroll view.
    fileprivate var scrollVisibleRect: CGRect? {
        guard let scrollView = enclosingScrollView, let document = scrollView.documentView else { return nil }
        return convert(scrollView.documentVisibleRect, toGlobalFrom: document)
    }
    fileprivate func reveal(_ rect: CGRect) {
        guard let document = enclosingScrollView?.documentView else { return }
        document.scrollToVisible(convert(global: rect.insetBy(dx: -8, dy: -8), to: document))
    }
    /// Scrolls half a viewport towards `direction`; false at the region's actual end.
    fileprivate func scroll(_ direction: VimDirection) -> Bool {
        guard let visible = scrollVisibleRect, let document = enclosingScrollView?.documentView else { return false }
        let step = (direction == .up || direction == .down ? visible.height : visible.width) / 2
        let remaining: CGFloat
        switch direction {
        case .down: remaining = global.maxY - visible.maxY
        case .up: remaining = visible.minY - global.minY
        case .right: remaining = global.maxX - visible.maxX
        case .left: remaining = visible.minX - global.minX
        }
        guard remaining > 1 else { return false }
        let distance = min(step, remaining)
        let offset: CGSize = switch direction {
        case .down: CGSize(width: 0, height: distance)
        case .up: CGSize(width: 0, height: -distance)
        case .right: CGSize(width: distance, height: 0)
        case .left: CGSize(width: -distance, height: 0)
        }
        document.scrollToVisible(convert(global: visible.offsetBy(dx: offset.width, dy: offset.height), to: document))
        return true
    }
}
