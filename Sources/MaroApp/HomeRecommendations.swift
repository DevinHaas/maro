import Foundation
import MaroCore
import SwiftUI

struct HomeSection: Identifiable {
    let id: String
    let title: String
    let query: String
    let reason: String
    let videos: [VideoSummary]
    let isOutdated: Bool
}

/// Local metadata recommendations. The controller retains the only source and audio lifetime.
@MainActor final class HomeRecommendations: ObservableObject {
    @Published private(set) var sections: [HomeSection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var isPaused = false
    var suggestedQueries: [String] { profile.seeds.map(\.query) }
    var onChange: (() -> Void)?

    private struct Seed: Equatable { let query: String; let title: String; let reason: String }
    private struct Profile: Equatable {
        var words: [String: Double] = [:]
        var creators: [String: Double] = [:]
        var seen: Set<String> = []
        var seeds: [Seed] = []
        var signature: String {
            let terms = words.keys.sorted().map { "\($0)=\(words[$0]!)" }
            let entities = creators.keys.sorted().map { "\($0)=\(creators[$0]!)" }
            return (terms + entities + seen.sorted() + seeds.map { $0.query + $0.reason }).joined(separator: "\u{1f}")
        }
    }
    private struct CacheKey: Hashable { let query: String; let provider: String; let scope: String; let profile: String }
    private struct Entry { let videos: [VideoSummary]; let expires: Date; var used: UInt64 }
    private let controller: MaroController
    private let now: () -> Date
    private var profile = Profile()
    private var scope: String?
    private var cache: [CacheKey: Entry] = [:]
    private var useCounter: UInt64 = 0
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var pending: [Seed] = []

    init(controller: MaroController, now: @escaping () -> Date = Date.init) {
        self.controller = controller; self.now = now
    }
    deinit { task?.cancel() }

    func update(favorites: [VideoSummary], playlists: [YouTubePlaylist], loaded: [String: [YouTubePlaylistItem]], scope: String) {
        let fresh = Self.preference(favorites: favorites, playlists: playlists, loaded: loaded)
        guard self.scope != scope || profile != fresh else { return }
        task?.cancel(); task = nil; isLoading = false; generation = UUID()
        if self.scope != scope { cache.removeAll(); sections = [] }
        self.scope = scope; profile = fresh; error = nil; isPaused = false
        pending = fresh.seeds.filter { seed in
            guard let entry = entry(for: seed) else { return true }
            return entry.expires <= now()
        }
        rebuild()
        resumeIfNeeded()
    }

    /// Called by the composition after foreground/audio work yields the shared provider.
    /// Player progress and navigation cannot add requests to this pending set.
    func resumeIfNeeded() {
        guard task == nil, !pending.isEmpty, !controller.hasForegroundMetadataRequest,
              !controller.snapshot.isSelecting else { return }
        let revision = generation
        isLoading = true
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == revision {
                    task = nil; isLoading = false; onChange?()
                    // Foreground may finish before this cancelled await unwinds.
                    // Resuming remaining seeds here closes that callback race without replaying a query.
                    resumeIfNeeded()
                }
            }
            while generation == revision, !Task.isCancelled, let seed = pending.first {
                guard !controller.hasForegroundMetadataRequest, !controller.snapshot.isSelecting else { return }
                do {
                    let candidates = try await controller.metadataSearch(seed.query, intent: .discovery)
                    try Task.checkCancellation()
                    guard generation == revision else { return }
                    pending.removeFirst()
                    useCounter += 1
                    cache[key(for: seed)] = Entry(videos: Array(candidates.prefix(20)), expires: now().addingTimeInterval(1_800), used: useCounter)
                    trimCache()
                    rebuild()
                } catch is CancellationError {
                    // One automatic attempt per seed preserves the three-search cold budget.
                    // A deliberate Retry can finish an interrupted query after foreground work.
                    if generation == revision, !Task.isCancelled {
                        pending.removeFirst()
                        isPaused = true
                    }
                    return
                } catch {
                    guard generation == revision, !Task.isCancelled else { return }
                    pending.removeFirst()
                    self.error = "Could not update suggestions. \(error.localizedDescription)"
                    rebuild()
                }
            }
        }
    }

    func retry() {
        guard task == nil else { return }
        error = nil; isPaused = false
        pending = profile.seeds.filter { entry(for: $0).map { $0.expires <= now() } ?? true }
        rebuild(); resumeIfNeeded()
    }

    private func key(for seed: Seed) -> CacheKey {
        CacheKey(query: Self.normalized(seed.query), provider: controller.metadataProviderVersion,
                 scope: scope ?? "local", profile: profile.signature)
    }
    private func entry(for seed: Seed, touching: Bool = false) -> Entry? {
        let target = key(for: seed)
        // Profile changes rerank the same account's metadata without repeating a fresh query.
        guard var selected = cache.filter({ $0.key.query == target.query && $0.key.provider == target.provider && $0.key.scope == target.scope })
            .max(by: { $0.value.expires == $1.value.expires ? $0.value.used < $1.value.used : $0.value.expires < $1.value.expires }) else { return nil }
        if touching {
            useCounter += 1
            selected.value.used = useCounter
            cache[selected.key] = selected.value
        }
        return selected.value
    }
    private func trimCache() {
        while cache.count > 12, let oldest = cache.min(by: { $0.value.used < $1.value.used })?.key { cache.removeValue(forKey: oldest) }
    }
    private func rebuild() {
        var usedVideos = Set<String>()
        sections = profile.seeds.map { seed in
            let available = entry(for: seed, touching: true)
            let videos = ranked(available?.videos ?? [], excluding: usedVideos)
            usedVideos.formUnion(videos.map(\.id))
            return HomeSection(id: seed.query, title: seed.title, query: seed.query, reason: seed.reason,
                videos: videos, isOutdated: available.map { $0.expires <= now() } ?? false)
        }
        onChange?()
    }
    private func ranked(_ candidates: [VideoSummary], excluding: Set<String>) -> [VideoSummary] {
        let wordTotal = max(1, profile.words.values.reduce(0, +))
        let creatorMax = max(1, profile.creators.values.max() ?? 0)
        var identities = excluding
        let sorted = candidates.enumerated().filter { identities.insert($0.element.id).inserted }.map { index, video in
            let overlap = Self.features(video.title + " " + video.creator).reduce(0.0) { $0 + (profile.words[$1] ?? 0) } / wordTotal
            let creator = (profile.creators[Self.normalized(video.creator)] ?? 0) / creatorMax
            let providerRank = 1 - Double(index) / Double(max(1, candidates.count - 1))
            return (video: video, index: index, score: 0.7 * overlap + 0.2 * creator + 0.1 * providerRank)
        }.sorted {
            let leftSeen = profile.seen.contains($0.video.id), rightSeen = profile.seen.contains($1.video.id)
            if leftSeen != rightSeen { return !leftSeen }
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.index != $1.index { return $0.index < $1.index }
            return $0.video.id < $1.video.id
        }
        var creatorCounts: [String: Int] = [:]
        var result: [VideoSummary] = []
        for candidate in sorted {
            let creator = Self.normalized(candidate.video.creator)
            if !creator.isEmpty && creatorCounts[creator, default: 0] >= 2 { continue }
            result.append(candidate.video)
            if !creator.isEmpty { creatorCounts[creator, default: 0] += 1 }
            if result.count == 8 { break }
        }
        return result
    }

    private static let noise: Set<String> = ["the", "a", "an", "and", "of", "for", "to", "in", "on", "with", "music", "video", "official", "audio", "lyrics", "hd", "4k", "full", "mix", "playlist", "live", "feat", "ft"]
    private static let themes: [(String, String, [String])] = [
        ("jazz", "Jazz", ["jazz", "bebop", "smooth jazz"]),
        ("ambient", "Ambient", ["ambient", "atmospheric", "soundscape"]),
        ("lofi focus", "Lofi & focus", ["lofi", "lo fi", "low fi", "focus", "study", "chillhop"]),
        ("pop", "Pop", ["pop", "synthpop"]),
        ("electronic", "Electronic", ["electronic", "techno", "house", "edm", "trance"])
    ]
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    private static func features(_ text: String) -> Set<String> {
        let normalized = normalized(text)
        let words = Set(normalized.split(separator: " ").map(String.init).filter { $0.count > 1 && !noise.contains($0) && !$0.allSatisfy(\.isNumber) })
        var result = words
        for (theme, _, aliases) in themes {
            if aliases.contains(where: { (" " + normalized + " ").contains(" " + $0 + " ") }) { result.insert(theme) }
        }
        return result
    }
    private static func preference(favorites: [VideoSummary], playlists: [YouTubePlaylist], loaded: [String: [YouTubePlaylistItem]]) -> Profile {
        var profile = Profile()
        var evidence: [String: [String: Int]] = [:]
        var sourceWords: [String: Set<String>] = [:]
        var creatorNames: [String: String] = [:]
        func add(_ text: String, source: String, weight: Double) {
            for word in features(text) {
                guard evidence[source, default: [:]][word, default: 0] < 3 else { continue }
                evidence[source, default: [:]][word, default: 0] += 1
                profile.words[word, default: 0] += weight
                sourceWords[source, default: []].insert(word)
            }
        }
        func addVideo(_ video: VideoSummary, source: String, weight: Double) {
            add(video.title + " " + video.creator, source: source, weight: weight)
            let creator = normalized(video.creator)
            if !creator.isEmpty {
                profile.creators[creator] = min(9, (profile.creators[creator] ?? 0) + weight)
                creatorNames[creator] = video.creator
            }
        }
        var favoriteIDs = Set<String>()
        for video in favorites where favoriteIDs.insert(video.id).inserted { profile.seen.insert(video.id); addVideo(video, source: "favorites", weight: 3) }
        var loadedIDs = Set<String>()
        for playlistID in loaded.keys.sorted() {
            for item in loaded[playlistID] ?? [] {
                if let video = item.video, loadedIDs.insert(video.id).inserted { profile.seen.insert(video.id); addVideo(video, source: "loaded", weight: 2) }
            }
        }
        var playlistIDs = Set<String>()
        for playlist in playlists where playlistIDs.insert(playlist.id).inserted { add(playlist.title + " " + (playlist.description ?? ""), source: "playlists", weight: 1) }
        let matchingThemes = themes.filter { profile.words[$0.0] != nil }.sorted {
            let lhs = profile.words[$0.0] ?? 0, rhs = profile.words[$1.0] ?? 0
            return lhs == rhs ? $0.0 < $1.0 : lhs > rhs
        }
        for (query, title, _) in matchingThemes.prefix(3) {
            let reason: String
            if sourceWords["favorites", default: []].contains(query) { reason = "Because you saved \(title.lowercased()) videos" }
            else if sourceWords["playlists", default: []].contains(query) { reason = "Based on your \(title.lowercased()) playlists" }
            else { reason = "Based on videos in your loaded playlists" }
            profile.seeds.append(Seed(query: query, title: title, reason: reason))
        }
        for creator in profile.creators.keys.sorted(by: {
            let left = profile.creators[$0] ?? 0, right = profile.creators[$1] ?? 0
            return left == right ? $0 < $1 : left > right
        }) where profile.seeds.count < 3 {
            let name = creatorNames[creator] ?? creator
            if !profile.seeds.contains(where: { normalized($0.query) == creator }) {
                profile.seeds.append(Seed(query: name, title: "More from \(name)", reason: "Because you saved videos by \(name)"))
            }
        }
        if profile.seeds.isEmpty {
            profile.seeds = [Seed(query: "jazz", title: "Jazz", reason: "General suggestions"),
                Seed(query: "lofi focus", title: "Lofi & focus", reason: "General suggestions"),
                Seed(query: "electronic", title: "Electronic", reason: "General suggestions")]
        }
        return profile
    }
}
