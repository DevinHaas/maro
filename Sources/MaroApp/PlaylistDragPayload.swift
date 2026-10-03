import Foundation

enum PlaylistReorderState: Equatable { case idle, saving, savedRefreshUnavailable, rejected, unconfirmed }

/// The occurrence, playlist, revision and account must all match the active native drag.
struct PlaylistDragPayload: Codable, Equatable {
    let playlistID: String
    let occurrenceID: String
    let revision: UUID
    let accountScope: String
    static let typeIdentifier = "com.maro.playlist-occurrence"
}
