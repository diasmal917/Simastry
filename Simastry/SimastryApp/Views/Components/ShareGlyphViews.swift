import SwiftUI

struct ShareGlyphCircle: View {
    let sign: ZodiacSign
    var circleSize: CGFloat
    var iconSize: CGFloat

    var body: some View {
        ZodiacIconView(sign: sign, size: iconSize, showsGlow: true)
            .frame(width: circleSize, height: circleSize)
            .contentShape(.circle)
            .help("\(sign.displayName) zodiac glyph")
            .accessibilityLabel(sign.displayName)
    }
}

struct ShareGlyphTrio: View {
    let sun: ZodiacSign
    let moon: ZodiacSign
    let rising: ZodiacSign
    var circleSize: CGFloat
    var iconSize: CGFloat
    var spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ShareGlyphCircle(sign: sun, circleSize: circleSize, iconSize: iconSize)
            ShareGlyphCircle(sign: moon, circleSize: circleSize, iconSize: iconSize)
            ShareGlyphCircle(sign: rising, circleSize: circleSize, iconSize: iconSize)
        }
    }
}
