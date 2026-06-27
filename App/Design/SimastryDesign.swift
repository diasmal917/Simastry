import SwiftUI

/// Central design tokens for Simastry. Kept small and semantic so the whole app
/// shares one spacing / radius / type scale rather than many one-off values.
enum SimastrySpacing {
  static let xs: CGFloat = 6
  static let sm: CGFloat = 10
  static let md: CGFloat = 16
  static let lg: CGFloat = 20
  static let xl: CGFloat = 28
  /// Bottom clearance reserved for the floating glass nav so content never hides behind it.
  static let navClearance: CGFloat = 108
}

/// Consistent continuous corner radii. Spec: 18, 22, 26, 30.
enum SimastryRadius {
  static let chip: CGFloat = 18
  static let card: CGFloat = 22
  static let hero: CGFloat = 26
  static let sheet: CGFloat = 30
}

enum SimastryFont {
  /// Display serif — only for hero/display moments, never body copy.
  static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .serif)
  }
}

extension Color {
  /// Soft gold used sparingly for premium accents.
  static let simastryGold = Color(red: 0.94, green: 0.84, blue: 0.55)
  /// Calm celestial backdrop base.
  static let simastryNight = Color(red: 0.06, green: 0.06, blue: 0.12)
}

/// The shared celestial background. Calm, low-neon, subtle depth.
struct SimastryBackground: View {
  var body: some View {
    LinearGradient(
      colors: [
        Color(red: 0.09, green: 0.08, blue: 0.18),
        Color(red: 0.05, green: 0.05, blue: 0.11),
        Color(red: 0.07, green: 0.06, blue: 0.14)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .overlay(alignment: .topTrailing) {
      Circle()
        .fill(Color.accentColor.opacity(0.18))
        .frame(width: 320, height: 320)
        .blur(radius: 120)
        .offset(x: 90, y: -120)
        .allowsHitTesting(false)
    }
    .overlay(alignment: .bottomLeading) {
      Circle()
        .fill(Color.simastryGold.opacity(0.10))
        .frame(width: 280, height: 280)
        .blur(radius: 120)
        .offset(x: -80, y: 120)
        .allowsHitTesting(false)
    }
    .ignoresSafeArea()
  }
}
