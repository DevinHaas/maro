import AppKit
import CoreText
import SwiftUI

/// Native font resources are registered only for this process, never installed on the Mac.
/// Existing SF roles remain until their rendered bounds and baselines pass the geometry gate.
@MainActor enum AppTypography {
    private static var registered = false
    private static let names = ["JetBrainsMono-Regular", "JetBrainsMono-Medium", "JetBrainsMono-SemiBold"]

    static func registerFonts() {
        guard !registered else { return }
        registered = true
        let bundle: Bundle
        if let resources = Bundle.main.resourceURL,
           let packaged = Bundle(url: resources.appendingPathComponent("Maro_MaroApp.bundle")) {
            bundle = packaged
        } else {
            #if SWIFT_PACKAGE
            bundle = Bundle.module
            #else
            bundle = Bundle.main
            #endif
        }
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Candidate for measured roles; AppKit supplies script and emoji cascade fallback.
    /// Do not substitute this for SF without a native text-bounds/baseline comparison.
    static func nativeMono(size: CGFloat, weight: NSFont.Weight = .regular, tabular: Bool = false) -> NSFont {
        registerFonts()
        let name = weight >= .semibold ? names[2] : weight >= .medium ? names[1] : names[0]
        guard let font = NSFont(name: name, size: size) else {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
        var features: [[NSFontDescriptor.FeatureKey: Int]] = [
            [.typeIdentifier: kLigaturesType, .selectorIdentifier: kCommonLigaturesOffSelector],
            [.typeIdentifier: kLigaturesType, .selectorIdentifier: kContextualLigaturesOffSelector]
        ]
        if tabular { features.append([.typeIdentifier: kNumberSpacingType, .selectorIdentifier: kMonospacedNumbersSelector]) }
        return NSFont(descriptor: font.fontDescriptor.addingAttributes([.featureSettings: features]), size: size) ?? font
    }
}
