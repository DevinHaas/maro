import AppKit
import MaroCore
import SwiftUI

struct AppShellView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    @State private var accountPresented = false
    @State private var profileHovered = false
    @State private var hoveredAccountAction: String?
    @State private var libraryHovered = false
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                topBar.frame(height: 64).zIndex(10)
                HStack(spacing: 8) {
                    if app.libraryCollapsed {
                        CompactLibraryRail(app: app, library: library, sidebarHovered: libraryHovered).frame(width: 72)
                            .background(AppDesign.surface).clipShape(RoundedRectangle(cornerRadius: 8)).tidalBorder(cornerRadius: 8)
                            .onHover { libraryHovered = $0 }
                    } else {
                        LibrarySidebar(app: app, library: library, sidebarHovered: libraryHovered).frame(width: geometry.size.width < 1200 ? 280 : 320)
                            .background(AppDesign.surface).clipShape(RoundedRectangle(cornerRadius: 8)).tidalBorder(cornerRadius: 8)
                            .onHover { libraryHovered = $0 }
                    }
                    ZStack {
                        HomeView(app: app).opacity(app.route == .home ? 1 : 0).allowsHitTesting(app.route == .home).accessibilityHidden(app.route != .home)
                        SearchResultsView(app: app).opacity(app.route == .search ? 1 : 0).allowsHitTesting(app.route == .search).accessibilityHidden(app.route != .search)
                        if app.route == .favorites { FavoritesView(app: app) }
                        if case .playlist = app.route { PlaylistDetailView(app: app) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppDesign.surface).clipShape(RoundedRectangle(cornerRadius: 8)).tidalBorder(cornerRadius: 8)
                }.frame(maxHeight: .infinity)
                BottomPlayerView(app: app, presentation: app.player).frame(height: 88)
            }.padding(.horizontal, 8).padding(.bottom, 4).background(AppDesign.chrome)
                .foregroundStyle(AppDesign.Text.primary).preferredColorScheme(.dark).tint(AppDesign.green)
                .background {
                    SubtleScrollbars(sidebarWidth: app.libraryCollapsed ? 72 : geometry.size.width < 1200 ? 280 : 320,
                                     sidebarHovered: libraryHovered)
                }
        }.sheet(isPresented: Binding(get: { library.pendingVideo != nil }, set: { if !$0 { library.pendingVideo = nil } })) {
            AddToPlaylistSheet(library: library)
        }
    }
    private var topBar: some View {
        HStack(spacing: 12) {
            Text("maro").font(.system(size: 24, weight: .heavy, design: .rounded)).padding(.leading, 12)
            AppIconButton(title: "Back", symbol: "chevron.left", enabled: app.canGoBack) { app.goBack() }
            Spacer(minLength: 0)
            AppIconButton(title: "Home", symbol: "house.fill") { app.showHome() }.background(Circle().fill(AppDesign.raised))
            GlobalSearchView(app: app).frame(maxWidth: 520)
            Spacer(minLength: 0)
            Button { accountPresented.toggle() } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppDesign.Accent.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppDesign.raised))
                    .padding(4)
                    .background(Circle().fill(profileHovered ? AppDesign.Surface.hover : AppDesign.surface))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain).onHover { profileHovered = $0 }.padding(.trailing, 12)
            .help("YouTube account").accessibilityLabel("YouTube account")
            .accessibilityIdentifier("account-profile")
            .accessibilityValue(accountPresented ? "Expanded" : "Collapsed")
            .popover(isPresented: $accountPresented, arrowEdge: .bottom) {
                VStack(spacing: 2) {
                    accountAction("Create private playlist…", symbol: "plus", enabled: library.connected && !library.busy) { library.create() }
                    accountAction("Import Google credentials…", symbol: "square.and.arrow.down", enabled: !library.busy) { library.importCredentials() }
                    if library.connected {
                        accountAction("Reconnect YouTube", symbol: "arrow.clockwise") { library.connect() }
                        accountAction("Disconnect on this Mac", symbol: "rectangle.portrait.and.arrow.right") { library.disconnect() }
                    } else {
                        accountAction("Connect YouTube", symbol: "person.crop.circle.badge.checkmark", enabled: library.configured && !library.busy) { library.connect() }
                    }
                }.padding(8).frame(width: 260).background(AppDesign.surface)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func accountAction(_ title: String, symbol: String, enabled: Bool = true,
                               action: @escaping @MainActor () -> Void) -> some View {
        Button {
            accountPresented = false
            Task { @MainActor in action() }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(enabled ? AppDesign.Text.primary : AppDesign.Text.disabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 10)
                .background(hoveredAccountAction == title && enabled ? AppDesign.Surface.hover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled)
            .onHover { hoveredAccountAction = $0 ? title : nil }
    }
}

struct CompactLibraryRail: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    var sidebarHovered = false

    var body: some View {
        VStack(spacing: 8) {
            AppIconButton(title: "Show library", symbol: "sidebar.left") { app.libraryCollapsed = false }
                .accessibilityIdentifier("expand-library")
            AppIconButton(title: "Create playlist", symbol: "plus", enabled: library.connected && !library.busy) { library.create() }
                .background(Circle().fill(AppDesign.raised))
            ScrollView {
                LazyVStack(spacing: 8) {
                    CompactLibraryItem(title: "Favorites", subtitle: "Saved on this Mac", favorites: true,
                        selected: app.route == .favorites) { app.showFavorites() }
                    // The rail remains a usable library even when the expanded filter is active.
                    ForEach(library.playlists) { playlist in
                        CompactLibraryItem(title: playlist.title,
                            subtitle: ["Playlist", playlist.owner, "\(playlist.count) videos"].compactMap { $0 }.joined(separator: " · "),
                            url: playlist.thumbnailURL, selected: app.route == .playlist(playlist.id)) {
                                app.openPlaylist(playlist)
                            }
                    }
                }.frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }.subtleScrollbars(sidebarHovered: sidebarHovered)
        }.padding(.top, 10).padding(.bottom, 6)
            .accessibilityElement(children: .contain).accessibilityLabel("Your library")
            .accessibilityIdentifier("compact-library-rail")
    }
}

private struct CompactLibraryItem: View {
    let title: String
    let subtitle: String
    var url: URL?
    var favorites = false
    var selected = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            LibraryArtwork(url: url, favorites: favorites)
                .frame(width: 48, height: 48)
                // Cover images are often wider than their layout frame.
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? AppDesign.Surface.selected : hovered ? AppDesign.Surface.hover : .clear))
                .tidalBorder(cornerRadius: 6, interactive: selected, visible: selected || hovered)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }
            .help("\(title)\n\(subtitle)")
            .accessibilityLabel("\(title), \(subtitle)").accessibilityValue(selected ? "Selected" : "")
    }
}

struct LibrarySidebar: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    var sidebarHovered = false
    @FocusState private var filterFocused: Bool
    @FocusState private var collapseFocused: Bool
    @State private var isHovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppIconButton(title: "Hide library", symbol: "sidebar.left") { app.libraryCollapsed = true }
                    .focused($collapseFocused)
                    .opacity(isHovered || collapseFocused ? 1 : 0)
                    .accessibilityHidden(false)
                Label("Your Library", systemImage: "books.vertical").font(.system(size: 15, weight: .bold))
                Spacer()
                AppIconButton(title: "Create playlist", symbol: "plus", enabled: library.connected && !library.busy) { library.create() }
                AppIconButton(title: "Refresh library", symbol: "arrow.clockwise", enabled: library.connected && !library.busy) { library.refresh() }
            }.padding(.horizontal, 12).padding(.top, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppDesign.muted)
                TextField("Search your library", text: $app.libraryFilter).textFieldStyle(.plain).focused($filterFocused).accessibilityLabel("Filter your library")
                if !app.libraryFilter.isEmpty {
                    Button { app.libraryFilter = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear library filter")
                }
            }.padding(10).background(AppDesign.raised).clipShape(Capsule()).tidalCapsuleBorder(focused: filterFocused, interactive: true).padding(.horizontal, 12)
            ScrollView {
                LazyVStack(spacing: 2) {
                    if app.favoritesVisible {
                        LibraryRow(title: "Favorites", subtitle: "Saved on this Mac", favorites: true, selected: app.route == .favorites) { app.showFavorites() }
                    }
                    ForEach(app.filteredPlaylists) { playlist in
                        LibraryRow(title: playlist.title, subtitle: ["Playlist", playlist.owner, "\(playlist.count) videos"].compactMap { $0 }.joined(separator: " · "),
                            url: playlist.thumbnailURL, selected: app.route == .playlist(playlist.id)) { app.openPlaylist(playlist) }
                    }
                    if app.filteredPlaylists.isEmpty && !app.libraryFilter.isEmpty && !app.favoritesVisible {
                        Text("No matching playlists").foregroundStyle(AppDesign.muted).padding(20)
                    }
                    if library.playlists.isEmpty && library.connected && !library.busy && app.libraryFilter.isEmpty {
                        Text("Your playlists will appear here. Create one to get started.").font(.system(size: 12)).foregroundStyle(AppDesign.muted).padding(16)
                    }
                }.padding(.horizontal, 6)
            }.subtleScrollbars(sidebarHovered: sidebarHovered)
            VStack(alignment: .leading, spacing: 8) {
                if !library.connected {
                    Text("YouTube is not connected.").font(.system(size: 13, weight: .semibold))
                    Text("Reconnect to reload your playlists.").font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                    Button(library.configured ? "Reconnect YouTube" : "Import Google credentials…") {
                        if library.configured { library.connect() } else { library.importCredentials() }
                    }.buttonStyle(.borderedProminent).disabled(library.busy)
                    if library.signingIn { Button("Cancel sign-in") { library.cancelSignIn() } }
                    if library.canRetry { Button("Retry connection") { library.retryLast() }.disabled(library.busy) }
                }
            }.padding(16)
        }
        .onHover { isHovered = $0 }
    }
}

struct AddToPlaylistSheet: View {
    @ObservedObject var library: PlaylistLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add to playlist").font(.title2.bold())
            Text(library.pendingVideo?.title ?? "").lineLimit(2).foregroundStyle(AppDesign.Text.secondary)
            if library.connected {
                Picker("Playlist", selection: $library.destination) { ForEach(library.playlists) { Text($0.title).tag($0.id) } }
                if library.playlists.isEmpty { Button("Create private playlist…") { library.create() } }
            } else { Text("Connect YouTube from the account menu to add videos to your own playlists.") }
            Text(library.status).font(.caption).foregroundStyle(AppDesign.Text.secondary)
            HStack {
                Button("Cancel") { library.pendingVideo = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { library.addPending() }.buttonStyle(.borderedProminent).foregroundStyle(AppDesign.Text.onAccent)
                    .disabled(!library.connected || library.destination.isEmpty || library.busy).keyboardShortcut(.defaultAction)
            }
        }.foregroundStyle(AppDesign.Text.primary).padding(24).frame(width: 420)
            .background(AppDesign.Surface.raised).tidalBorder(cornerRadius: 0).preferredColorScheme(.dark).tint(AppDesign.Accent.primary)
    }
}
