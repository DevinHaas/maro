import SwiftUI

/// Right-hand reference of every keyboard shortcut, toggled with `?` like Todoist.
/// Keep this list in step with the key handlers it describes.
struct KeyboardShortcutsPanel: View {
    @ObservedObject var app: ApplicationModel
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    static let groups: [(title: String, shortcuts: [(action: String, keys: [String])])] = [
        ("General", [
            ("Search", ["⌘", "K"]),
            ("Show keyboard shortcuts", ["?"]),
            ("Close panel or hide window", ["Esc"]),
            ("Move focus", ["Tab"]),
            ("Move focus backwards", ["⇧", "Tab"]),
        ]),
        ("Vim navigation", [
            ("Move left", ["H"]),
            ("Move down", ["J"]),
            ("Move up", ["K"]),
            ("Move right", ["L"]),
            ("Activate focused item", ["Return"]),
        ]),
        ("Search suggestions", [
            ("Previous suggestion", ["↑"]),
            ("Next suggestion", ["↓"]),
            ("Search or play selected", ["Return"]),
            ("Close suggestions", ["Esc"]),
        ]),
        ("Playback", [
            ("Seek back 5 seconds", ["←"]),
            ("Seek forward 5 seconds", ["→"]),
        ]),
        ("Dialogs", [
            ("Confirm", ["Return"]),
            ("Cancel", ["Esc"]),
        ]),
    ]

    private var filtered: [(title: String, shortcuts: [(action: String, keys: [String])])] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return Self.groups }
        return Self.groups.compactMap { group in
            let matches = group.title.localizedCaseInsensitiveContains(needle) ? group.shortcuts
                : group.shortcuts.filter { shortcut in
                    shortcut.action.localizedCaseInsensitiveContains(needle)
                        || shortcut.keys.contains { $0.localizedCaseInsensitiveCompare(needle) == .orderedSame }
                }
            return matches.isEmpty ? nil : (group.title, matches)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Keyboard shortcuts", systemImage: "keyboard").font(.system(size: 15, weight: .bold))
                Spacer()
                AppIconButton(title: "Close keyboard shortcuts", symbol: "xmark") { app.shortcutsOpen = false }
            }.padding(.horizontal, 12).padding(.top, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppDesign.muted)
                TextField("Search shortcuts", text: $query).textFieldStyle(.plain).focused($queryFocused)
                    .accessibilityLabel("Search keyboard shortcuts")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear shortcut search")
                }
            }.padding(10).background(AppDesign.raised).clipShape(Capsule())
                .tidalCapsuleBorder(focused: queryFocused, interactive: true).padding(.horizontal, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filtered, id: \.title) { group in
                        Text(group.title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(AppDesign.muted)
                            .padding(.top, 12).padding(.bottom, 2)
                        ForEach(group.shortcuts, id: \.action) { shortcut in
                            HStack {
                                Text(shortcut.action).font(.system(size: 13))
                                Spacer(minLength: 8)
                                HStack(spacing: 4) {
                                    ForEach(shortcut.keys, id: \.self) { key in
                                        Text(key).font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6).frame(minWidth: 22, minHeight: 22)
                                            .background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }.padding(.vertical, 4)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(shortcut.action): \(shortcut.keys.joined(separator: " "))")
                        }
                    }
                    if filtered.isEmpty {
                        Text("No shortcuts match “\(query)”.").font(.caption).foregroundStyle(AppDesign.muted).padding(.top, 12)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }.subtleScrollbars()
        }.accessibilityElement(children: .contain).accessibilityLabel("Keyboard shortcuts")
    }
}
