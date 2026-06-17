import SwiftUI

struct SimastrySpring {
    static let snappy = Spring(response: 0.35, dampingRatio: 0.82)
    static let smooth = Spring(response: 0.55, dampingRatio: 0.86)
    static let bouncy = Spring(response: 0.70, dampingRatio: 0.65)
    static let grounded = Spring(response: 0.45, dampingRatio: 0.90)
    static let drift = Spring(response: 1.20, dampingRatio: 0.95)
}

struct SimastryColor {
    static let ink = Color(red: 6/255, green: 6/255, blue: 8/255)
    static let espresso = Color(red: 37/255, green: 27/255, blue: 22/255)
    static let plum = Color(red: 70/255, green: 42/255, blue: 60/255)
    static let olive = Color(red: 75/255, green: 78/255, blue: 56/255)
    static let rose = Color(red: 190/255, green: 102/255, blue: 104/255)
    static let cream = Color(red: 247/255, green: 239/255, blue: 226/255)
    static let smoke = Color(red: 174/255, green: 164/255, blue: 150/255)

    static let midnight = Color(red: 8/255, green: 8/255, blue: 11/255)
    static let surface = Color(red: 24/255, green: 19/255, blue: 18/255)
    static let gold = Color(red: 221/255, green: 181/255, blue: 102/255)
    static let celestialBlue = Color(red: 74/255, green: 144/255, blue: 217/255)
    static let offWhite = cream
    static let mutedSilver = Color(red: 176/255, green: 168/255, blue: 154/255)
    static let deepMuted = Color(red: 92/255, green: 82/255, blue: 76/255)
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

struct SimastryShellBackground: View {
    var accent: Color = SimastryColor.gold

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SimastryColor.ink,
                    SimastryColor.espresso.opacity(0.92),
                    SimastryColor.ink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 280
            )

            RadialGradient(
                colors: [SimastryColor.plum.opacity(0.22), .clear],
                center: .bottomLeading,
                startRadius: 16,
                endRadius: 360
            )

            StarfieldView()
                .opacity(0.34)
        }
        .ignoresSafeArea()
    }
}

struct CinematicSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SimastryColor.gold)
                .tracking(2.8)

            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(SimastryColor.cream)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    @ViewBuilder
    func liquidGlassSurface(cornerRadius: CGFloat = 16, tint: Color = .clear, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background(tint.opacity(0.12), in: .rect(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func editorialGlassCard(cornerRadius: CGFloat = 22) -> some View {
        if #available(iOS 26.0, *) {
            // Real Liquid Glass refracts the content behind it and supplies its
            // own edge highlight, so we drop the material + manual hairline and
            // keep only a soft ambient shadow plus a warm brand tint.
            self
                .glassEffect(
                    .regular.tint(SimastryColor.gold.opacity(0.06)),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
        } else {
            self
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            SimastryColor.gold.opacity(0.04),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.20), radius: 24, x: 0, y: 14)
        }
    }

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
