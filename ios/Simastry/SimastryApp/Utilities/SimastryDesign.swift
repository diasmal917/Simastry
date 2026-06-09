import SwiftUI

struct SimastrySpacing {
    static let tabBarClearance: CGFloat = 72
}

struct SimastrySpring {
    static let snappy = Spring(response: 0.35, dampingRatio: 0.82)
    static let smooth = Spring(response: 0.55, dampingRatio: 0.86)
    static let bouncy = Spring(response: 0.70, dampingRatio: 0.65)
    static let grounded = Spring(response: 0.45, dampingRatio: 0.90)
    static let drift = Spring(response: 1.20, dampingRatio: 0.95)
}

struct SimastryColor {
    static let midnight = Color(red: 5/255, green: 5/255, blue: 10/255)
    static let pureBlack = Color.black
    static let surface = Color(red: 12/255, green: 14/255, blue: 22/255)
    static let gold = Color(red: 185/255, green: 155/255, blue: 75/255)
    static let goldLight = Color(red: 215/255, green: 185/255, blue: 105/255)
    static let goldDark = Color(red: 145/255, green: 120/255, blue: 55/255)
    static let celestialBlue = Color(red: 74/255, green: 144/255, blue: 217/255)
    static let offWhite = Color(red: 240/255, green: 242/255, blue: 245/255)
    static let mutedSilver = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let deepMuted = Color(red: 135/255, green: 145/255, blue: 165/255)
    static let amber = Color(red: 212/255, green: 145/255, blue: 58/255)
    static let sunCoral = Color(red: 232/255, green: 132/255, blue: 90/255)

    static let risingViolet = Color(red: 192/255, green: 132/255, blue: 216/255)
    static let placeholderLight = Color(red: 197/255, green: 189/255, blue: 179/255)
    static let placeholderDark = Color(red: 168/255, green: 159/255, blue: 149/255)
}

enum SimastryGradient {
    static let gold = LinearGradient(
        colors: [SimastryColor.goldLight, SimastryColor.gold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension CelestialRole {
    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }
}

extension View {
    @ViewBuilder
    func simastryToolbarGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surface.opacity(0.88))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.025)), in: .rect(cornerRadius: 0))
        } else {
            self
                .background(SimastryColor.surface.opacity(0.92))
                .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    func simastryGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surface.opacity(0.78), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.035)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(Color.white.opacity(0.04), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    @ViewBuilder
    func simastryGlassLight(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surface.opacity(0.58), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        } else {
            self
                .background(Color.white.opacity(0.03), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.10), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    @ViewBuilder
    func simastryGlassPill() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surface.opacity(0.74), in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.035)), in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(Color.white.opacity(0.04), in: .capsule)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    @ViewBuilder
    func goldGlassPill() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryGradient.gold, in: Capsule())
                .glassEffect(.regular.tint(SimastryColor.gold.opacity(0.32)), in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.28), SimastryColor.goldDark.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(SimastryColor.gold.opacity(0.15), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [SimastryColor.goldLight.opacity(0.3), SimastryColor.gold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    @ViewBuilder
    func goldGlassRect(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.gold.opacity(0.13), in: .rect(cornerRadius: cornerRadius))
                .background(SimastryColor.surface.opacity(0.84), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(SimastryColor.gold.opacity(0.20)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [SimastryColor.goldLight.opacity(0.26), SimastryColor.gold.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(SimastryColor.gold.opacity(0.08), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [SimastryColor.goldLight.opacity(0.25), SimastryColor.gold.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    @ViewBuilder
    func tintedGlass(_ color: Color, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(SimastryColor.surface.opacity(0.94), in: .rect(cornerRadius: cornerRadius))
                .background(color.opacity(0.025), in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular.tint(color.opacity(0.06)), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.22), .white.opacity(0.055)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            self
                .background(SimastryColor.surface.opacity(0.94), in: .rect(cornerRadius: cornerRadius))
                .background(color.opacity(0.025), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.18), .white.opacity(0.045)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }

    func glossyCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(SimastryColor.surface.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

enum SimastryRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let card: CGFloat = 22
    static let panel: CGFloat = 28
}

struct SimastryFont {
    // Display — large titles, hero text
    static let displayLarge = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let displayMedium = Font.system(.title, design: .default, weight: .semibold)

    // Title — section headers, card titles
    static let titleLarge = Font.system(.title2, weight: .semibold)
    static let titleMedium = Font.system(.title3, weight: .semibold)
    static let titleSmall = Font.system(.headline, weight: .semibold)

    // Body — primary content
    static let bodyLarge = Font.system(.body)
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

enum SimastryDateFormatter {
    static let summaryDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let chatDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let compactDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

struct SpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
    }
}

struct SimastryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SimastryFont.titleSmall)
            .foregroundStyle(SimastryColor.midnight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(SimastryGradient.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: SimastryColor.gold.opacity(0.26), radius: 18, x: 0, y: 10)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SimastryPrimaryButtonStyle {
    static var simastryPrimary: SimastryPrimaryButtonStyle { SimastryPrimaryButtonStyle() }
}

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let reducedAnimation: Animation?

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}
