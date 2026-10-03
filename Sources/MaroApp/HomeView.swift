import SwiftUI

/// Ticket #3 owns discovery and the editorial Home content.
struct HomeView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your listening starts here").font(.system(size: 34, weight: .bold))
                Text("Open a playlist or search YouTube for a song, artist, or video.").foregroundStyle(AppDesign.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    LibraryRow(title: "Favorites", subtitle: "Saved on this Mac", favorites: true) { app.showFavorites() }
                        .background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 6))
                    ForEach(app.library.playlists.prefix(7)) { playlist in
                        LibraryRow(title: playlist.title, subtitle: "\(playlist.count) videos", url: playlist.thumbnailURL) { app.openPlaylist(playlist) }
                            .background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
