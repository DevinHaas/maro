import AppKit
import MaroCore
import SwiftUI

struct PlaylistDetailView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View { PlaylistDetailContent(app: app, library: app.library, player: app.player) }
}

private struct PlaylistDetailContent: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var library: PlaylistLibrary
    @ObservedObject var player: PlayerPresentation
    @State private var artworkColor = Color(red: 0.20, green: 0.23, blue: 0.26)
    @State private var invokingControl: String?
    @FocusState private var focusedControl: String?
    private var showsDates: Bool { library.items.contains { $0.addedAt != nil } }
    private var showsDurations: Bool { library.items.contains { $0.video?.durationSeconds != nil } }

    var body: some View {
        Group {
            if let playlist = library.selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlaylistCoverHeader(playlist: playlist, loadedCount: library.busy ? nil : library.items.count,
                            fallbackURL: library.items.compactMap { item in
                                guard let video = item.video else { return nil as URL? }
                                return player.snapshot.localThumbnailPaths?[video.id].map { URL(fileURLWithPath: $0) } ?? video.thumbnailURL
                            }.first, color: $artworkColor)
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 18) {
                                Button { library.play() } label: {
                                    Image(systemName: "play.fill").font(.system(size: 25)).foregroundStyle(.black)
                                        .frame(width: 62, height: 62).background(Circle().fill(AppDesign.green))
                                }.buttonStyle(.plain).disabled(library.items.isEmpty || library.busy)
                                    .opacity(library.items.isEmpty || library.busy ? 0.4 : 1)
                                    .accessibilityLabel("Play \(playlist.title) in saved order")
                                AppIconButton(title: "Playlist actions for \(playlist.title)", symbol: "ellipsis", enabled: !library.busy) {
                                    invokingControl = "playlist-actions"; library.presentPlaylistActions()
                                }.focused($focusedControl, equals: "playlist-actions")
                                Spacer()
                                if library.busy { ProgressView().controlSize(.small) }
                                Text("Saved order").font(.system(size: 12)).foregroundStyle(AppDesign.muted)
                                Image(systemName: "list.bullet").foregroundStyle(AppDesign.muted)
                            }
                            if player.snapshot.originPlaylistID == playlist.id {
                                Text("Playing a captured queue. Playlist edits apply the next time you start it.")
                                    .font(.system(size: 11)).foregroundStyle(AppDesign.muted)
                            }
                            rowHeadings
                            LazyVStack(spacing: 2) {
                                ForEach(Array(library.items.enumerated()), id: \.element.id) { index, item in
                                    PlaylistTrackRow(item: item, position: index + 1,
                                        active: player.snapshot.originPlaylistID == playlist.id && player.snapshot.activePlaylistItemID == item.id,
                                        playback: player.snapshot.playback, showsDates: showsDates, showsDurations: showsDurations,
                                        busy: library.busy, localPath: item.video.flatMap { player.snapshot.localThumbnailPaths?[$0.id] }, focusedControl: $focusedControl,
                                        reorderLibrary: library, playlistID: playlist.id,
                                        play: { library.play(occurrenceID: item.id, in: playlist.id) },
                                        actions: { invokingControl = item.id; library.presentItemActions(occurrenceID: item.id, playlistID: playlist.id) })
                                        .onDrop(of: [PlaylistDragPayload.typeIdentifier], delegate: PlaylistInsertionDrop(library: library, playlistID: playlist.id, insertionIndex: index, splitRow: true))
                                        .overlay(alignment: .top) {
                                            if library.dragInsertion == index { Rectangle().fill(AppDesign.green).frame(height: 2).allowsHitTesting(false) }
                                        }
                                }
                                Color.clear.frame(height: 18).contentShape(Rectangle())
                                    .onDrop(of: [PlaylistDragPayload.typeIdentifier], delegate: PlaylistInsertionDrop(library: library, playlistID: playlist.id, insertionIndex: library.items.count))
                                    .overlay(alignment: .top) {
                                        if library.dragInsertion == library.items.count { Rectangle().fill(AppDesign.green).frame(height: 2).allowsHitTesting(false) }
                                    }
                            }
                            if library.items.isEmpty && !library.busy {
                                VStack(spacing: 10) {
                                    Image(systemName: "music.note.list").font(.system(size: 32))
                                    Text("Your playlist starts here").font(.title3.bold())
                                    Text("Search for a video and add it to this playlist.").foregroundStyle(AppDesign.muted)
                                }.frame(maxWidth: .infinity).padding(.vertical, 44)
                            }
                            if library.stale { Text("Previously loaded data · may be outdated").font(.caption).foregroundStyle(.orange) }
                            Text(library.status).font(.system(size: 11)).foregroundStyle(AppDesign.muted).textSelection(.enabled)
                        }.padding(24).background(LinearGradient(colors: [artworkColor.opacity(0.55), AppDesign.surface], startPoint: .top, endPoint: .bottom))
                    }
                }.safeAreaInset(edge: .bottom, spacing: 0) {
                    if library.reorderState != .idle || library.status.hasPrefix("Saved") {
                        HStack(spacing: 12) {
                            if library.busy { ProgressView().controlSize(.small) }
                            Text(library.status).font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            if library.canRetry || library.reorderState == .unconfirmed || library.reorderState == .savedRefreshUnavailable {
                                Button(library.reorderState == .rejected ? "Retry move" : "Refresh YouTube") {
                                    if library.canRetry { library.retryLast() } else { library.refresh() }
                                }.disabled(library.busy)
                            }
                        }.padding(14).background(AppDesign.raised)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("This playlist is no longer available.").font(.title3.bold())
                    Button("Back to Home") { app.showHome() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.sheet(item: $library.actionContext, onDismiss: {
            focusedControl = invokingControl; invokingControl = nil
        }) { context in PlaylistActionsSheet(context: context, library: library, player: player) }
    }

    private var rowHeadings: some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: 16, height: 1)
            Text("#").frame(width: 24)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
            if showsDates { Text("Date added").frame(width: 100, alignment: .leading) }
            if showsDurations { Image(systemName: "clock").frame(width: 48) }
            Color.clear.frame(width: 38, height: 1)
        }.font(.system(size: 11)).foregroundStyle(AppDesign.muted).padding(.horizontal, 8).padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }.accessibilityHidden(true)
    }
}

private struct PlaylistCoverHeader: View {
    let playlist: YouTubePlaylist
    let loadedCount: Int?
    let fallbackURL: URL?
    @Binding var color: Color
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
            else { Image(systemName: "music.note.list").font(.system(size: 100)).foregroundStyle(.white.opacity(0.10)).frame(maxWidth: .infinity) }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.black.opacity(0.40), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 12) {
                Text(playlist.privacy.map { "\($0.capitalized) playlist" } ?? "Playlist").font(.system(size: 12, weight: .medium))
                Text(playlist.title).font(.system(size: 54, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.6).accessibilityAddTraits(.isHeader)
                if let description = playlist.description, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                }
                Text([playlist.owner, "\(loadedCount ?? playlist.count) \((loadedCount ?? playlist.count) == 1 ? "video" : "videos")"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.88))
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 320).clipped().task(id: urls) {
            artwork = nil; color = Color(red: 0.20, green: 0.23, blue: 0.26)
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
        HStack(spacing: 14) {
            if let reorderLibrary {
                PlaylistDragHandle(item: item, playlistID: playlistID, localPath: localPath, library: reorderLibrary)
                    .frame(width: 16, height: 44)
            }
            Button(action: play) {
                ZStack {
                    if hovered || playFocused { Image(systemName: "play.fill") }
                    else if active { Image(systemName: playback == .paused || playback == .ended ? "pause.fill" : "waveform") }
                    else { Text("\(position)").monospacedDigit() }
                }.frame(width: 24, height: 40).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(item.video == nil || busy).focused($playFocused)
                .foregroundStyle(active ? AppDesign.green : AppDesign.muted).accessibilityLabel("Play \(item.title) from position \(position)")
            LibraryArtwork(url: item.video?.thumbnailURL, localPath: localPath, symbol: item.video == nil ? "exclamationmark.triangle" : "music.note")
                .frame(width: 44, height: 44).opacity(item.video == nil ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(active ? AppDesign.green : .white).lineLimit(1)
                Text(item.video.map { $0.creator.isEmpty ? "Video" : $0.creator } ?? "Unavailable · skipped during playback")
                    .font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.title), \(item.video?.creator ?? "Unavailable"), position \(position)\(active ? ", \(playback.rawValue)" : "")")
            if showsDates { Text(item.addedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "")
                .font(.system(size: 11)).foregroundStyle(AppDesign.muted).frame(width: 100, alignment: .leading) }
            if showsDurations { Text(item.video?.durationSeconds.map { seconds in
                let duration = Int(seconds); return "\(duration / 60):\(String(format: "%02d", duration % 60))"
            } ?? "").monospacedDigit().font(.system(size: 11)).foregroundStyle(AppDesign.muted).frame(width: 48) }
            AppIconButton(title: "Actions for \(item.title), position \(position)", symbol: "ellipsis", enabled: !busy, action: actions)
                .focused(focusedControl, equals: item.id)
        }.padding(.horizontal, 8).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 5).fill(hovered || playFocused || focusedControl.wrappedValue == item.id ? Color.white.opacity(0.10) : active ? Color.white.opacity(0.035) : .clear))
            .onHover { hovered = $0 }
    }
}
