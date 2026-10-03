import SwiftUI

/// Ticket #5 owns the detailed redesign and row action modals.
struct PlaylistDetailView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View { PlaylistLibraryView(library: app.library) }
}
