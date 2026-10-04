import MaroCore
import SwiftUI

struct PlaylistActionsSheet: View {
    let context: PlaylistActionContext
    @ObservedObject var library: PlaylistLibrary
    @ObservedObject var player: PlayerPresentation
    @State private var name = ""
    @State private var destination = ""
    @State private var position = 1
    @State private var confirmsDeletion = false
    @FocusState private var cancelFocused: Bool
    private var isFavorite: Bool { context.item?.video.map { video in player.snapshot.favorites.contains { $0.id == video.id } } ?? false }
    private var destinations: [YouTubePlaylist] { library.playlists.filter { $0.id != context.playlist.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                LibraryArtwork(url: context.item?.video?.thumbnailURL ?? context.playlist.thumbnailURL,
                    localPath: context.item?.video.flatMap { player.snapshot.localThumbnailPaths?[$0.id] }).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.item?.title ?? context.playlist.title).font(.system(size: 20, weight: .bold)).lineLimit(2)
                    Text(context.item == nil ? "Playlist actions" : context.playlist.title).font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }
            }
            Divider()
            if let item = context.item { rowActions(item) } else { playlistActions }
            Text(library.status).font(.system(size: 11)).foregroundStyle(AppDesign.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel") { library.dismissActions() }.keyboardShortcut(.cancelAction).focused($cancelFocused)
                Spacer()
                if library.busy { ProgressView().controlSize(.small) }
            }
        }.foregroundStyle(AppDesign.Text.primary).padding(24).frame(width: 460)
            .background(AppDesign.Surface.raised).tidalBorder(cornerRadius: 0).preferredColorScheme(.dark).tint(AppDesign.Accent.primary)
            .onAppear {
                name = context.playlist.title; destination = destinations.first?.id ?? ""
                position = (library.items.firstIndex { $0.id == context.item?.id } ?? 0) + 1
                cancelFocused = true
            }
    }

    @ViewBuilder private func rowActions(_ item: YouTubePlaylistItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { library.play(occurrenceID: item.id, in: context.playlist.id); library.dismissActions() } label: {
                Label("Play from here", systemImage: "play.fill").frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderedProminent).foregroundStyle(AppDesign.Text.onAccent).disabled(item.video == nil || library.busy)
            if let video = item.video {
                Button { library.toggleFavorite(video) } label: {
                    Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.fill" : "heart")
                }.disabled(!isFavorite && player.snapshot.favorites.count >= 20)
                Text(player.snapshot.favorites.count >= 20 && !isFavorite
                    ? "Favorites are full (20 of 20). Remove one before adding another."
                    : "\(player.snapshot.favorites.count) of 20 Favorites saved on this Mac.")
                    .font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                if !destinations.isEmpty {
                    HStack {
                        Picker("Add to playlist", selection: $destination) { ForEach(destinations) { Text($0.title).tag($0.id) } }
                        Button("Add") { library.add(video, to: destination) }.disabled(destination.isEmpty || library.busy)
                    }
                } else { Text("Create another playlist from the library to add this video there.").font(.system(size: 11)).foregroundStyle(AppDesign.muted) }
            } else { Text("This video is unavailable. It will be skipped during playback; you can still remove this occurrence.").font(.system(size: 12)).foregroundStyle(AppDesign.muted) }
            HStack {
                Stepper("Move to position \(position)", value: $position, in: 1...max(1, library.items.count))
                Button("Move") { library.move(occurrenceID: item.id, in: context.playlist.id, to: position - 1) }
                    .disabled(item.resourceVideoID == nil || !library.canReorder || library.selected?.id != context.playlist.id)
            }.disabled(item.resourceVideoID == nil || !library.canReorder)
            if library.canRetry || library.reorderState == .unconfirmed {
                Button(library.reorderState == .rejected ? "Retry move" : "Refresh YouTube") { library.retryLast() }.disabled(library.busy)
            }
            Button("Remove this occurrence", role: .destructive) {
                library.remove(occurrenceID: item.id, from: context.playlist.id); library.dismissActions()
            }.disabled(library.busy)
            Text("Removal changes this playlist only. It does not delete the video from YouTube or change the captured playback queue.")
                .font(.system(size: 11)).foregroundStyle(AppDesign.muted)
        }
    }

    private var playlistActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Playlist name", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Playlist name")
            Button("Save name") { library.rename(playlistID: context.playlist.id, title: name); library.dismissActions() }
                .disabled(library.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 150)
            Divider()
            if confirmsDeletion {
                Text("Delete “\(context.playlist.title)”? This permanently deletes the playlist from YouTube. The videos themselves are not deleted.").font(.system(size: 12))
                HStack {
                    Button("Keep playlist") { confirmsDeletion = false; cancelFocused = true }
                    Spacer()
                    Button("Delete playlist", role: .destructive) { library.delete(context.playlist); library.dismissActions() }.disabled(library.busy)
                }
            } else { Button("Delete playlist…", role: .destructive) { confirmsDeletion = true; cancelFocused = true }.disabled(library.busy) }
        }
    }
}
