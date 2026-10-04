import Foundation
import MaroCore

struct PlaylistSearchResult: Identifiable {
    let originalIndex: Int
    let item: YouTubePlaylistItem
    var id: String { item.id }
}

func PlaylistSearchProjection(items: [YouTubePlaylistItem], query: String) -> [PlaylistSearchResult] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return items.enumerated().compactMap { index, item in
        guard needle.isEmpty else {
            let titleMatches = item.title.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) != nil
            let creatorMatches = item.video?.creator.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) != nil
            guard titleMatches || creatorMatches else { return nil }
            return PlaylistSearchResult(originalIndex: index, item: item)
        }
        return PlaylistSearchResult(originalIndex: index, item: item)
    }
}
