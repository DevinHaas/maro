import MaroCore
import SwiftUI

/// Ticket #4 owns modern result rows and preview selection behavior.
struct SearchResultsView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(app.searchState.query.isEmpty ? "Search" : "Results for “\(app.searchState.query)”").font(.system(size: 28, weight: .bold))
                if app.searchState.isSearching { ProgressView("Searching YouTube…") }
                if let error = app.searchState.error { Text(error).foregroundStyle(.orange) }
                if let error = app.actionError { Text(error).foregroundStyle(.orange) }
                if !app.searchState.isSearching && app.searchState.results.isEmpty { Text("No videos found. Try another search.").foregroundStyle(AppDesign.muted) }
                LazyVStack(spacing: 4) {
                    ForEach(app.searchState.results, id: \.id) { video in
                        HStack {
                            LibraryRow(title: video.title, subtitle: video.creator, url: video.thumbnailURL) { app.play(video) }
                            Button { app.offerAdd(video) } label: { Image(systemName: "text.badge.plus") }.buttonStyle(.plain).accessibilityLabel("Add \(video.title) to playlist")
                        }
                    }
                }
                if app.searchState.hasMore { Button("Load 5 more") { app.revealMore() }.disabled(app.searchState.isSearching) }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var player: PlayerPresentation
    init(app: ApplicationModel) { self.app = app; player = app.player }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    LibraryArtwork(favorites: true).frame(width: 160, height: 160)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SAVED ON THIS MAC").font(.caption.bold()).foregroundStyle(AppDesign.muted)
                        Text("Favorites").font(.system(size: 44, weight: .heavy))
                        Text("\(player.snapshot.favorites.count) videos").foregroundStyle(AppDesign.muted)
                    }
                }
                if player.snapshot.favorites.isEmpty { Text("Save a video with the heart in the player to find it here.").foregroundStyle(AppDesign.muted) }
                ForEach(player.snapshot.favorites, id: \.id) { video in
                    HStack {
                        LibraryRow(title: video.title, subtitle: video.creator, url: video.thumbnailURL) { app.play(video) }
                        AppIconButton(title: "Remove \(video.title) from Favorites", symbol: "heart.fill") { app.perform(.favoriteToggle, videoID: video.id) }
                        AppIconButton(title: "Add \(video.title) to playlist", symbol: "text.badge.plus") { app.offerAdd(video) }
                    }
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
