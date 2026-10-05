import AppKit
import MaroCore
import SwiftUI

struct BottomPlayerView: View {
    @ObservedObject var app: ApplicationModel
    @ObservedObject var presentation: PlayerPresentation
    @State private var timelinePreview: Double?
    private var snapshot: PlayerSnapshot { presentation.snapshot }
    private var video: VideoSummary? { snapshot.loadedVideo?.video }
    private var playing: Bool { snapshot.playback == .playing || snapshot.playback == .buffering || snapshot.isSelecting }
    private var loadingAudio: Bool { snapshot.isSelecting || (snapshot.playback == .buffering && snapshot.timeline == nil) }
    var body: some View {
        GeometryReader { geometry in
            // Symmetric side frames keep transport at the window midpoint, regardless
            // of the title's intrinsic width, volume controls or the sidebar state.
            let centerWidth = min(520, geometry.size.width * 0.44)
            let sideWidth = max(0, (geometry.size.width - centerWidth - 48) / 2)
            HStack(spacing: 24) {
                currentTrack.frame(width: sideWidth)
                transport.frame(width: centerWidth)
                trailingControls.frame(width: sideWidth, alignment: .trailing)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.padding(.horizontal, 12)
    }

    private var currentTrack: some View {
        HStack(spacing: 12) {
            ZStack {
                AppDesign.raised
                if loadingAudio && video == nil {
                    LoadingSkeleton(label: "Loading track artwork", identifier: "player-artwork-loading", announce: false) {
                        SkeletonBlock(cornerRadius: 5)
                    }
                } else if let video, let path = snapshot.localThumbnailPaths?[video.id], let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else { Image(systemName: "music.note").foregroundStyle(AppDesign.muted) }
            }.frame(width: 56, height: 56).clipped().clipShape(RoundedRectangle(cornerRadius: 5))
            Group {
                if loadingAudio && video == nil {
                    PlayerTrackDetailsSkeleton().frame(height: 29)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(video?.title ?? "Choose a video").font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(video?.creator ?? "Search YouTube to start listening").font(.system(size: 10)).foregroundStyle(AppDesign.muted).lineLimit(1)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).clipped()
            AppIconButton(title: "Toggle favorite", symbol: snapshot.favorites.contains { $0.id == video?.id } ? "heart.fill" : "heart", enabled: video != nil) {
                if let video { app.perform(.favoriteToggle, videoID: video.id) }
            }
        }
    }

    private var transport: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIconButton(title: "Previous", symbol: "backward.end.fill", enabled: snapshot.canGoPrevious == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate) { app.perform(.previous) }
                AppIconButton(title: snapshot.playback == .ended ? "Replay" : playing ? "Pause" : "Play",
                    symbol: snapshot.playback == .ended ? "arrow.counterclockwise" : playing ? "pause.fill" : "play.fill",
                    enabled: video != nil && (playing || !snapshot.sourceNeedsUpdate), prominent: true) { app.perform(snapshot.playback == .ended ? .replay : .toggle) }
                AppIconButton(title: "Next", symbol: "forward.end.fill", enabled: snapshot.canGoNext == true && !snapshot.isSelecting && !snapshot.sourceNeedsUpdate) { app.perform(.next) }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("bottom-player-transport")
            if loadingAudio {
                PlayerTimelineSkeleton(timeWidth: 40)
            } else {
                HStack(spacing: 8) {
                    Text(clock(timelinePreview ?? snapshot.seekTarget ?? snapshot.loadedVideo?.positionSeconds ?? 0))
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: 40)
                    PlaybackTimelineSlider(position: snapshot.seekTarget ?? snapshot.loadedVideo?.positionSeconds ?? 0,
                        timeline: snapshot.timeline, playbackID: snapshot.timelineID, epoch: presentation.timelineEpoch,
                        preview: { timelinePreview = $0 }, commit: { app.controller.seek(to: $0, timelineID: $1) }, displayDuration: snapshot.timeline?.duration ?? video?.durationSeconds)
                        .frame(height: 18).onChange(of: snapshot.timelineID) { _ in timelinePreview = nil }.onDisappear { timelinePreview = nil }
                    Text((snapshot.timeline?.duration ?? video?.durationSeconds).map(clock) ?? "--:--")
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: 40)
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(AppDesign.muted)
            }
            if let error = app.actionError ?? snapshot.error ?? snapshot.persistenceError {
                Text(error).font(.system(size: 10)).foregroundStyle(AppDesign.Status.error).lineLimit(1).help(error)
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 10) {
            if let video {
                SaveDestinationButton(app: app, video: video, rowHovered: true, iconOnly: true)
            } else {
                AppIconButton(title: "Add to playlist", symbol: "plus", enabled: false) {}
            }
            Image(systemName: "speaker.wave.2.fill").foregroundStyle(AppDesign.muted).accessibilityHidden(true)
            Slider(value: Binding(get: { snapshot.volume ?? 1 }, set: { app.controller.setVolume($0); app.render() }), in: 0...1)
                .tint(AppDesign.Accent.primary).frame(width: 90).accessibilityLabel("Playback volume")
        }
    }
    private func clock(_ value: Double) -> String {
        guard value.isFinite else { return "--:--" }
        let seconds = Int(min(max(0, value), 359_999))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
