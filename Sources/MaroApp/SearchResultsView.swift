import MaroCore
import SwiftUI

struct SearchResultsView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var player: PlayerPresentation
    init(app: ApplicationModel) { self.app = app; player = app.player }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(app.searchState.query.isEmpty ? "Search" : "Results for “\(app.searchState.query)”").font(.system(size: 28, weight: .bold))
                if app.searchState.isSearching { ProgressView("Searching YouTube…") }
                if let error = app.searchState.error {
                    Text(error).foregroundStyle(.orange)
                    Button("Retry search") { app.retrySearch() }.disabled(player.snapshot.sourceNeedsUpdate)
                }
                if let error = app.actionError { Text(error).foregroundStyle(.orange) }
                if !app.searchState.isSearching && app.searchState.error == nil && app.searchState.results.isEmpty {
                    Text(app.searchState.query.isEmpty ? "Search YouTube to find your next video." : "No videos found. Try another search.").foregroundStyle(AppDesign.muted)
                }
                HStack {
                    Text("TITLE"); Spacer(); Text("DURATION").padding(.trailing, 106)
                }.font(.system(size: 10, weight: .semibold)).foregroundStyle(AppDesign.muted).padding(.horizontal, 12)
                Divider()
                LazyVStack(spacing: 4) {
                    ForEach(app.searchState.results, id: \.id) { video in
                        SearchVideoRow(app: app, player: player, video: video)
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
                    SearchVideoRow(app: app, player: player, video: video)
                }
                if let error = app.actionError { Text(error).foregroundStyle(.orange) }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SearchVideoRow: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var player: PlayerPresentation
    let video: VideoSummary
    @State private var hovered = false
    private var current: Bool { player.snapshot.loadedVideo?.video.id == video.id }
    private var saved: Bool { player.snapshot.favorites.contains { $0.id == video.id } }
    private var duration: String {
        guard let duration = video.durationSeconds else { return "—" }
        let seconds = Int(duration.rounded(.down))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(title: "Play \(video.title)", symbol: "play.fill", enabled: !player.snapshot.sourceNeedsUpdate,
                          prominent: hovered) { app.play(video) }.opacity(hovered || current ? 1 : 0.6)
            Button { app.play(video) } label: {
                HStack(spacing: 12) {
                    LibraryArtwork(url: video.thumbnailURL, localPath: player.snapshot.localThumbnailPaths?[video.id], symbol: "music.note").frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title).font(.system(size: 14, weight: .medium)).foregroundStyle(current ? AppDesign.green : .white).lineLimit(1)
                        Text(video.creator).font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(player.snapshot.sourceNeedsUpdate).accessibilityLabel("Play \(video.title) by \(video.creator)")
            Text(duration).font(.system(size: 12)).monospacedDigit().foregroundStyle(AppDesign.muted).frame(width: 60, alignment: .trailing)
            AppIconButton(title: saved ? "Remove \(video.title) from Favorites" : "Save \(video.title) to Favorites", symbol: saved ? "heart.fill" : "heart") { app.toggleFavorite(video) }
            Menu {
                Button("Play") { app.play(video) }.disabled(player.snapshot.sourceNeedsUpdate)
                Button(saved ? "Remove from Favorites" : "Save to Favorites") { app.toggleFavorite(video) }
                Button("Add to playlist…") { app.offerAdd(video) }
            } label: { Image(systemName: "ellipsis").frame(width: 30, height: 38) }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions for \(video.title)")
        }.padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? AppDesign.raised : current ? AppDesign.green.opacity(0.05) : .clear))
            .onHover { hovered = $0 }
    }
}
