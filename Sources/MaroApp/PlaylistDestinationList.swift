import SwiftUI
import MaroCore

/// Shared by the live picker and isolated native rendering fixtures.
struct PlaylistDestinationList: View {
    let playlists: [YouTubePlaylist]
    @Binding var selectedIDs: Set<String>
    var savedIDs: Set<String> = []
    var unavailableIDs: Set<String> = []
    var saving = false
    var localArtworkPath: String? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                ForEach(playlists) { playlist in
                    Toggle(isOn: Binding(get: { savedIDs.contains(playlist.id) || selectedIDs.contains(playlist.id) }, set: { chosen in
                        if chosen { selectedIDs.insert(playlist.id) } else { selectedIDs.remove(playlist.id) }
                    })) {
                        HStack(spacing: 9) {
                            LibraryArtwork(url: playlist.thumbnailURL, localPath: localArtworkPath, symbol: "music.note.list")
                                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                Text(savedIDs.contains(playlist.id) ? "Saved in this playlist" : "\(playlist.count) videos")
                                    .font(.system(size: 10)).foregroundStyle(AppDesign.muted)
                            }
                            Spacer(minLength: 0)
                        }
                    }.toggleStyle(.checkbox).padding(.horizontal, 7).padding(.vertical, 5)
                        .disabled(saving || savedIDs.contains(playlist.id) || unavailableIDs.contains(playlist.id))
                        .accessibilityLabel("\(playlist.title), \(savedIDs.contains(playlist.id) ? "already saved" : "select destination")")
                }
            }
        }.subtleScrollbars().accessibilityLabel("Available playlists")
    }
}
