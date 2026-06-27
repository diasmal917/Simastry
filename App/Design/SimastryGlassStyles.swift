import SwiftUI

/// Reusable Liquid Glass surfaces. One small set of modifiers is used everywhere
/// (cards, pills, selected tab capsule, sticky bars) instead of bespoke styles.
///
/// On iOS 26+ these use the native `glassEffect`. On iOS 18 they fall back to
/// `.ultraThinMaterial` with a matching hairline stroke. We never stack an opaque
/// fill *under* real glass — the tint passed in is a light wash only.
extension View {

  /// Non-interactive glass surface for static cards and containers.
  @ViewBuilder
  func glassSurface<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
    modifier(GlassSurface(shape: shape, tint: tint, interactive: false))
  }

  /// Interactive glass for tappable controls (pills, buttons, nav items).
  @ViewBuilder
  func glassControl<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
    modifier(GlassSurface(shape: shape, tint: tint, interactive: true))
  }

  /// Standard app card: hero radius, generous padding, glass surface.
  func glassCard(radius: CGFloat = SimastryRadius.card, tint: Color? = nil) -> some View {
    padding(SimastrySpacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassSurface(in: RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint)
  }
}

private struct GlassSurface<S: Shape>: ViewModifier {
  var shape: S
  var tint: Color?
  var interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      var glass: Glass = .regular
      if let tint { glass = glass.tint(tint.opacity(0.18)) }
      if interactive { glass = glass.interactive() }
      return AnyView(content.glassEffect(glass, in: shape))
    } else {
      return AnyView(
        content
          .background(.ultraThinMaterial, in: shape)
          .overlay(
            shape.strokeBorder(
              LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
            .allowsHitTesting(false)
          )
          .background(
            (tint ?? .clear).opacity(0.16).clipShape(shape)
          )
          .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
      )
    }
  }
}

/// A small Pro chip used at moments of intent (never as a Home hero).
struct ProChip: View {
  var text: String = "Pro"
  var body: some View {
    Label(text, systemImage: "sparkle")
      .font(.caption2.weight(.semibold))
      .labelStyle(.titleAndIcon)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(Color.simastryGold)
      .glassControl(in: Capsule(), tint: .simastryGold)
      .accessibilityLabel("Pro feature")
  }
}
