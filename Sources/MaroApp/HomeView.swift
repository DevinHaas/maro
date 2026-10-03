import SwiftUI
import MaroCore

struct HomeView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject private var home: HomeRecommendations
    @ObservedObject private var library: PlaylistLibrary
    init(app: ApplicationModel) { self.app = app; home = app.home; library = app.library }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                feature
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 218), spacing: 10)], spacing: 10) {
                    shortcut(title: "Favorites", favorites: true, playEnabled: !app.player.snapshot.favorites.isEmpty,
                        open: { app.showFavorites() }, play: { app.playFavorites() })
                    ForEach(library.playlists.prefix(7)) { playlist in
                        shortcut(title: playlist.title, url: playlist.thumbnailURL, playEnabled: playlist.count > 0 && !library.busy,
                            open: { app.openPlaylist(playlist) }, play: { library.play(playlist) })
                    }
                }
                if home.isLoading {
                    HStack(spacing: 10) { ProgressView().controlSize(.small); Text("Finding suggestions…").foregroundStyle(AppDesign.muted) }
                        .font(.system(size: 12)).accessibilityElement(children: .combine)
                }
                if let error = home.error {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(home.sections.contains { !$0.videos.isEmpty } ? "Suggestions may be outdated" : "Suggestions are unavailable").font(.system(size: 14, weight: .semibold))
                            Text(error).font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(3)
                        }
                        Spacer(minLength: 0)
                        Button("Retry") { home.retry() }.disabled(home.isLoading)
                    }.padding(16).background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                ForEach(home.sections) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(section.reason).font(.system(size: 12)).foregroundStyle(AppDesign.muted)
                                Text(section.title).font(.system(size: 23, weight: .bold)).lineLimit(1)
                            }
                            Spacer()
                            if section.isOutdated { Text("Outdated").font(.system(size: 11)).foregroundStyle(.orange) }
                            Button("Explore") { app.submitSearch(section.query) }.buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppDesign.muted)
                                .accessibilityLabel("Search \(section.query)")
                        }
                        if !section.videos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 14) {
                                    ForEach(section.videos, id: \.id) { video in HomeVideoCard(app: app, video: video) }
                                }.padding(.bottom, 4)
                            }
                        } else if !home.isLoading {
                            Text(home.error == nil ? "No suggestions found. Try a search or another theme." : "Try again when you’re connected.")
                                .font(.system(size: 13)).foregroundStyle(AppDesign.muted).padding(.vertical, 12)
                        }
                    }
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var feature: some View {
        GeometryReader { geometry in
            let playlist = library.playlists.first
            HStack(spacing: 0) {
                LibraryArtwork(url: playlist?.thumbnailURL ?? home.sections.first?.videos.first?.thumbnailURL, symbol: "music.note")
                    .frame(width: max(160, geometry.size.width * 0.43), height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 14) {
                    Text(playlist == nil ? "DISCOVER WITH MARO" : "FROM YOUR LIBRARY")
                        .font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(AppDesign.muted)
                    Text(playlist?.title ?? "Find your next favorite")
                        .font(.system(size: geometry.size.width < 650 ? 26 : 34, weight: .bold)).lineLimit(3)
                    Text(playlist?.description ?? (playlist == nil ? "Explore \(home.sections.first?.title.lowercased() ?? "jazz") and start listening." : "\(playlist!.count) videos · Saved in your YouTube library"))
                        .font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(3)
                    Spacer(minLength: 0)
                    Button {
                        if let playlist { app.openPlaylist(playlist) }
                        else { app.submitSearch(home.suggestedQueries.first ?? "jazz") }
                    } label: {
                        Text(playlist == nil ? "Explore suggestions" : "Open playlist")
                            .font(.system(size: 13, weight: .bold)).padding(.horizontal, 18).padding(.vertical, 11)
                            .foregroundStyle(.black).background(AppDesign.green).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.background(LinearGradient(colors: [Color(red: 0.18, green: 0.28, blue: 0.22), AppDesign.surface], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }.frame(height: 260)
    }

    private func shortcut(title: String, url: URL? = nil, favorites: Bool = false, playEnabled: Bool,
                          open: @escaping () -> Void, play: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: open) {
                HStack(spacing: 12) {
                    LibraryArtwork(url: url, favorites: favorites).frame(width: 62, height: 62)
                    Text(title).font(.system(size: 13, weight: .bold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Open \(title)")
            AppIconButton(title: "Play \(title) in saved order", symbol: "play.fill", enabled: playEnabled, prominent: true, action: play)
                .padding(.horizontal, 8)
        }.background(AppDesign.raised).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct HomeVideoCard: View {
    @ObservedObject var app: ApplicationModel
    let video: VideoSummary
    @State private var hovered = false
    private var saved: Bool { app.player.snapshot.favorites.contains { $0.id == video.id } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { app.play(video) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    LibraryArtwork(url: video.thumbnailURL, localPath: app.player.snapshot.localThumbnailPaths?[video.id], symbol: "play.rectangle")
                        .frame(width: 176, height: 176)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "play.fill").font(.system(size: 20))
                                .foregroundStyle(.black).frame(width: 44, height: 44)
                                .background(AppDesign.green).clipShape(Circle()).padding(10).opacity(hovered ? 1 : 0)
                        }
                    Text(video.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                        .frame(height: 36, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                    Text(video.creator.isEmpty ? "Creator unavailable" : video.creator)
                        .font(.system(size: 12)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Play \(video.title) by \(video.creator)")
            Menu {
                Button(saved ? "Remove from Favorites" : "Add to Favorites") { app.toggleFavorite(video) }
                Button("Add to playlist…") { app.offerAdd(video) }
            } label: {
                Label(saved ? "Saved" : "Save", systemImage: saved ? "heart.fill" : "plus.circle")
                    .font(.system(size: 12)).foregroundStyle(saved ? AppDesign.green : AppDesign.muted)
            }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Save actions for \(video.title)")
        }.padding(10).frame(width: 196, alignment: .leading)
            .background(hovered ? AppDesign.raised : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovered = $0 }
    }
}
