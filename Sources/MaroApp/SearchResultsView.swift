import MaroCore
import SwiftUI

enum SearchTrackColumns {
    static let gap: CGFloat = 16
    static let inset: CGFloat = 12
    static let play: CGFloat = 38
    static let artwork: CGFloat = 52
    static let duration: CGFloat = 64
    static let favorite: CGFloat = 38
    static let actions: CGFloat = 30
}

struct SearchResultsView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var player: PlayerPresentation
    @State private var bottomVisible = false
    @State private var bottomRequestCount: Int?
    init(app: ApplicationModel) { self.app = app; player = app.player }
    var body: some View {
        GeometryReader { viewport in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(app.searchState.query.isEmpty ? "Search" : "Results for “\(app.searchState.query)”").font(.system(size: 28, weight: .bold))
                if let error = app.searchState.error {
                    Text(error).foregroundStyle(AppDesign.Status.error)
                    Button("Retry search") { app.retrySearch() }.disabled(player.snapshot.sourceNeedsUpdate)
                        .vimTarget(enabled: !player.snapshot.sourceNeedsUpdate) { app.retrySearch() }
                }
                if let error = app.actionError { Text(error).foregroundStyle(AppDesign.Status.error) }
                if !app.searchState.isSearching && app.searchState.error == nil && app.searchState.results.isEmpty {
                    Text(app.searchState.query.isEmpty ? "Search YouTube to find your next video." : "No videos found. Try another search.").foregroundStyle(AppDesign.muted)
                }
                HStack(spacing: SearchTrackColumns.gap) {
                    Color.clear.frame(width: SearchTrackColumns.play)
                    HStack(spacing: SearchTrackColumns.gap) {
                        Color.clear.frame(width: SearchTrackColumns.artwork)
                        Text("TITLE").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("DURATION").frame(width: SearchTrackColumns.duration, alignment: .trailing)
                    Color.clear.frame(width: SearchTrackColumns.favorite)
                    Color.clear.frame(width: SearchTrackColumns.actions)
                }.font(.system(size: 10, weight: .semibold)).foregroundStyle(AppDesign.muted)
                    .padding(.horizontal, SearchTrackColumns.inset)
                Divider().overlay(AppDesign.Border.decorative).accessibilityHidden(true)
                LazyVStack(spacing: 6) {
                    ForEach(app.searchState.results, id: \.id) { video in
                        SearchVideoRow(app: app, player: player, video: video)
                    }
                }
                if app.searchState.isSearching {
                    TrackListSkeleton(label: "Loading search results", identifier: "search-results-loading")
                }
                if app.searchState.isLoadingMore {
                    TrackListSkeleton(count: 3, label: "Loading more tracks", identifier: "search-more-loading")
                } else if let error = app.searchState.loadMoreError {
                    Text(error).foregroundStyle(AppDesign.Status.error)
                    Button("Retry loading more") { app.retryMoreResults() }.disabled(player.snapshot.sourceNeedsUpdate)
                        .vimTarget(enabled: !player.snapshot.sourceNeedsUpdate) { app.retryMoreResults() }
                } else if !app.searchState.isSearching && !app.searchState.results.isEmpty && !app.searchState.hasMore {
                    Text("All results loaded").font(.caption).foregroundStyle(AppDesign.muted).frame(maxWidth: .infinity)
                }
                Color.clear.frame(height: 1)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: SearchBottomPreference.self, value: geometry.frame(in: .named("searchScroll")).minY)
                    }).accessibilityHidden(true)
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).vimRegion("search", scrolls: true)
        }
        .subtleScrollbars()
        .coordinateSpace(name: "searchScroll")
        .onPreferenceChange(SearchBottomPreference.self) { y in
                let visible = y >= 0 && y <= viewport.size.height
                if !visible { bottomRequestCount = nil }
                bottomVisible = visible
                loadVisiblePageIfNeeded()
        }
        .onChange(of: app.searchState.query) { _ in bottomRequestCount = nil; bottomVisible = false }
        }
    }

    private func loadVisiblePageIfNeeded() {
        guard bottomVisible, !app.searchState.isSearching, !app.searchState.isLoadingMore,
              app.searchState.loadMoreError == nil, app.searchState.hasMore,
              bottomRequestCount != app.searchState.results.count else { return }
        bottomRequestCount = app.searchState.results.count
        app.revealMore()
    }
}

private struct SearchBottomPreference: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
                if let error = app.actionError { Text(error).foregroundStyle(AppDesign.Status.error) }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).vimRegion("favorites", scrolls: true)
        }.subtleScrollbars()
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
        HStack(spacing: SearchTrackColumns.gap) {
            AppIconButton(title: "Play \(video.title)", symbol: "play.fill", enabled: !player.snapshot.sourceNeedsUpdate,
                          prominent: hovered) { app.play(video) }.opacity(hovered || current || player.snapshot.sourceNeedsUpdate ? 1 : 0.6)
            Button { app.play(video) } label: {
                HStack(spacing: SearchTrackColumns.gap) {
                    LibraryArtwork(url: video.thumbnailURL, localPath: player.snapshot.localThumbnailPaths?[video.id], symbol: "music.note")
                        .frame(width: SearchTrackColumns.artwork, height: SearchTrackColumns.artwork).clipShape(RoundedRectangle(cornerRadius: 6))
                        .fixedSize()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title).font(.system(size: 14, weight: .medium)).foregroundStyle(current ? AppDesign.green : AppDesign.Text.primary).lineLimit(1)
                        Text(video.creator).font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                .disabled(player.snapshot.sourceNeedsUpdate).vimTarget(enabled: !player.snapshot.sourceNeedsUpdate) { app.play(video) }
                .accessibilityLabel("Play \(video.title) by \(video.creator)")
            Text(duration).font(.system(size: 12)).monospacedDigit().foregroundStyle(AppDesign.muted)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: SearchTrackColumns.duration, alignment: .trailing)
            AppIconButton(title: saved ? "Remove \(video.title) from Favorites" : "Save \(video.title) to Favorites", symbol: saved ? "heart.fill" : "heart") { app.toggleFavorite(video) }
            Menu {
                Button("Play") { app.play(video) }.disabled(player.snapshot.sourceNeedsUpdate)
                Button(saved ? "Remove from Favorites" : "Save to Favorites") { app.toggleFavorite(video) }
                Button("Add to playlist…") { app.offerAdd(video) }
            } label: { Text("⋮").font(.system(size: 22, weight: .semibold)).frame(width: SearchTrackColumns.actions, height: 38) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Actions for \(video.title)").accessibilityLabel("Actions for \(video.title)")
        }.padding(.horizontal, SearchTrackColumns.inset).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? AppDesign.Surface.hover : current ? AppDesign.Surface.selected : .clear))
            .onHover { hovered = $0 }
    }
}
