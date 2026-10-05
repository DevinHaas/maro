// Compile alongside app sources excluding MaroApp.swift, linking MaroCore objects.
// Uses the actual checkbox rows with isolated playlist state and local JPEG artwork; never accesses an account.
import AppKit
import SwiftUI
import MaroCore

private struct PickerFixture: View {
    let artworkPath: String
    let query: String
    let saving: Bool
    var overflow = false
    @State var selectedIDs: Set<String>
    private var playlists: [YouTubePlaylist] { [
        YouTubePlaylist(id: "PLsaved", title: "Nordic Beats", count: 18),
        YouTubePlaylist(id: "PLgym", title: "GYM", count: 149),
        YouTubePlaylist(id: "PLblue", title: "Blues Baby", count: 45),
        YouTubePlaylist(id: "PLlong", title: "An especially long playlist title that clips safely", count: 230)
    ] + (overflow ? (0..<12).map { YouTubePlaylist(id: "extra\($0)", title: "Additional destination \($0 + 1)", count: 12) } : []) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to playlists").font(.system(size: 14, weight: .bold))
            HStack { Image(systemName: "magnifyingglass"); Text(query.isEmpty ? "Find a playlist" : query); Spacer() }
                .font(.system(size: 12)).foregroundStyle(AppDesign.muted).padding(9)
                .background(AppDesign.Surface.panel, in: RoundedRectangle(cornerRadius: 5))
            Label("New private playlist…", systemImage: "plus").font(.system(size: 12))
            Divider()
            Text("YOUR PLAYLISTS").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(AppDesign.muted)
            PlaylistDestinationList(playlists: playlists.filter { query.isEmpty || $0.title.localizedStandardContains(query) },
                selectedIDs: $selectedIDs, savedIDs: ["PLsaved"], saving: saving, localArtworkPath: artworkPath)
                .frame(height: 200)
            Divider()
            HStack {
                Text("\(selectedIDs.count) selected").font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                Spacer()
                Button("Cancel") {}.disabled(saving)
                Button(saving ? "Adding…" : "Add") {}.buttonStyle(.borderedProminent).disabled(saving || selectedIDs.isEmpty)
            }
        }.padding(14).frame(width: 330).background(AppDesign.Surface.raised).foregroundStyle(AppDesign.Text.primary)
            .preferredColorScheme(.dark).tint(AppDesign.green)
    }
}

@main struct PlaylistPickerCheck {
    @MainActor static func main() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let artwork = CommandLine.arguments[2]
        precondition(NSImage(contentsOfFile: artwork) != nil, "A real local artwork fixture is required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, query, saving, selected, overflow) in [
            ("picker-open", "", false, Set<String>(), false),
            ("picker-multi-selected", "", false, Set(["PLgym", "PLblue"]), false),
            ("picker-search", "Blues", false, Set(["PLgym", "PLblue"]), false),
            ("picker-saving", "", true, Set(["PLgym", "PLblue"]), false),
            ("picker-overflow", "", false, Set<String>(), true)
        ] {
            let view = NSHostingView(rootView: PickerFixture(artworkPath: artwork, query: query, saving: saving, overflow: overflow, selectedIDs: selected))
            let size = view.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = view
            view.frame = NSRect(origin: .zero, size: size)
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(180))
            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            // This executable has no NSApplication.run() loop. Let the native
            // background's queued styling complete after materializing the scroll view.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async { continuation.resume() }
            }
            var scrollCount = 0
            func checkScrollbars(_ node: NSView) {
                if let scroll = node as? NSScrollView {
                    scrollCount += 1
                    precondition(scroll.scrollerStyle == .overlay, "Picker scroller must use overlay style")
                    if scroll.hasVerticalScroller, let scroller = scroll.verticalScroller {
                        precondition(String(describing: type(of: scroller)).contains("SubtleScroller"), "Picker must use the shared native scroller")
                    }
                }
                node.subviews.forEach(checkScrollbars)
            }
            checkScrollbars(view)
            precondition(scrollCount > 0, "Picker scroll view must exist")
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No native bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            print("PASS: \(name) \(Int(size.width))×\(Int(size.height)); fixture performs no writes")
            window.close()
        }
    }
}
