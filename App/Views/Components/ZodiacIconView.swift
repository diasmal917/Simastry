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

/// The refined pastel sign token used across the app (Today tiles, People
/// avatars): a soft pastel disc, dark glyph, one restrained top sheen, and a
/// hairline rim. `tilt` adds the tiles' gentle accessory lean.
struct ZodiacSignToken: View {
    let sign: ZodiacSign
    var size: CGFloat = 52
    var tilt: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [sign.color.opacity(0.95), sign.color.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Text(sign.glyph)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 12/255, green: 11/255, blue: 18/255).opacity(0.82))

            Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.7)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt ? -8 : 0))
        .shadow(color: sign.color.opacity(0.28), radius: size * 0.19, y: 3)
        .accessibilityLabel(sign.displayName)
    }
}
