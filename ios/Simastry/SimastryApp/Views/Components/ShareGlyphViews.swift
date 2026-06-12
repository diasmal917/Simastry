import SwiftUI

/// Glyph chrome for share cards. Plain fills only — ImageRenderer flattens
/// materials and glass effects, so share artwork must avoid both.
struct ShareGlyphCircle: View {
    let sign: ZodiacSign
    var circleSize: CGFloat = 58
    var iconSize: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(sign.color.opacity(0.16))
            Circle()
                .strokeBorder(sign.color.opacity(0.45), lineWidth: 1)
            ZodiacIconView(sign: sign, size: iconSize, showsGlow: true)
        }
        .frame(width: circleSize, height: circleSize)
    }
}

/// The Sun · Moon · Rising glyph columns shared across share cards.
struct ShareGlyphTrio: View {
    let sun: ZodiacSign
    let moon: ZodiacSign
    let rising: ZodiacSign
    var circleSize: CGFloat = 58
    var iconSize: CGFloat = 34
    var spacing: CGFloat = 12

    var body: some View {
        HStack(spacing: spacing) {
            column(role: .sun, sign: sun)
            column(role: .moon, sign: moon)
            column(role: .rising, sign: rising)
        }
    }

    private func column(role: CelestialRole, sign: ZodiacSign) -> some View {
        VStack(spacing: 5) {
            ShareGlyphCircle(sign: sign, circleSize: circleSize, iconSize: iconSize)

            Text(role.displayName.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1)
                .foregroundStyle(role.accentColor)

            Text(sign.displayName)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}
