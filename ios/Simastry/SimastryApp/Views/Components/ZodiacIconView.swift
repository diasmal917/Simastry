import SwiftUI

struct ZodiacIconView: View {
    let sign: ZodiacSign
    var size: CGFloat = 44
    var showsGlow: Bool = true

    var body: some View {
        Image(sign.iconAssetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(
                color: showsGlow ? sign.color.opacity(0.32) : .clear,
                radius: showsGlow ? size * 0.16 : 0,
                x: 0,
                y: showsGlow ? size * 0.06 : 0
            )
            .accessibilityLabel("\(sign.displayName) zodiac icon")
    }
}
