import SwiftUI
import MaroCore

/// A per-track save action. It never changes playback, route, or queue state.
struct SaveDestinationButton: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var library: PlaylistLibrary
    let video: VideoSummary
    var sourcePlaylistID: String? = nil
    var rowHovered = false
    var diameter: CGFloat = 34
    var iconOnly = false
    @State private var presented = false
    @State private var hovered = false
    @State private var saving = false
    @State private var selectedIDs: Set<String> = []
    @State private var query = ""
    @State private var outcomes: [PlaylistSaveOutcome] = []
    @State private var destinationTitles: [String: String] = [:]
    @State private var favoriteResult: String?
    @State private var invocationVideoID: String?
    @State private var invocationScope: String?
    @State private var suppressFocusRestore = false
    @FocusState private var buttonFocused: Bool

    init(app: ApplicationModel, video: VideoSummary, sourcePlaylistID: String? = nil, rowHovered: Bool = false, diameter: CGFloat = 34, iconOnly: Bool = false) {
        self.app = app; self.video = video; self.sourcePlaylistID = sourcePlaylistID
        self.rowHovered = rowHovered; self.diameter = diameter; self.iconOnly = iconOnly; library = app.library
    }

    private var isFavorite: Bool { app.player.snapshot.favorites.contains { $0.id == video.id } }
    private var canAddFavorite: Bool { isFavorite || app.player.snapshot.favorites.count < 20 }
    private var visible: Bool { rowHovered || hovered || buttonFocused || presented }
    private var destinations: [YouTubePlaylist] {
        library.playlists.filter { $0.id != sourcePlaylistID }.sorted {
            let left = isSaved(in: $0.id), right = isSaved(in: $1.id)
            if left != right { return left }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    private var filteredDestinations: [YouTubePlaylist] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return destinations.filter { term.isEmpty || $0.title.localizedStandardContains(term) }
    }
    private var pendingIDs: [String] {
        destinations.filter { selectedIDs.contains($0.id) && !isSaved(in: $0.id) }.map(\.id)
    }

    var body: some View {
        Group {
            if iconOnly {
                AppIconButton(title: "Save \(video.title)", symbol: "plus", action: presentPicker)
            } else {
                Button(action: presentPicker) {
                    Image(systemName: "plus")
                        .font(.system(size: diameter < 34 ? 12 : 14, weight: .semibold))
                        .foregroundStyle(buttonFocused ? AppDesign.Text.primary : AppDesign.Text.secondary)
                        .frame(width: diameter, height: diameter)
                        .background(visible ? AppDesign.Surface.panel : Color.clear, in: Circle())
                        .overlay(Circle().strokeBorder(buttonFocused ? AppDesign.Border.focus : AppDesign.Border.decorative, lineWidth: 1))
                        .contentShape(Circle())
                }.buttonStyle(.plain)
            }
        }
        .focused($buttonFocused)
        .opacity(visible ? 1 : 0).accessibilityHidden(false)
        .help("Save \(video.title)").accessibilityLabel("Save \(video.title)")
        .accessibilityHint("Choose Favorites or select multiple YouTube playlists")
        .onHover { hovered = $0 }
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            destinationPopover.frame(width: 330).background(AppDesign.Surface.raised)
                .preferredColorScheme(.dark).tint(AppDesign.green)
                .onExitCommand { presented = false }
        }
        .onChange(of: presented) { open in
            if !open {
                if suppressFocusRestore { suppressFocusRestore = false }
                else { DispatchQueue.main.async { buttonFocused = true } }
            }
        }
        .onChange(of: video.id) { _ in invalidatePopover() }
        .onChange(of: sourcePlaylistID) { _ in invalidatePopover() }
        .onChange(of: app.route) { _ in invalidatePopover() }
        .onChange(of: library.saveScopeID) { _ in invalidatePopover() }
    }

    private func presentPicker() {
        invocationVideoID = video.id; invocationScope = library.saveAccountScope
        if !saving { outcomes = []; selectedIDs = []; destinationTitles = [:] }
        query = ""; favoriteResult = nil; presented = true
    }

    private var destinationPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LibraryArtwork(url: video.thumbnailURL, localPath: app.player.snapshot.localThumbnailPaths?[video.id], symbol: "music.note")
                    .frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add to playlists").font(.system(size: 14, weight: .bold))
                    Text(video.title).font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { presented = false } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                    .buttonStyle(.plain).foregroundStyle(AppDesign.muted).help("Close save menu").accessibilityLabel("Close save menu")
            }

            Button {
                guard canAddFavorite else { return }
                app.toggleFavorite(video)
                favoriteResult = app.actionError ?? (app.player.snapshot.favorites.contains { $0.id == video.id }
                    ? "Added to Favorites." : "Removed from Favorites.")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart").foregroundStyle(AppDesign.green).frame(width: 18)
                    Text(isFavorite ? "Remove from Favorites" : "Add to Favorites").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if isFavorite { Image(systemName: "checkmark").foregroundStyle(AppDesign.green) }
                }.contentShape(Rectangle()).padding(.vertical, 8).padding(.horizontal, 9)
                    .background(AppDesign.Surface.panel, in: RoundedRectangle(cornerRadius: 5))
            }.buttonStyle(.plain).disabled(!canAddFavorite)
                .accessibilityHint(!canAddFavorite ? "Favorites are full. Remove one before adding another." : "")
            if !canAddFavorite { statusRow("Favorites are full (20 of 20). Remove one before adding another.", symbol: "heart", color: AppDesign.Status.warning) }
            if let favoriteResult { statusRow(favoriteResult, symbol: "heart", color: AppDesign.green) }

            Divider().overlay(AppDesign.Border.decorative)
            if library.connected {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppDesign.muted)
                    TextField("Find a playlist", text: $query).textFieldStyle(.plain).accessibilityLabel("Find a playlist")
                }.font(.system(size: 12)).padding(9)
                    .background(AppDesign.Surface.panel, in: RoundedRectangle(cornerRadius: 5))
                Button { library.create() } label: { Label("New private playlist…", systemImage: "plus").font(.system(size: 12)) }
                    .buttonStyle(.plain).disabled(library.busy || saving)
            }
            HStack {
                Text("YOUR PLAYLISTS").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(AppDesign.muted)
                Spacer()
                if library.stale { Text("May be outdated").font(.system(size: 9)).foregroundStyle(AppDesign.Status.warning) }
            }
            playlistContent
            if !outcomes.isEmpty {
                ScrollView { VStack(alignment: .leading, spacing: 6) { ForEach(outcomes, id: \.playlistID) { resultView($0) } } }
                    .frame(maxHeight: 100)
            }
            if library.canRetry {
                Button("Refresh YouTube library") { library.retryLast() }.disabled(library.busy || saving).font(.system(size: 11))
            }
            if library.connected && !destinations.isEmpty {
                Divider().overlay(AppDesign.Border.decorative)
                HStack {
                    Text("\(pendingIDs.count) selected").font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                    Spacer()
                    Button(outcomes.isEmpty ? "Cancel" : "Done") { presented = false }.disabled(saving)
                    Button(saving ? "Adding…" : "Add") { saveSelected() }.buttonStyle(.borderedProminent)
                        .disabled(saving || library.busy || pendingIDs.isEmpty)
                        .accessibilityLabel("Add track to \(pendingIDs.count) selected playlists")
                }
            }
        }.padding(14).frame(maxHeight: 610).accessibilityElement(children: .contain)
    }

    @ViewBuilder private var playlistContent: some View {
        if !library.connected {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect YouTube to save to your playlists.").font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                Button(library.configured ? "Connect YouTube" : "Import Google credentials…") {
                    if library.configured { library.connect() } else { library.importCredentials() }
                }.buttonStyle(.borderedProminent).disabled(library.busy)
            }.padding(.vertical, 6)
        } else if library.busy && library.playlists.isEmpty {
            progress("Loading playlists…")
        } else if library.playlists.isEmpty {
            Text(library.canRetry ? "Could not load your YouTube playlists." : "No playlists found for this account.")
                .font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.vertical, 8)
        } else if destinations.isEmpty {
            Text("This track’s source playlist is excluded.").font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.vertical, 8)
        } else if filteredDestinations.isEmpty {
            Text("No playlists match your search.").font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.vertical, 8)
        } else {
            PlaylistDestinationList(playlists: filteredDestinations, selectedIDs: $selectedIDs,
                savedIDs: Set(filteredDestinations.filter { isSaved(in: $0.id) }.map(\.id)),
                unavailableIDs: Set(filteredDestinations.filter { !library.canSaveVideo(to: $0.id) }.map(\.id)), saving: saving)
                .frame(maxHeight: 240)
        }
        if saving { progress("Adding to selected playlists…") }
        else if library.busy { progress("Updating YouTube library…") }
    }

    private func isSaved(in playlistID: String) -> Bool {
        library.containsSavedVideo(video.id, in: playlistID)
            || outcomes.contains { $0.playlistID == playlistID && isConfirmed($0.result) }
    }
    private func isConfirmed(_ result: PlaylistSaveResult) -> Bool {
        switch result { case .added, .alreadyInPlaylist, .savedRefreshUnavailable: return true; default: return false }
    }
    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).font(.system(size: 11)).foregroundStyle(AppDesign.muted) }
    }
    @ViewBuilder private func resultView(_ outcome: PlaylistSaveOutcome) -> some View {
        let title = destinationTitles[outcome.playlistID] ?? "Playlist"
        switch outcome.result {
        case .added: statusRow("\(title): saved.", symbol: "checkmark.circle.fill", color: AppDesign.green)
        case .alreadyInPlaylist: statusRow("\(title): already saved.", symbol: "checkmark.circle", color: AppDesign.green)
        case let .unavailable(message), let .failed(message): statusRow("\(title): \(message)", symbol: "exclamationmark.circle.fill", color: AppDesign.Status.error)
        case .busy: statusRow("\(title): another YouTube action is in progress.", symbol: "hourglass", color: AppDesign.muted)
        case let .uncertain(message), let .savedRefreshUnavailable(message): statusRow("\(title): \(message)", symbol: "exclamationmark.triangle.fill", color: AppDesign.Status.warning)
        }
    }
    private func statusRow(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 10)).foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
    private func saveSelected() {
        guard !saving, let videoID = invocationVideoID, videoID == video.id, let scope = invocationScope, !pendingIDs.isEmpty else { return }
        let track = video, ids = pendingIDs
        for playlist in destinations where ids.contains(playlist.id) { destinationTitles[playlist.id] = playlist.title }
        saving = true
        Task { @MainActor in
            let results = await library.saveVideo(track, toPlaylists: ids, accountScope: scope)
            if invocationVideoID == videoID, invocationScope == scope {
                outcomes.removeAll { ids.contains($0.playlistID) }
                outcomes.append(contentsOf: results)
                for outcome in results where isConfirmed(outcome.result) { selectedIDs.remove(outcome.playlistID) }
            }
            saving = false
        }
    }
    private func invalidatePopover() {
        suppressFocusRestore = presented; presented = false; invocationVideoID = nil; invocationScope = nil
        outcomes = []; selectedIDs = []; favoriteResult = nil; destinationTitles = [:]
    }
}
