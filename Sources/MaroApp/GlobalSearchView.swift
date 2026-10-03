import SwiftUI

/// Ticket #4 owns focus suggestions and previews, independently of the library filter.
struct GlobalSearchView: View {
    @ObservedObject var app: ApplicationModel
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 19)).foregroundStyle(AppDesign.muted)
            TextField("What do you want to play?", text: $app.globalQuery).textFieldStyle(.plain).font(.system(size: 14))
                .onSubmit { app.submitSearch() }.accessibilityLabel("Search YouTube")
            if !app.globalQuery.isEmpty {
                Button { app.globalQuery = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Clear global search")
            }
        }.padding(.horizontal, 18).frame(height: 44).background(AppDesign.raised).clipShape(Capsule())
    }
}
