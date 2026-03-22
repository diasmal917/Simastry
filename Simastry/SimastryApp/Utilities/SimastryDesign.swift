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
    static let mutedSilver = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let deepMuted = Color(red: 120/255, green: 130/255, blue: 150/255)
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

struct SimastryFont {
    // Display — large titles, hero text
    static let displayLarge = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let displayMedium = Font.system(.title, design: .serif, weight: .bold)

    // Title — section headers, card titles
    static let titleLarge = Font.system(.title2, weight: .semibold)
    static let titleMedium = Font.system(.title3, weight: .semibold)
    static let titleSmall = Font.system(.headline, weight: .semibold)

    // Body — primary content
    static let bodyLarge = Font.system(.body, design: .serif)
    static let bodyMedium = Font.system(.body)
    static let bodySmall = Font.system(.subheadline)

    // Label — UI labels, buttons, metadata
    static let labelLarge = Font.system(.subheadline, weight: .semibold)
    static let labelMedium = Font.system(.footnote, weight: .medium)
    static let labelSmall = Font.system(.caption, weight: .medium)

    // Caption — timestamps, fine print, legal
    static let caption = Font.system(.caption)
    static let captionSmall = Font.system(.caption2)

    // Tracking/uppercase labels
    static let overline = Font.system(.caption2, weight: .medium)
}

struct SkeletonShimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
            }
            .onAppear { phase = 2 }
    }
}

extension View {
    func skeletonShimmer() -> some View {
        modifier(SkeletonShimmer())
    }
}

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let reducedAnimation: Animation?

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}
