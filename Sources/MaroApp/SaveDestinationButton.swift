import SwiftUI
import MaroCore

/// A per-track save action. It never changes playback, route, or queue state.
struct SaveDestinationButton: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var library: PlaylistLibrary
    let video: VideoSummary
    var sourcePlaylistID: String? = nil
    @State private var presented = false
    @State private var hovered = false
    @State private var saving = false
    @State private var savingDestinationID: String?
    @State private var result: PlaylistSaveResult?
    @State private var favoriteResult: String?
    @State private var resultDestinationTitle: String?
    @State private var invocationVideoID: String?
    @State private var invocationScope: String?
    @State private var restoreFocus = false
    @FocusState private var buttonFocused: Bool

    init(app: ApplicationModel, video: VideoSummary, sourcePlaylistID: String? = nil) {
        self.app = app
        self.video = video
        self.sourcePlaylistID = sourcePlaylistID
        library = app.library
    }

    private var isFavorite: Bool { app.player.snapshot.favorites.contains { $0.id == video.id } }
    private var canAddFavorite: Bool { isFavorite || app.player.snapshot.favorites.count < 20 }
    private var visible: Bool { hovered || buttonFocused || presented }
    private var destinations: [YouTubePlaylist] {
        library.playlists.filter { $0.id != sourcePlaylistID }
    }

    var body: some View {
        Button {
            invocationVideoID = video.id
            invocationScope = library.saveAccountScope
            if !saving { result = nil; resultDestinationTitle = nil }
            favoriteResult = nil
            presented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(buttonFocused ? AppDesign.Text.primary : AppDesign.green)
                .frame(width: 34, height: 34)
                .background(visible ? AppDesign.Surface.hover : Color.clear, in: Circle())
                .overlay(Circle().strokeBorder(buttonFocused ? AppDesign.Border.focus : Color.clear, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focused($buttonFocused)
        .opacity(visible ? 1 : 0)
        .accessibilityHidden(false)
        .accessibilityLabel("Save \(video.title)")
        .accessibilityHint("Choose Favorites or one of your YouTube playlists")
        .onHover { hovered = $0 }
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            destinationPopover
                .frame(width: 310)
                .background(AppDesign.Surface.raised)
                .preferredColorScheme(.dark)
                .tint(AppDesign.green)
                .onExitCommand {
                    restoreFocus = true
                    presented = false
                }
        }
        .onChange(of: presented) { open in
            if !open && restoreFocus {
                restoreFocus = false
                DispatchQueue.main.async { buttonFocused = true }
            }
        }
        .onChange(of: video.id) { _ in invalidatePopover() }
        .onChange(of: sourcePlaylistID) { _ in invalidatePopover() }
        .onChange(of: app.route) { _ in invalidatePopover() }
        .onChange(of: library.saveScopeID) { _ in invalidatePopover() }
    }

    private var destinationPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LibraryArtwork(url: video.thumbnailURL, localPath: app.player.snapshot.localThumbnailPaths?[video.id], symbol: "music.note")
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save track").font(.system(size: 14, weight: .bold))
                    Text(video.title).font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { restoreFocus = true; presented = false } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                    .buttonStyle(.plain).foregroundStyle(AppDesign.muted).accessibilityLabel("Close save menu")
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
            }
            .buttonStyle(.plain)
            .disabled(!canAddFavorite)
            .accessibilityHint(!canAddFavorite ? "Favorites are full. Remove one before adding another." : "")
            if !canAddFavorite {
                Text("Favorites are full (20 of 20). Remove one before adding another.")
                    .font(.system(size: 10)).foregroundStyle(AppDesign.Status.warning)
            }
            if let favoriteResult { statusRow(favoriteResult, symbol: "checkmark.circle.fill", color: AppDesign.green) }

            Divider().overlay(AppDesign.Border.decorative)
            HStack {
                Text("YOUR PLAYLISTS").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(AppDesign.muted)
                Spacer()
                if library.stale { Text("May be outdated").font(.system(size: 9)).foregroundStyle(AppDesign.Status.warning) }
            }
            playlistContent
            if let result { resultView(result) }
        }
        .padding(14)
        .frame(maxHeight: 510)
        .accessibilityElement(children: .contain)
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
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Loading playlists…").font(.system(size: 11)).foregroundStyle(AppDesign.muted) }
                .padding(.vertical, 8)
        } else if library.playlists.isEmpty && library.canRetry {
            VStack(alignment: .leading, spacing: 8) {
                Text("Could not load your YouTube playlists.").font(.system(size: 11)).foregroundStyle(AppDesign.Status.warning)
                Button("Retry refresh") { library.retryLast() }.disabled(library.busy)
            }.padding(.vertical, 6)
        } else if library.playlists.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(library.stale ? "Your playlist list may be outdated." : "No playlists found for this account.")
                    .font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                HStack {
                    Button("Create private playlist…") { library.create() }.disabled(library.busy)
                    if library.canRetry { Button("Refresh") { library.retryLast() }.disabled(library.busy) }
                }
            }.padding(.vertical, 6)
        } else if destinations.isEmpty {
            Text("This track’s source playlist is excluded.").font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.vertical, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(destinations) { playlist in
                        Button { save(to: playlist) } label: {
                            HStack(spacing: 9) {
                                LibraryArtwork(url: playlist.thumbnailURL, symbol: "music.note.list").frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                    Text("\(playlist.count) videos").font(.system(size: 9)).foregroundStyle(AppDesign.muted)
                                }
                                Spacer(minLength: 0)
                                if saving && savingDestinationID == playlist.id { ProgressView().controlSize(.small) }
                                else { Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).foregroundStyle(AppDesign.green) }
                            }.padding(.horizontal, 7).padding(.vertical, 5).contentShape(Rectangle())
                                .background(AppDesign.Surface.raised, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain)
                            .disabled(saving || library.busy || !library.connected || !library.playlists.contains(where: { $0.id == playlist.id }))
                            .accessibilityLabel("Add \(video.title) to \(playlist.title)")
                    }
                }
            }
            .frame(maxHeight: 280)
            .accessibilityLabel("Available playlists")
        }
        if library.busy && !saving { HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Updating YouTube library…").font(.system(size: 10)).foregroundStyle(AppDesign.muted) } }
    }

    @ViewBuilder private func resultView(_ result: PlaylistSaveResult) -> some View {
        switch result {
        case .added:
            statusRow("Saved to \(resultDestinationTitle ?? "playlist").", symbol: "checkmark.circle.fill", color: AppDesign.green)
        case .alreadyInPlaylist:
            statusRow("Already in \(resultDestinationTitle ?? "this playlist").", symbol: "checkmark.circle", color: AppDesign.Status.warning)
        case let .unavailable(message), let .failed(message):
            statusRow(message, symbol: "exclamationmark.circle.fill", color: AppDesign.Status.error)
        case .busy:
            statusRow("Another YouTube action is in progress. Try again when it finishes.", symbol: "hourglass", color: AppDesign.muted)
        case let .uncertain(message), let .savedRefreshUnavailable(message):
            VStack(alignment: .leading, spacing: 6) {
                statusRow(message, symbol: "exclamationmark.triangle.fill", color: AppDesign.Status.warning)
                if library.canRetry { Button("Refresh before another edit") { library.retryLast() }.disabled(library.busy) }
            }
        }
    }

    private func statusRow(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 10)).foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }

    private func save(to playlist: YouTubePlaylist) {
        guard !saving, let videoID = invocationVideoID, videoID == video.id,
              let scope = invocationScope else { return }
        saving = true
        savingDestinationID = playlist.id
        result = nil
        resultDestinationTitle = playlist.title
        Task { @MainActor in
            let outcome = await library.saveVideo(video, to: playlist.id, accountScope: scope)
            if invocationVideoID == videoID, invocationScope == scope { result = outcome }
            saving = false
            savingDestinationID = nil
        }
    }

    private func invalidatePopover() {
        presented = false
        invocationVideoID = nil
        invocationScope = nil
        result = nil
        favoriteResult = nil
        resultDestinationTitle = nil
    }
}
