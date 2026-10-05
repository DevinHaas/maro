import AppKit
import SwiftUI

private struct SkeletonReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    /// Native fixtures can render reduced motion without changing system preferences.
    var skeletonReduceMotionOverride: Bool? {
        get { self[SkeletonReduceMotionOverrideKey.self] }
        set { self[SkeletonReduceMotionOverrideKey.self] = newValue }
    }
}

/// One restrained shimmer per placeholder group, with a static reduced-motion fallback.
struct LoadingSkeleton<Content: View>: View {
    let label: String
    let identifier: String
    var announce = true
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.skeletonReduceMotionOverride) private var reduceMotionOverride

    var body: some View {
        Group {
            if reduceMotionOverride ?? reduceMotion { content() }
            else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    content().overlay {
                        GeometryReader { geometry in
                            let band = min(180, max(60, geometry.size.width * 0.4))
                            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                            LinearGradient(colors: [.clear, .white.opacity(0.13), .clear],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: band)
                                .offset(x: -band + (geometry.size.width + band) * phase)
                        }.mask(content())
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("In progress")
        .accessibilityIdentifier(identifier)
        .onAppear {
            guard announce, let window = NSApp?.keyWindow else { return }
            NSAccessibility.post(element: window, notification: .announcementRequested,
                userInfo: [.announcement: label, .priority: NSAccessibilityPriorityLevel.low.rawValue])
        }
    }
}

struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 4
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            // An opaque theme color also gives the shimmer mask full shape coverage.
            .fill(AppDesign.Surface.hover)
            .accessibilityHidden(true)
    }
}

/// Matches the timeline's height so preparation never resizes either player.
struct PlayerTimelineSkeleton: View {
    let timeWidth: CGFloat
    var body: some View {
        LoadingSkeleton(label: "Loading track audio", identifier: "player-audio-loading") {
            HStack(spacing: 8) {
                SkeletonBlock().frame(width: timeWidth, height: 8)
                SkeletonBlock(cornerRadius: 2).frame(height: 4)
                SkeletonBlock().frame(width: timeWidth, height: 8)
            }.frame(height: 18)
        }
    }
}

struct PlayerTrackDetailsSkeleton: View {
    var body: some View {
        LoadingSkeleton(label: "Loading track details", identifier: "player-details-loading", announce: false) {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBlock().frame(width: geometry.size.width * 0.78, height: 11)
                    SkeletonBlock().frame(width: geometry.size.width * 0.45, height: 8)
                }.frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct TrackListSkeleton: View {
    enum Layout: Equatable { case search, preview, playlist }
    var count = 4
    var layout: Layout = .search
    var showsDates = false
    var showsDurations = true
    var label = "Loading tracks"
    var identifier = "track-list-loading"

    var body: some View {
        LoadingSkeleton(label: label, identifier: identifier) {
            VStack(spacing: layout == .playlist ? 2 : 6) {
                ForEach(0..<count, id: \.self) { index in row(index: index) }
            }
        }
    }

    @ViewBuilder private func row(index: Int) -> some View {
        if layout == .playlist {
            HStack(spacing: PlaylistTrackColumns.gap) {
                SkeletonBlock().frame(width: PlaylistTrackColumns.position, height: 10)
                SkeletonBlock(cornerRadius: 5).frame(width: PlaylistTrackColumns.artwork, height: PlaylistTrackColumns.artwork)
                textLines(index: index)
                if showsDates { SkeletonBlock().frame(width: PlaylistTrackColumns.date, height: 8) }
                if showsDurations { SkeletonBlock().frame(width: PlaylistTrackColumns.duration, height: 8) }
                Color.clear.frame(width: PlaylistTrackColumns.actions)
                Color.clear.frame(width: PlaylistTrackColumns.handle)
            }.padding(.horizontal, PlaylistTrackColumns.inset).padding(.vertical, 9)
        } else {
            HStack(spacing: SearchTrackColumns.gap) {
                if layout == .search { Color.clear.frame(width: SearchTrackColumns.play) }
                SkeletonBlock(cornerRadius: 6).frame(width: layout == .preview ? 48 : SearchTrackColumns.artwork, height: layout == .preview ? 48 : SearchTrackColumns.artwork)
                textLines(index: index)
                if layout == .search {
                    SkeletonBlock().frame(width: 40, height: 8).frame(width: SearchTrackColumns.duration, alignment: .trailing)
                    Color.clear.frame(width: SearchTrackColumns.favorite)
                    Color.clear.frame(width: SearchTrackColumns.actions)
                } else {
                    Color.clear.frame(width: 98)
                }
            }.padding(.horizontal, SearchTrackColumns.inset).padding(.vertical, 10)
        }
    }

    private func textLines(index: Int) -> some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock().frame(width: max(0, geometry.size.width * (index.isMultiple(of: 2) ? 0.78 : 0.62)), height: 11)
                SkeletonBlock().frame(width: max(0, geometry.size.width * (index.isMultiple(of: 2) ? 0.4 : 0.5)), height: 8)
            }
        }.frame(height: 27).frame(maxWidth: .infinity)
    }
}

struct TrackCardsSkeleton: View {
    let label: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LoadingSkeleton(label: label, identifier: "suggested-tracks-loading") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(0..<3, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBlock(cornerRadius: 5).frame(width: 176, height: 176)
                            SkeletonBlock().frame(width: index == 1 ? 130 : 158, height: 12).frame(height: 36, alignment: .top)
                            SkeletonBlock().frame(width: 96, height: 9).frame(height: 28, alignment: .center)
                        }.padding(10).frame(width: 196, alignment: .leading)
                    }
                }.padding(.bottom, 4)
            }
        }
    }
}
