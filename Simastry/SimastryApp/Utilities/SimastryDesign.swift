import SwiftUI

struct SimastrySpring {
    static let snappy = Spring(response: 0.35, dampingRatio: 0.82)
    static let smooth = Spring(response: 0.55, dampingRatio: 0.86)
    static let bouncy = Spring(response: 0.70, dampingRatio: 0.65)
    static let grounded = Spring(response: 0.45, dampingRatio: 0.90)
    static let drift = Spring(response: 1.20, dampingRatio: 0.95)
}

struct SimastryColor {
    static let midnight = Color(red: 10/255, green: 14/255, blue: 26/255)
    static let surface = Color(red: 17/255, green: 24/255, blue: 39/255)
    static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
    static let celestialBlue = Color(red: 74/255, green: 144/255, blue: 217/255)
    static let offWhite = Color(red: 240/255, green: 237/255, blue: 230/255)
    static let mutedSilver = Color(red: 122/255, green: 133/255, blue: 153/255)
    static let deepMuted = Color(red: 74/255, green: 85/255, blue: 104/255)
    static let amber = Color(red: 212/255, green: 145/255, blue: 58/255)
    static let sunCoral = Color(red: 232/255, green: 132/255, blue: 90/255)
    static let moonBlue = Color(red: 74/255, green: 144/255, blue: 217/255)
    static let risingViolet = Color(red: 192/255, green: 132/255, blue: 216/255)
}

extension CelestialRole {
    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }
}

extension View {
    @ViewBuilder
    func simastryGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func simastryGlassLight(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color.white.opacity(0.06), in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func simastryGlassPill() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: .capsule)
        }
    }

    @ViewBuilder
    func goldGlassPill() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(SimastryColor.gold), in: .capsule)
        } else {
            self.background(SimastryColor.gold.opacity(0.2), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func goldGlassRect(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(SimastryColor.gold), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(SimastryColor.gold.opacity(0.15), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func tintedGlass(_ color: Color, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(color), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(color.opacity(0.1), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}
