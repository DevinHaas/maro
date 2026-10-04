import AppKit
import SwiftUI

enum AppDesign {
    private static func rgb(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 255) / 255,
              green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    enum Surface {
        static let canvas = rgb(0x0B151A)
        static let panel = rgb(0x10232B)
        static let raised = rgb(0x18323B)
        static let hover = rgb(0x21434C)
        static let selected = rgb(0x1D4547)
    }
    enum Text {
        static let primary = rgb(0xDDF1F0)
        static let secondary = rgb(0xA0BDC4)
        static let onAccent = Surface.canvas
        static let disabled = rgb(0x78949E)
    }
    enum Accent {
        static let primary = rgb(0x91DAB8)
        static let hover = rgb(0xABEDCE)
        static let pressed = rgb(0x79C9A7)
        static let secondary = rgb(0x82CDDF)
        static let secondaryHover = rgb(0xA4E5ED)
        static let secondaryPressed = rgb(0x71BACA)
    }
    enum Border {
        static let decorative = rgb(0x2B4A54)
        static let interactive = rgb(0x729CA6)
        static let focus = rgb(0xB5F3E8)
    }
    enum Status {
        static let warning = rgb(0xE5C78D)
        static let error = rgb(0xF0A0A0)
    }
    static let chrome = Surface.canvas
    static let surface = Surface.panel
    static let raised = Surface.raised
    static let green = Accent.primary
    static let muted = Text.secondary
}

extension View {
    /// Paint stays inside the existing shape and never participates in layout or hit testing.
    func tidalBorder(cornerRadius: CGFloat, focused: Bool = false, interactive: Bool = false, visible: Bool = true) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: focused ? 2 : 0)
                .strokeBorder(visible ? (focused ? AppDesign.Border.focus : interactive ? AppDesign.Border.interactive : AppDesign.Border.decorative) : .clear, lineWidth: 1)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    func tidalCapsuleBorder(focused: Bool = false, interactive: Bool = false) -> some View {
        overlay {
            Capsule().inset(by: focused ? 2 : 0)
                .strokeBorder(focused ? AppDesign.Border.focus : interactive ? AppDesign.Border.interactive : AppDesign.Border.decorative, lineWidth: 1)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

private struct TidalIconButtonStyle: ButtonStyle {
    var prominent: Bool
    var hovered: Bool
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(!enabled ? AppDesign.Text.disabled : prominent ? AppDesign.Text.onAccent : AppDesign.Text.primary)
            .background(Circle().fill(prominent
                ? (configuration.isPressed ? AppDesign.Accent.pressed : hovered ? AppDesign.Accent.hover : AppDesign.Accent.primary)
                : configuration.isPressed ? AppDesign.Surface.selected : hovered ? AppDesign.Surface.hover : .clear))
    }
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
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }.buttonStyle(TidalIconButtonStyle(prominent: prominent, hovered: hovered, enabled: enabled)).disabled(!enabled)
            .onHover { hovered = $0 }.help(title).accessibilityLabel(title)
    }
}
struct LibraryArtwork: View {
    var url: URL?
    var localPath: String?
    var symbol = "music.note.list"
    var favorites = false
    var body: some View {
        ZStack {
            if favorites {
                LinearGradient(colors: [AppDesign.Surface.raised, AppDesign.Accent.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(AppDesign.Text.primary)
            } else {
                AppDesign.raised
                if let localPath, let image = CachedArtworkImages.image(at: localPath) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                        placeholder: { Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(AppDesign.muted) }
                }
            }
        }.clipped().clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityHidden(true)
    }
}

@MainActor private enum CachedArtworkImages {
    private static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 80
        return cache
    }()
    static func image(at path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        if let image = images.object(forKey: path as NSString) { return image }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        images.setObject(image, forKey: path as NSString)
        return image
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
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(selected ? AppDesign.green : AppDesign.Text.primary).lineLimit(1)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(AppDesign.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? AppDesign.Surface.selected : hovered ? AppDesign.Surface.hover : .clear))
                .tidalBorder(cornerRadius: 6, interactive: selected, visible: selected || hovered)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }.accessibilityLabel("\(title), \(subtitle)")
    }
}
