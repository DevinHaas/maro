import Foundation
import MaroCore

/// A modal captures the occurrence and playlist identity, never its transient row index.
struct PlaylistActionContext: Identifiable {
    let id = UUID()
    let playlist: YouTubePlaylist
    var item: YouTubePlaylistItem?
}
