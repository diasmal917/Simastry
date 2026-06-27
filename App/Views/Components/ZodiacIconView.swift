import SwiftUI

/// Source of zodiac sign artwork. The app currently renders the bundled
/// `Zodiacs_*` image sets, but routing every glyph through this adapter means
/// an official Zodiac SDK can be dropped in later by swapping
/// `ZodiacIconProvider.current` — no call sites change.
protocol ZodiacIconProviding: Sendable {
    func image(for sign: ZodiacSign) -> Image
}

/// Default provider backed by the in-app asset catalog. This is the stable
/// fallback while the external Zodiac SDK (zodiacs.org/SDK) is unavailable.
struct AssetZodiacIconProvider: ZodiacIconProviding {
    func image(for sign: ZodiacSign) -> Image {
        Image(sign.iconAssetName)
    }
}

/// Single swap point for zodiac artwork. Replace `current` with an
/// SDK-backed provider when the official source comes online.
enum ZodiacIconProvider {
    nonisolated(unsafe) static var current: ZodiacIconProviding = AssetZodiacIconProvider()
}

struct ZodiacIconView: View {
    let sign: ZodiacSign
    var size: CGFloat
    var showsGlow: Bool = false

    var body: some View {
        ZodiacIconProvider.current.image(for: sign)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: showsGlow ? sign.color.opacity(0.65) : .clear, radius: showsGlow ? size * 0.22 : 0)
            .accessibilityLabel(sign.displayName)
    }
}
