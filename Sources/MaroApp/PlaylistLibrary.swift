import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MaroCore

@MainActor
final class PlaylistLibrary: ObservableObject {
    @Published var playlists: [YouTubePlaylist] = []
    @Published var items: [YouTubePlaylistItem] = []
    @Published var selected: YouTubePlaylist?
    @Published var busy = false
    @Published var connected = false
    @Published var configured = false
    @Published var status = "Connect YouTube to browse your own playlists."
    @Published var stale = false
    @Published var pendingVideo: VideoSummary?
    @Published var destination = ""
    @Published var signingIn = false
    @Published var canRetry = false
    private var account: YouTubeAccount?
    private var api: YouTubePlaylists?
    private var retry: (() async throws -> Void)?
    private var operation: Task<Void, Never>?
    private let controller: MaroController
    private var accountRevision = 0

    init(controller: MaroController, api: YouTubePlaylists? = nil) {
        self.controller = controller
        if let api {
            self.api = api; connected = true; configured = true
            return
        }
        do {
            let account = try YouTubeAccount(keychainService:
                ProcessInfo.processInfo.environment["MARO_KEYCHAIN_SERVICE"] ?? "Maro.YouTube")
            self.account = account
            self.api = YouTubePlaylists(token: { try await account.accessToken() })
            connected = account.isConnected; configured = account.isConfigured
        } catch { status = error.localizedDescription }
    }

    func importCredentials() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose the downloaded JSON for your Google Desktop app OAuth client."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let account = try account ?? YouTubeAccount()
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 65_536 else { throw YouTubeAccountError("This credentials file is too large.") }
            try account.configure(json: Data(contentsOf: url))
            self.account = account
            api = YouTubePlaylists(token: { try await account.accessToken() })
            configured = true; connected = false
            accountRevision += 1
            playlists = []; items = []; selected = nil
            retry = nil; canRetry = false; stale = false
            status = "Credentials imported. Connect YouTube to continue."
        } catch { status = error.localizedDescription }
    }

    func connect() {
        guard let account else { return }
        run {
            self.signingIn = true
            defer { self.signingIn = false }
            self.status = "Finish Google sign-in in your browser."
            try await account.connect { NSWorkspace.shared.open($0) }
            self.connected = true
            self.playlists = []; self.items = []; self.selected = nil
            try await self.reload()
        }
    }

    func cancelSignIn() { operation?.cancel(); account?.cancelSignIn() }

    func disconnect() {
        do {
            try account?.disconnect()
            accountRevision += 1
            connected = false; playlists = []; items = []; selected = nil
            pendingVideo = nil; retry = nil; canRetry = false; stale = false
            status = "Disconnected on this Mac. Your YouTube playlists are unchanged."
        } catch { status = error.localizedDescription }
    }

    func refresh() {
        guard connected else { return }
        run { try await self.reload() }
    }

    func open(_ playlist: YouTubePlaylist) {
        selected = playlist; items = []
        refresh()
    }

    func back() { selected = nil; items = []; refresh() }

    func addPending() {
        guard let video = pendingVideo, !destination.isEmpty, let api else { return }
        let destination = destination
        mutate {
            try await api.add(video, to: destination)
            if self.pendingVideo == video { self.pendingVideo = nil }
        }
    }

    func create() {
        guard let name = askName(title: "Create private playlist", value: "") else { return }
        create(title: name)
    }

    func create(title: String) {
        guard let api else { return }
        var created: YouTubePlaylist?
        mutate({ created = try await api.create(title: title) }, reconcile: {
            guard let created else { return }
            self.playlists.removeAll { $0.id == created.id }
            self.playlists.insert(created, at: 0)
            self.destination = created.id
            self.status = "Playlist created."
        })
    }

    func confirmDelete() {
        guard let selected else { return }
        let alert = PlaylistDialogs.deletion(title: selected.title)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        delete(selected)
    }

    func delete(_ playlist: YouTubePlaylist) {
        guard let api else { return }
        mutate({ try await api.delete(playlist.id) }, reconcile: {
            self.playlists.removeAll { $0.id == playlist.id }
            if self.selected?.id == playlist.id { self.selected = nil; self.items = [] }
            if self.destination == playlist.id { self.destination = self.playlists.first?.id ?? "" }
            self.status = "Playlist deleted from YouTube."
        })
    }

    func rename() {
        guard let selected, let name = askName(title: "Rename playlist", value: selected.title), let api else { return }
        mutate { try await api.rename(selected.id, title: name) }
    }

    func remove(_ item: YouTubePlaylistItem) {
        guard let api, let playlistID = selected?.id else { return }
        mutate({ try await api.remove(item) }, reconcile: {
            guard self.selected?.id == playlistID else { return }
            self.items.removeAll { $0.id == item.id }
        })
    }

    func move(_ item: YouTubePlaylistItem, offset: Int) {
        guard let selected, let api, let index = items.firstIndex(where: { $0.id == item.id }),
              items.indices.contains(index + offset) else { return }
        mutate { try await api.move(item, in: selected.id, to: index + offset) }
    }

    func play(from index: Int = 0) {
        let items = items
        guard items.indices.contains(index) else { return }
        Task {
            do {
                try await controller.playPlaylist(items, startingAt: index)
                status = controller.snapshot.error ?? "Playing in saved order. Edits apply the next time you play this playlist."
            } catch is CancellationError { }
            catch { status = "Could not play this selection. \(controller.snapshot.error ?? error.localizedDescription)" }
        }
    }

    func retryLast() { if let retry { run(retry) } }

    private func reload() async throws {
        guard let api else { return }
        let revision = accountRevision
        let fresh = try await api.playlists()
        // Opening another playlist while a read is in flight must not restore the old page.
        while true {
            let requestedID = selected?.id
            let freshSelected = fresh.first { $0.id == requestedID }
            var freshItems: [YouTubePlaylistItem] = []
            if let freshSelected { freshItems = try await api.items(in: freshSelected.id) }
            guard revision == accountRevision, connected else { return }
            guard requestedID == selected?.id else { continue }
            playlists = fresh; selected = freshSelected; items = freshItems
            break
        }
        if !fresh.contains(where: { $0.id == destination }) { destination = fresh.first?.id ?? "" }
        stale = false
        status = fresh.isEmpty ? "No playlists yet. Create your first private playlist." : "Up to date with YouTube."
    }

    private func mutate(_ write: @escaping () async throws -> Void, reconcile: @escaping () -> Void = {}) {
        run {
            do { try await write() }
            catch {
                // A timed-out write may already have reached YouTube. Never replay it automatically.
                self.retry = { try await self.reload() }
                throw YouTubeAccountError("\(error.localizedDescription) Refresh to check YouTube before trying the edit again.")
            }
            // Keep confirmed writes visible even when the immediate list response lags behind.
            reconcile()
            defer { reconcile() }
            self.retry = { try await self.reload() }
            do { try await self.reload() }
            catch { throw YouTubeAccountError("Saved on YouTube, but refresh failed. Retry refresh to see the updated playlist.") }
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true; canRetry = false; retry = action
        operation = Task {
            defer { busy = false; operation = nil }
            do { try await action(); canRetry = false; retry = nil }
            catch is CancellationError { status = "Sign-in cancelled."; retry = nil }
            catch { stale = !playlists.isEmpty; status = error.localizedDescription; canRetry = true }
        }
    }

    private func askName(title: String, value: String) -> String? {
        let (alert, field) = PlaylistDialogs.name(title: title, value: value)
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

/// Native dialogs retain keyboard/modal semantics and explicit cancellation.
@MainActor enum PlaylistDialogs {
    private static func styledAlert() -> NSAlert {
        let alert = NSAlert()
        alert.window.appearance = NSAppearance(named: .darkAqua)
        alert.window.backgroundColor = MaroAppearance.background
        return alert
    }

    static func name(title: String, value: String) -> (NSAlert, NSTextField) {
        let alert = styledAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        MaroAppearance.primary(alert.buttons[0])
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        field.font = .systemFont(ofSize: 13)
        field.setAccessibilityLabel("Playlist name")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        applySurface(alert)
        return (alert, field)
    }

    static func deletion(title: String) -> NSAlert {
        let alert = styledAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete “\(title)”?"
        alert.informativeText = "This permanently deletes the playlist from YouTube. The videos themselves are not deleted."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete playlist")
        // Return must never approve destruction by default.
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        alert.window.initialFirstResponder = alert.buttons[0]
        applySurface(alert)
        return alert
    }

    private static func applySurface(_ alert: NSAlert) {
        alert.layout()
        alert.window.contentView?.wantsLayer = true
        alert.window.contentView?.layer?.backgroundColor = MaroAppearance.background.cgColor
    }
}

struct PlaylistLibraryView: View {
    @ObservedObject var library: PlaylistLibrary
    @State private var selectedItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(library.selected?.title ?? "Your YouTube playlists", systemImage: "music.note.list")
                    .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Spacer()
                if library.busy { ProgressView().controlSize(.small) }
                if library.connected {
                    Button("Refresh") { library.refresh() }.disabled(library.busy)
                    Menu("Account") {
                        Button("Reconnect YouTube") { library.connect() }
                        Button("Disconnect on this Mac") { library.disconnect() }
                    }.disabled(library.busy).fixedSize()
                }
            }
            if !library.connected {
                Text("Connect your Google account to create and edit your own YouTube playlists. New playlists are private.")
                Text("Google's permission covers more than playlists. Maro uses it only for playlist access and editing.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Import Google credentials…") { library.importCredentials() }.disabled(library.busy)
                    Button("Connect YouTube") { library.connect() }
                        .buttonStyle(.borderedProminent).disabled(!library.configured || library.busy)
                }
                Link("Google Desktop app setup instructions", destination: URL(string: "https://developers.google.com/youtube/v3/guides/auth/installed-apps")!)
                Spacer()
            } else {
                if let pending = library.pendingVideo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add: \(pending.title)").lineLimit(1)
                        HStack {
                            Picker("Playlist", selection: $library.destination) {
                                ForEach(library.playlists) { Text($0.title).tag($0.id) }
                            }
                            Button("Add") { library.addPending() }.disabled(library.destination.isEmpty)
                            Button("Cancel") { library.pendingVideo = nil }
                        }
                    }.padding(12).background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: MaroAppearance.border).opacity(0.3)))
                        .cornerRadius(8).disabled(library.busy)
                }
                if library.selected == nil {
                    List(library.playlists) { playlist in
                        Button { library.open(playlist); selectedItem = nil } label: {
                            HStack {
                                Image(systemName: "music.note.list")
                                Text(playlist.title).lineLimit(1)
                                Spacer()
                                Text("\(playlist.count) videos").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                            }.padding(.vertical, 5).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(library.busy)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if library.playlists.isEmpty && !library.busy {
                            Text("No playlists yet. Create one to get started.")
                                .foregroundStyle(.secondary).allowsHitTesting(false)
                        }
                    }
                    Button("Create playlist…") { library.create() }
                        .buttonStyle(.borderedProminent).disabled(library.busy)
                } else {
                    HStack {
                        Button("All playlists") { library.back(); selectedItem = nil }
                        Button("Rename…") { library.rename() }
                        Button("Delete playlist…", role: .destructive) { library.confirmDelete() }
                        Spacer()
                        Button("Play all") { library.play() }.disabled(library.items.isEmpty)
                    }.disabled(library.busy)
                    List(selection: $selectedItem) {
                        ForEach(Array(library.items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(item.title).lineLimit(1)
                                    Text(item.video?.creator ?? "Unavailable · skipped during playback")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button { library.play(from: index) } label: { Image(systemName: "play.fill") }
                                    .help("Play from this video").accessibilityLabel("Play \(item.title)")
                            }.tag(item.id).padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button("Move up") { if let item = selection { library.move(item, offset: -1) } }
                            .disabled(selection?.video == nil || selectedItem == library.items.first?.id)
                        Button("Move down") { if let item = selection { library.move(item, offset: 1) } }
                            .disabled(selection?.video == nil || selectedItem == library.items.last?.id)
                        Spacer()
                        Button("Remove video") { if let item = selection { library.remove(item) } }.disabled(selection == nil)
                    }.disabled(library.busy)
                }
            }
            if library.stale { Text("Previously loaded data · may be outdated").font(.caption).foregroundStyle(.orange) }
            HStack(alignment: .top) {
                Text(library.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                if library.signingIn { Button("Cancel sign-in") { library.cancelSignIn() } }
                else if library.canRetry { Button("Retry") { library.retryLast() }.disabled(library.busy) }
            }
        }.font(.system(size: 12))
            .controlSize(.small)
            .tint(Color(nsColor: MaroAppearance.accent))
            .padding(16).frame(minWidth: 490, minHeight: 360)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: MaroAppearance.background))
            .preferredColorScheme(.dark)
    }

    private var selection: YouTubePlaylistItem? { library.items.first { $0.id == selectedItem } }
}
