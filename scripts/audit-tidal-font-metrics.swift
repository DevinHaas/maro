import AppKit
import CoreText
import Foundation

for path in CommandLine.arguments.dropFirst() {
    var error: Unmanaged<CFError>?
    guard CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, &error) else {
        fatalError("Could not register audit font: \(path)")
    }
}
struct Role {
    var name: String
    var size: CGFloat
    var weight: NSFont.Weight
    var candidate: String
    var sample: String
    var rounded = false
    var monospaced = false
}
let roles = [
    Role(name: "library title", size: 14, weight: .medium, candidate: "JetBrainsMono-Medium", sample: "Evening Sessions"),
    Role(name: "library subtitle", size: 11, weight: .regular, candidate: "JetBrainsMono-Regular", sample: "Playlist • Maro"),
    Role(name: "search input", size: 14, weight: .regular, candidate: "JetBrainsMono-Regular", sample: "What do you want to listen to?"),
    Role(name: "row title", size: 14, weight: .medium, candidate: "JetBrainsMono-Medium", sample: "Unhurried listening"),
    Role(name: "duration", size: 11, weight: .regular, candidate: "JetBrainsMono-Regular", sample: "3:42"),
    Role(name: "Home section heading", size: 23, weight: .bold, candidate: "JetBrainsMono-SemiBold", sample: "Made for you"),
    Role(name: "Home feature heading (narrow)", size: 26, weight: .bold, candidate: "JetBrainsMono-SemiBold", sample: "Your next favourite sound"),
    Role(name: "Home feature heading (wide)", size: 34, weight: .bold, candidate: "JetBrainsMono-SemiBold", sample: "Your next favourite sound"),
    Role(name: "playlist heading", size: 54, weight: .heavy, candidate: "JetBrainsMono-SemiBold", sample: "Evening Sessions"),
    Role(name: "player title", size: 12, weight: .medium, candidate: "JetBrainsMono-Medium", sample: "Unhurried listening"),
    Role(name: "wordmark", size: 24, weight: .heavy, candidate: "JetBrainsMono-SemiBold", sample: "maro", rounded: true),
    Role(name: "player time", size: 10, weight: .regular, candidate: "JetBrainsMono-Regular", sample: "3:42", monospaced: true)
]
func metrics(_ font: NSFont, sample: String) -> [String: Any] {
    let string = NSAttributedString(string: sample, attributes: [.font: font, .ligature: 0])
    let line = CTLineCreateWithAttributedString(string)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    return ["font": font.fontName, "advance": width, "ascent": ascent, "descent": descent,
            "leading": leading, "glyphBounds": [bounds.origin.x, bounds.origin.y, bounds.width, bounds.height]]
}
let results = roles.map { role -> [String: Any] in
    guard let candidate = NSFont(name: role.candidate, size: role.size) else { fatalError("Missing candidate font") }
    var baseline = NSFont.systemFont(ofSize: role.size, weight: role.weight)
    if role.monospaced { baseline = NSFont.monospacedSystemFont(ofSize: role.size, weight: role.weight) }
    if role.rounded {
        guard let descriptor = baseline.fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: descriptor, size: role.size) else { fatalError("Missing rounded system font") }
        baseline = font
    }
    return ["role": role.name, "size": role.size, "sample": role.sample,
            "baseline": metrics(baseline, sample: role.sample),
            "candidate": metrics(candidate, sample: role.sample)]
}
let output = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: output, as: UTF8.self))

