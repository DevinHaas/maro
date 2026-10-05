import AppKit
import MaroCore
import SwiftUI

/// The header and rows use the same fixed columns around their flexible title cell.
enum PlaylistTrackColumns {
    static let gap: CGFloat = 18
    static let inset: CGFloat = 12
    static let position: CGFloat = 24
    static let artwork: CGFloat = 44
    static let date: CGFloat = 100
    static let duration: CGFloat = 48
    static let actions: CGFloat = 82
    static let handle: CGFloat = 16
}

struct PlaylistDetailView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View { PlaylistDetailContent(app: app, library: app.library, player: app.player) }
}

private struct PlaylistDetailContent: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    @ObservedObject var player: PlayerPresentation
    @State private var artworkColor = AppDesign.Surface.raised
    @State private var invokingControl: String?
    @State private var searchQuery = ""
    @FocusState private var focusedControl: String?
    @FocusState private var playFocused: Bool
    @State private var playHovered = false
    private var hasActiveSearch: Bool { !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var filteredItems: [PlaylistSearchResult] { PlaylistSearchProjection(items: library.items, query: searchQuery) }

    var body: some View {
        GeometryReader { viewport in
            // Read the viewport directly so metadata visibility is correct on the first layout.
            let tableWidth = max(0, viewport.size.width - 48)
            content(showsDates: tableWidth >= 600 && library.items.contains { $0.addedAt != nil },
                showsDurations: tableWidth >= 520 && library.items.contains { $0.video?.durationSeconds != nil })
        }
    }

    private func content(showsDates: Bool, showsDurations: Bool) -> some View {
        Group {
            if let playlist = library.selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlaylistCoverHeader(playlist: playlist, loadedCount: library.busy ? nil : library.items.count,
                            fallbackURL: library.items.compactMap { item in
                                guard let video = item.video else { return nil as URL? }
                                return player.snapshot.localThumbnailPaths?[video.id].map { URL(fileURLWithPath: $0) } ?? video.thumbnailURL
                            }.first, color: $artworkColor,
                            renameEnabled: library.canReorder, rename: { library.rename() })
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 18) {
                                Button { library.play() } label: {
                                    Image(systemName: "play.fill").font(.system(size: 25))
                                        .frame(width: 62, height: 62)
                                }.buttonStyle(PlaylistPlayButtonStyle(hovered: playHovered)).disabled(library.items.isEmpty || library.busy)
                                    .opacity(library.items.isEmpty || library.busy ? 0.4 : 1)
                                    .onHover { playHovered = $0 }.focused($playFocused)
                                    .overlay {
                                        Circle().inset(by: 2).strokeBorder(playFocused ? AppDesign.Border.focus : .clear, lineWidth: 2)
                                            .allowsHitTesting(false).accessibilityHidden(true)
                                    }
                                    .accessibilityLabel("Play \(playlist.title) in saved order")
                                AppIconButton(title: "Remove playlist \(playlist.title)", symbol: "xmark", enabled: library.canReorder) {
                                    library.confirmDelete()
                                }.background(Circle().fill(AppDesign.Surface.raised))
                                    .focusable().focused($focusedControl, equals: "playlist-delete")
                                    .accessibilityIdentifier("playlist-delete")
                                    .tidalBorder(cornerRadius: 19, focused: focusedControl == "playlist-delete", visible: focusedControl == "playlist-delete")
                                Spacer(minLength: 8)
                                if library.busy { ProgressView().controlSize(.small) }
                                Text("Saved order").font(.system(size: 12)).foregroundStyle(AppDesign.muted)
                                Image(systemName: "list.bullet").foregroundStyle(AppDesign.muted)
                                playlistSearch
                            }
                            if player.snapshot.originPlaylistID == playlist.id {
                                Text("Playing a captured queue. Playlist edits apply the next time you start it.")
                                    .font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                            }
                            rowHeadings(showsDates: showsDates, showsDurations: showsDurations)
                            if library.loadingTracks && library.items.isEmpty {
                                TrackListSkeleton(layout: .playlist, showsDates: showsDates, showsDurations: showsDurations,
                                    label: "Loading playlist tracks", identifier: "playlist-tracks-loading")
                            }
                            LazyVStack(spacing: 2) {
                                ForEach(filteredItems) { result in
                                    let index = result.originalIndex
                                    let item = result.item
                                    let row = PlaylistTrackRow(app: app, item: item, position: index + 1,
                                        active: player.snapshot.originPlaylistID == playlist.id && player.snapshot.activePlaylistItemID == item.id,
                                        playback: player.snapshot.playback, showsDates: showsDates, showsDurations: showsDurations,
                                        busy: library.busy, localPath: item.video.flatMap { player.snapshot.localThumbnailPaths?[$0.id] }, focusedControl: $focusedControl,
                                        reorderLibrary: hasActiveSearch ? nil : library, playlistID: playlist.id,
                                        play: { library.play(occurrenceID: item.id, in: playlist.id) },
                                        actions: { invokingControl = item.id; library.presentItemActions(occurrenceID: item.id, playlistID: playlist.id) })
                                    if !hasActiveSearch {
                                        row.onDrop(of: [PlaylistDragPayload.typeIdentifier], delegate: PlaylistInsertionDrop(library: library, playlistID: playlist.id, insertionIndex: index, splitRow: true))
                                            .overlay(alignment: .top) {
                                                if library.dragInsertion == index { Rectangle().fill(AppDesign.green).frame(height: 2).allowsHitTesting(false) }
                                            }
                                    } else {
                                        row
                                    }
                                }
                                if !hasActiveSearch {
                                    Color.clear.frame(height: 18).contentShape(Rectangle())
                                        .onDrop(of: [PlaylistDragPayload.typeIdentifier], delegate: PlaylistInsertionDrop(library: library, playlistID: playlist.id, insertionIndex: library.items.count))
                                        .overlay(alignment: .top) {
                                            if library.dragInsertion == library.items.count { Rectangle().fill(AppDesign.green).frame(height: 2).allowsHitTesting(false) }
                                        }
                                }
                            }
                            if library.items.isEmpty && !library.busy {
                                VStack(spacing: 10) {
                                    Image(systemName: "music.note.list").font(.system(size: 32))
                                    Text("Your playlist starts here").font(.title3.bold())
                                    Text("Search for a video and add it to this playlist.").foregroundStyle(AppDesign.muted)
                                }.frame(maxWidth: .infinity).padding(.vertical, 44)
                            } else if filteredItems.isEmpty && !library.busy {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 28))
                                    Text("No matching videos").font(.title3.bold())
                                    Text("Try a different title or creator.").foregroundStyle(AppDesign.muted)
                                }.frame(maxWidth: .infinity).padding(.vertical, 44)
                            }
                        }.padding(24).background(AppDesign.Surface.panel)
                    }
                }.safeAreaInset(edge: .bottom, spacing: 0) {
                    if library.reorderState != .idle || library.stale || library.canRetry || !library.connected {
                        HStack(spacing: 12) {
                            if library.busy { ProgressView().controlSize(.small) }
                            VStack(alignment: .leading, spacing: 4) {
                                if library.stale {
                                    Text("Previously loaded data · may be outdated").foregroundStyle(AppDesign.Status.warning)
                                }
                                Text(library.status).textSelection(.enabled)
                            }.font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            if library.canRetry || library.reorderState == .unconfirmed || library.reorderState == .savedRefreshUnavailable {
                                Button(library.reorderState == .rejected ? "Retry move" : "Refresh YouTube") {
                                    if library.canRetry { library.retryLast() } else { library.refresh() }
                                }.disabled(library.busy)
                            }
                            if library.configured && (library.stale || library.canRetry || !library.connected) {
                                Button("Reconnect YouTube") { library.connect() }.disabled(library.busy)
                            }
                        }.padding(14).background(AppDesign.Surface.raised).tidalBorder(cornerRadius: 0)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("This playlist is no longer available.").font(.title3.bold())
                    Button("Back to Home") { app.showHome() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.foregroundStyle(AppDesign.Text.primary)
        .onChange(of: searchQuery) { _ in library.cancelDrag() }
        .onChange(of: library.selected?.id) { _ in searchQuery = "" }
        .sheet(item: $library.actionContext, onDismiss: {
            focusedControl = invokingControl; invokingControl = nil
        }) { context in PlaylistActionsSheet(context: context, library: library, player: player) }
    }

    private var playlistSearch: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppDesign.muted)
            TextField("Search playlist", text: $searchQuery)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search this playlist by title or creator")
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppDesign.muted)
                }.buttonStyle(.plain).accessibilityLabel("Clear playlist search")
            }
        }
        .padding(.horizontal, 10).frame(minWidth: 96, maxWidth: 260, minHeight: 34, maxHeight: 34)
        .layoutPriority(1)
        .background(AppDesign.Surface.raised, in: RoundedRectangle(cornerRadius: 7))
        .tidalBorder(cornerRadius: 7)
    }

    private func rowHeadings(showsDates: Bool, showsDurations: Bool) -> some View {
        HStack(spacing: PlaylistTrackColumns.gap) {
            Text("#").frame(width: PlaylistTrackColumns.position)
            HStack(spacing: PlaylistTrackColumns.gap) {
                Color.clear.frame(width: PlaylistTrackColumns.artwork, height: 1)
                Text("Title").frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("playlist-title-column")
            }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            if showsDates { Text("Date added").frame(width: PlaylistTrackColumns.date, alignment: .leading) }
            if showsDurations { Image(systemName: "clock").frame(width: PlaylistTrackColumns.duration) }
            Color.clear.frame(width: PlaylistTrackColumns.actions, height: 1)
            Color.clear.frame(width: PlaylistTrackColumns.handle, height: 1)
        }.font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.horizontal, PlaylistTrackColumns.inset).padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(AppDesign.Border.decorative).frame(height: 1) }.accessibilityHidden(true)
    }
}

private struct PlaylistCoverHeader: View {
    let playlist: YouTubePlaylist
    let loadedCount: Int?
    let fallbackURL: URL?
    @Binding var color: Color
    var renameEnabled = true
    let rename: () -> Void
    @State private var artwork: NSImage?
    private var urls: [URL] {
        var seen = Set<URL>()
        return [playlist.thumbnailURL, fallbackURL].compactMap { $0 }.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            color
            if let artwork {
                GeometryReader { bounds in
                    Image(nsImage: artwork).resizable().scaledToFill()
                        .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                }
            }
            else { Image(systemName: "music.note.list").font(.system(size: 100)).foregroundStyle(AppDesign.Accent.secondary.opacity(0.10)).frame(maxWidth: .infinity) }
            LinearGradient(colors: [AppDesign.Surface.canvas.opacity(0.05), AppDesign.Surface.canvas.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [AppDesign.Surface.canvas.opacity(0.40), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 12) {
                Text(playlist.privacy.map { "\($0.capitalized) playlist" } ?? "Playlist").font(.system(size: 12, weight: .medium))
                Button(action: rename) {
                    Text(playlist.title).font(.system(size: 54, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.6)
                        .multilineTextAlignment(.leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!renameEnabled)
                    .help("Rename playlist").accessibilityLabel("Rename playlist \(playlist.title)")
                    .accessibilityIdentifier("playlist-rename-title").accessibilityAddTraits(.isHeader)
                if let description = playlist.description, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(AppDesign.Text.primary).lineLimit(2)
                }
                Text([playlist.owner, "\(loadedCount ?? playlist.count) \((loadedCount ?? playlist.count) == 1 ? "video" : "videos")"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(AppDesign.Text.primary)
            }.foregroundStyle(AppDesign.Text.primary).padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 320).clipped().task(id: urls) {
            artwork = nil; color = AppDesign.Surface.raised
            for url in urls {
                guard !Task.isCancelled else { return }
                do {
                    let data: Data
                    if url.isFileURL { data = try Data(contentsOf: url) }
                    else {
                        guard url.scheme == "https" else { continue }
                        let (bytes, response) = try await URLSession.shared.data(from: url)
                        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else { continue }
                        data = bytes
                    }
                    guard !Task.isCancelled else { return }
                    guard data.count <= 10_485_760, let image = NSImage(data: data),
                          image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else { continue }
                    artwork = image
                    if let sampled = averageColor(image) { color = Color(nsColor: sampled) }
                    return
                } catch {
                    // Try the first available video after failed primary HTTP, file or decode.
                }
            }
        }
    }

    private func averageColor(_ image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        return pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let rgba = bytes.bindMemory(to: UInt8.self)
            return NSColor(srgbRed: CGFloat(rgba[0]) / 255, green: CGFloat(rgba[1]) / 255, blue: CGFloat(rgba[2]) / 255, alpha: 1)
        }
    }
}

/// Playback, drag and action controls retain separate native hit regions.
struct PlaylistTrackRow: View {
    let app: ApplicationModel
    let item: YouTubePlaylistItem
    let position: Int
    let active: Bool
    let playback: PlaybackState
    let showsDates: Bool
    let showsDurations: Bool
    let busy: Bool
    var localPath: String? = nil
    var focusedControl: FocusState<String?>.Binding
    var reorderLibrary: PlaylistLibrary? = nil
    var playlistID = ""
    let play: () -> Void
    let actions: () -> Void
    @State private var hovered = false
    @FocusState private var playFocused: Bool

    var body: some View {
        HStack(spacing: PlaylistTrackColumns.gap) {
            Button(action: play) {
                ZStack {
                    if hovered || playFocused { Image(systemName: "play.fill") }
                    else if active { Image(systemName: playback == .paused || playback == .ended ? "pause.fill" : "waveform") }
                    else { Text("\(position)").monospacedDigit() }
                }.frame(width: PlaylistTrackColumns.position, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(item.video == nil || busy).focused($playFocused)
                .foregroundStyle(active ? AppDesign.green : AppDesign.muted).accessibilityLabel("Play \(item.title) from position \(position)")
            HStack(spacing: PlaylistTrackColumns.gap) {
                LibraryArtwork(url: item.video?.thumbnailURL, localPath: localPath, symbol: item.video == nil ? "exclamationmark.triangle" : "music.note")
                    .frame(width: PlaylistTrackColumns.artwork, height: PlaylistTrackColumns.artwork)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .opacity(item.video == nil ? 0.5 : 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(active ? AppDesign.Accent.primary : AppDesign.Text.primary).lineLimit(1)
                    Text(item.video.map { $0.creator.isEmpty ? "Video" : $0.creator } ?? "Unavailable · skipped during playback")
                        .font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("playlist-track-title-\(item.id)")
                    .accessibilityLabel("\(item.title), \(item.video?.creator ?? "Unavailable"), position \(position)\(active ? ", \(playback.rawValue)" : "")")
            }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            if showsDates { Text(item.addedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "")
                .font(.system(size: 11)).foregroundStyle(AppDesign.muted).frame(width: PlaylistTrackColumns.date, alignment: .leading) }
            if showsDurations { Text(item.video?.durationSeconds.map { seconds in
                let duration = Int(seconds); return "\(duration / 60):\(String(format: "%02d", duration % 60))"
            } ?? "").monospacedDigit().font(.system(size: 11)).foregroundStyle(AppDesign.muted).frame(width: PlaylistTrackColumns.duration) }
            HStack(spacing: 10) {
                if let video = item.video {
                    SaveDestinationButton(app: app, video: video, sourcePlaylistID: playlistID, rowHovered: hovered)
                } else {
                    Color.clear.frame(width: 34, height: 34).accessibilityHidden(true)
                }
                AppIconButton(title: "Actions for \(item.title), position \(position)", symbol: "ellipsis", enabled: !busy, action: actions)
                    .focusable().focused(focusedControl, equals: item.id)
            }.frame(width: PlaylistTrackColumns.actions)
            if let reorderLibrary {
                PlaylistDragHandle(item: item, playlistID: playlistID, localPath: localPath, library: reorderLibrary)
                    .frame(width: PlaylistTrackColumns.handle, height: 44)
            } else {
                Color.clear.frame(width: PlaylistTrackColumns.handle, height: 44).accessibilityHidden(true)
            }
        }.padding(.horizontal, PlaylistTrackColumns.inset).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 5).fill(hovered || playFocused || focusedControl.wrappedValue == item.id ? AppDesign.Surface.hover : active ? AppDesign.Surface.selected : .clear))
            .tidalBorder(cornerRadius: 5, focused: playFocused || focusedControl.wrappedValue == item.id, visible: playFocused || focusedControl.wrappedValue == item.id)
            .onHover { hovered = $0 }
    }
}

private struct PlaylistPlayButtonStyle: ButtonStyle {
    let hovered: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(AppDesign.Text.onAccent)
            .background(Circle().fill(configuration.isPressed ? AppDesign.Accent.pressed : hovered ? AppDesign.Accent.hover : AppDesign.Accent.primary))
    }
}
