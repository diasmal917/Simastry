import SwiftUI

nonisolated enum OrbState: Sendable {
    case idle, active
}

struct GlossyOrbView: View {
    let signColors: [Color]
    let state: OrbState
    let size: CGFloat

    @State private var breatheScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var rotation: Double = 0

    init(signColors: [Color] = [SimastryColor.gold, SimastryColor.celestialBlue],
         state: OrbState = .idle,
         size: CGFloat = 130) {
        self.signColors = signColors
        self.state = state
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.4),
                            signColors.first ?? SimastryColor.gold,
                            signColors.last ?? SimastryColor.celestialBlue,
                            SimastryColor.midnight.opacity(0.8)
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(rotation))
                )
                .clipShape(Circle())

            if state == .active {
                Circle()
                    .stroke(SimastryColor.gold, lineWidth: 2)
                    .frame(width: size + 12, height: size + 12)
                    .opacity(glowOpacity)

                Circle()
                    .stroke(SimastryColor.gold.opacity(0.3), lineWidth: 1)
                    .frame(width: size + 24, height: size + 24)
                    .opacity(glowOpacity * 0.5)
            }
        }
        .scaleEffect(breatheScale)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        switch state {
        case .idle:
            withAnimation(.spring(SimastrySpring.drift).repeatForever(autoreverses: true)) {
                breatheScale = 1.03
            }
            withAnimation(.spring(response: 3, dampingFraction: 0.95).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        case .active:
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                breatheScale = 1.08
                glowOpacity = 0.8
            }
            withAnimation(.spring(response: 2, dampingFraction: 0.95).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
