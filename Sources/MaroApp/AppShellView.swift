import AppKit
import MaroCore
import SwiftUI

struct AppShellView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                topBar.frame(height: 64)
                HStack(spacing: 8) {
                    if !app.libraryCollapsed {
                        LibrarySidebar(app: app, library: library).frame(width: geometry.size.width < 1200 ? 280 : 320)
                            .background(AppDesign.surface).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    ZStack {
                        HomeView(app: app).opacity(app.route == .home ? 1 : 0).allowsHitTesting(app.route == .home).accessibilityHidden(app.route != .home)
                        SearchResultsView(app: app).opacity(app.route == .search ? 1 : 0).allowsHitTesting(app.route == .search).accessibilityHidden(app.route != .search)
                        if app.route == .favorites { FavoritesView(app: app) }
                        if case .playlist = app.route { PlaylistDetailView(app: app) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppDesign.surface).clipShape(RoundedRectangle(cornerRadius: 8))
                }.frame(maxHeight: .infinity)
                BottomPlayerView(app: app, presentation: app.player).frame(height: 88)
            }.padding(.horizontal, 8).padding(.bottom, 4).background(AppDesign.chrome)
                .preferredColorScheme(.dark).tint(AppDesign.green)
        }.sheet(isPresented: Binding(get: { library.pendingVideo != nil }, set: { if !$0 { library.pendingVideo = nil } })) {
            AddToPlaylistSheet(library: library)
        }
    }
    private var topBar: some View {
        HStack(spacing: 12) {
            Text("maro").font(.system(size: 24, weight: .heavy, design: .rounded)).padding(.leading, 12)
            AppIconButton(title: "Back", symbol: "chevron.left", enabled: app.canGoBack) { app.goBack() }
            AppIconButton(title: app.libraryCollapsed ? "Show library" : "Hide library", symbol: "sidebar.left") { app.libraryCollapsed.toggle() }
            Spacer(minLength: 0)
            AppIconButton(title: "Home", symbol: "house.fill") { app.showHome() }.background(Circle().fill(AppDesign.raised))
            GlobalSearchView(app: app).frame(maxWidth: 520)
            Spacer(minLength: 0)
            Menu {
                Button("Create private playlist…") { library.create() }.disabled(!library.connected || library.busy)
                Button("Import Google credentials…") { library.importCredentials() }.disabled(library.busy)
                if library.connected {
                    Button("Reconnect YouTube") { library.connect() }
                    Button("Disconnect on this Mac") { library.disconnect() }
                } else { Button("Connect YouTube") { library.connect() }.disabled(!library.configured || library.busy) }
            } label: { Image(systemName: "person.crop.circle.fill").font(.system(size: 28)).foregroundStyle(AppDesign.muted) }
                .menuStyle(.borderlessButton).fixedSize().frame(width: 40).padding(.trailing, 12).accessibilityLabel("YouTube account")
        }
    }
}

struct LibrarySidebar: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your Library", systemImage: "books.vertical").font(.system(size: 15, weight: .bold))
                Spacer()
                AppIconButton(title: "Create playlist", symbol: "plus", enabled: library.connected && !library.busy) { library.create() }
                AppIconButton(title: "Refresh library", symbol: "arrow.clockwise", enabled: library.connected && !library.busy) { library.refresh() }
            }.padding(.horizontal, 12).padding(.top, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppDesign.muted)
                TextField("Search your library", text: $app.libraryFilter).textFieldStyle(.plain).accessibilityLabel("Filter your library")
                if !app.libraryFilter.isEmpty {
                    Button { app.libraryFilter = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear library filter")
                }
            }.padding(10).background(AppDesign.raised).clipShape(Capsule()).padding(.horizontal, 12)
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
            }
            VStack(alignment: .leading, spacing: 8) {
                if !library.connected {
                    Text("Bring your YouTube playlists here.").font(.system(size: 13, weight: .semibold))
                    Text("Connect your account to browse and edit your own playlists.").font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                    Button(library.configured ? "Connect YouTube" : "Import Google credentials…") {
                        if library.configured { library.connect() } else { library.importCredentials() }
                    }.buttonStyle(.borderedProminent).disabled(library.busy)
                }
                if library.busy { HStack { ProgressView().controlSize(.small); Text(library.signingIn ? "Finish sign-in in your browser…" : "Updating library…").font(.caption) } }
                if library.stale { Text("Previously loaded data · may be outdated").font(.caption).foregroundStyle(.orange) }
                Text(library.status).font(.system(size: 10)).foregroundStyle(AppDesign.muted).lineLimit(3).textSelection(.enabled)
                if library.signingIn { Button("Cancel sign-in") { library.cancelSignIn() } }
                if library.canRetry { Button("Retry refresh") { library.retryLast() }.disabled(library.busy) }
            }.padding(16)
        }
    }
}

struct AddToPlaylistSheet: View {
    @ObservedObject var library: PlaylistLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add to playlist").font(.title2.bold())
            Text(library.pendingVideo?.title ?? "").lineLimit(2).foregroundStyle(.secondary)
            if library.connected {
                Picker("Playlist", selection: $library.destination) { ForEach(library.playlists) { Text($0.title).tag($0.id) } }
                if library.playlists.isEmpty { Button("Create private playlist…") { library.create() } }
            } else { Text("Connect YouTube from the account menu to add videos to your own playlists.") }
            Text(library.status).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { library.pendingVideo = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { library.addPending() }.buttonStyle(.borderedProminent)
                    .disabled(!library.connected || library.destination.isEmpty || library.busy).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 420).background(AppDesign.surface).preferredColorScheme(.dark).tint(AppDesign.green)
    }
}
