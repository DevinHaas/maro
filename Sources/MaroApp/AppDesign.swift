import AppKit
import SwiftUI

enum AppDesign {
    static let chrome = Color.black
    static let surface = Color(red: 0.068, green: 0.068, blue: 0.068)
    static let raised = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let green = Color(red: 0.12, green: 0.84, blue: 0.38)
    static let muted = Color.white.opacity(0.60)
}
struct AppIconButton: View {
    let title: String
    let symbol: String
    var enabled = true
    var prominent = false
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: prominent ? 17 : 15, weight: .semibold))
                .foregroundStyle(prominent ? Color.black : Color.white).frame(width: 38, height: 38)
                .background(Circle().fill(prominent ? AppDesign.green : hovered ? AppDesign.raised : Color.clear))
                .contentShape(Circle())
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.3)
            .onHover { hovered = $0 }.help(title).accessibilityLabel(title)
    }
}
struct LibraryArtwork: View {
    var url: URL?
    var symbol = "music.note.list"
    var favorites = false
    var body: some View {
        ZStack {
            if favorites {
                LinearGradient(colors: [Color.indigo, Color.mint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(.white)
            } else {
                AppDesign.raised
                AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                    placeholder: { Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(AppDesign.muted) }
            }
        }.clipped().clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityHidden(true)
    }
}
struct LibraryRow: View {
    let title: String
    let subtitle: String
    var url: URL?
    var favorites = false
    var selected = false
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LibraryArtwork(url: url, favorites: favorites).frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(selected ? AppDesign.green : .white).lineLimit(1)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? AppDesign.raised : hovered ? Color.white.opacity(0.05) : .clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }.accessibilityLabel("\(title), \(subtitle)")
    }
}
