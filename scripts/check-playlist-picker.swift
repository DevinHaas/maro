// Compile with AppDesign.swift, PlaylistDestinationList.swift and MaroCore objects.
// Uses the actual checkbox rows with isolated playlist state and local JPEG artwork; never accesses an account.
import AppKit
import SwiftUI
import MaroCore

private struct PickerFixture: View {
    let artworkPath: String
    let query: String
    let saving: Bool
    @State var selectedIDs: Set<String>
    private let playlists = [
        YouTubePlaylist(id: "PLsaved", title: "Nordic Beats", count: 18),
        YouTubePlaylist(id: "PLgym", title: "GYM", count: 149),
        YouTubePlaylist(id: "PLblue", title: "Blues Baby", count: 45),
        YouTubePlaylist(id: "PLlong", title: "An especially long playlist title that clips safely", count: 230)
    ]
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
    @MainActor static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let artwork = CommandLine.arguments[2]
        precondition(NSImage(contentsOfFile: artwork) != nil, "A real local artwork fixture is required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, query, saving, selected) in [
            ("picker-open", "", false, Set<String>()),
            ("picker-multi-selected", "", false, Set(["PLgym", "PLblue"])),
            ("picker-search", "Blues", false, Set(["PLgym", "PLblue"])),
            ("picker-saving", "", true, Set(["PLgym", "PLblue"]))
        ] {
            let view = NSHostingView(rootView: PickerFixture(artworkPath: artwork, query: query, saving: saving, selectedIDs: selected))
            let size = view.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = view
            view.frame = NSRect(origin: .zero, size: size); view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No native bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            print("PASS: \(name) \(Int(size.width))×\(Int(size.height)); fixture performs no writes")
            window.close()
        }
    }
}
