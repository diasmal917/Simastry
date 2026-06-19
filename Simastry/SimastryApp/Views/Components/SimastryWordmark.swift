import SwiftUI

/// The canonical Simastry brand wordmark: italic, with a blue → violet → red
/// fade and an optional subtle shimmer. Use this everywhere the brand name is
/// shown (landing, loading, age gate, profile, message discovery) so the logo
/// stays consistent in color and font across the app.
///
/// Pass a `font` to control size per context; the italic weight and the fade
/// stay identical everywhere.
struct SimastryWordmark: View {
    var font: Font = .system(.title, weight: .bold).italic()
    var sparkles: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    /// The warm accent the fade resolves to beneath the "stry" letters.
    static let red = Color(red: 240 / 255, green: 92 / 255, blue: 115 / 255)

    /// Blue → violet → red, left to right. The brand's one true wordmark fill.
    static let fade = LinearGradient(
        stops: [
            .init(color: SimastryColor.celestialBlue, location: 0.0),
            .init(color: SimastryColor.risingViolet, location: 0.45),
            .init(color: Color(red: 240 / 255, green: 92 / 255, blue: 115 / 255), location: 1.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        Text("Simastry")
            .font(font)
            .foregroundStyle(SimastryWordmark.fade)
            .overlay {
                if sparkles && !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.75), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: phase * geo.size.width * 1.4)
                        .blendMode(.screen)
                    }
                    .mask { Text("Simastry").font(font) }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard sparkles, !reduceMotion else { return }
                withAnimation(.linear(duration: 2.4).delay(0.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Simastry")
    }
}
