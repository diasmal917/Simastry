import SwiftUI

struct ZodiacIconView: View {
    let sign: ZodiacSign
    var size: CGFloat
    var showsGlow: Bool = false

    var body: some View {
        Image(sign.iconAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: showsGlow ? sign.color.opacity(0.65) : .clear, radius: showsGlow ? size * 0.22 : 0)
            .accessibilityLabel(sign.displayName)
    }
}
