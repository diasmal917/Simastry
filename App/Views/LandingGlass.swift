import SwiftUI

/// Neutral, iOS-native Liquid Glass for the landing screen's containers.
///
/// Deliberately scoped to the landing (it is intentionally *not* one of the
/// app-wide `simastryGlass` / `heroGlass` styles) so the onboarding can read as
/// understated, ChatGPT-style frosted glass without retinting the rest of the
/// app. Depth comes from translucency, blur, a soft white edge highlight and a
/// faint inner rim — never from color. No gloss, no neon, no candy tint.
///
/// On iOS 26 it uses the real Liquid Glass material (`.glassEffect`); older OSes
/// fall back to `.ultraThinMaterial` with a matching neutral treatment.
enum LandingGlassEmphasis {
    case chip   // small capsules / chips — most subtle
    case card   // panels, reading cards, the action bar
    case cta    // the primary button — a touch more present, and interactive glass
}

private extension LandingGlassEmphasis {
    var tintTop: Double { self == .chip ? 0.04 : 0.05 }          // clear at the top…
    var tintBottom: Double { self == .chip ? 0.12 : 0.16 }       // …to faintly smoky at the bottom (neutral, low-sat)
    var edgeTop: Double { switch self { case .chip: 0.22; case .card: 0.28; case .cta: 0.40 } }
    var borderWidth: CGFloat { switch self { case .chip: 0.6; case .card: 0.8; case .cta: 1.0 } }
    var innerTop: Double { switch self { case .chip: 0.08; case .card: 0.12; case .cta: 0.16 } }
    var shadowOpacity: Double { switch self { case .chip: 0.14; case .card: 0.20; case .cta: 0.26 } }
    var shadowRadius: CGFloat { switch self { case .chip: 9; case .card: 16; case .cta: 16 } }
    var shadowY: CGFloat { switch self { case .chip: 4; case .card: 8; case .cta: 8 } }
    var isInteractive: Bool { self == .cta }
}

struct LandingGlass<S: Shape & InsettableShape>: ViewModifier {
    let shape: S
    var emphasis: LandingGlassEmphasis = .card

    /// Edge highlight matching the app-wide `simastryGlass` hairline so landing
    /// cards read as the same material as every other screen.
    private var edgeHighlight: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(emphasis.edgeTop),
                .white.opacity(emphasis.edgeTop * 0.32),
                .white.opacity(emphasis.edgeTop * 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A faint inner rim just inside the top edge — reads as depth, not shine.
    private var innerHighlight: some View {
        shape
            .inset(by: 1)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(emphasis.innerTop), .clear],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 0.8
            )
            .blur(radius: 0.6)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(SimastryColor.surfaceSunken.opacity(0.30), in: shape)
                .background(SimastryColor.surface.opacity(0.18), in: shape)
                .glassEffect(.regular.tint(SimastryColor.offWhite.opacity(0.085)).interactive(emphasis.isInteractive), in: shape)
                .overlay(shape.strokeBorder(edgeHighlight, lineWidth: emphasis.borderWidth))
                .overlay(innerHighlight)
                .shadow(color: .black.opacity(emphasis.shadowOpacity), radius: emphasis.shadowRadius, y: emphasis.shadowY)
        } else {
            content
                .background(SimastryColor.surface.opacity(0.72), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(edgeHighlight, lineWidth: emphasis.borderWidth))
                .overlay(innerHighlight)
                .shadow(color: .black.opacity(emphasis.shadowOpacity), radius: emphasis.shadowRadius, y: emphasis.shadowY)
        }
    }
}

extension View {
    /// Neutral Liquid Glass card/panel for the landing screen.
    func landingGlass(cornerRadius: CGFloat = 22, emphasis: LandingGlassEmphasis = .card) -> some View {
        modifier(LandingGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), emphasis: emphasis))
    }

    /// Neutral Liquid Glass capsule (chips, pills, the primary CTA) for the landing screen.
    func landingGlassCapsule(emphasis: LandingGlassEmphasis = .chip) -> some View {
        modifier(LandingGlass(shape: Capsule(style: .continuous), emphasis: emphasis))
    }
}
