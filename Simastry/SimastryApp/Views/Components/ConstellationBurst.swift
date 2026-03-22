import SwiftUI

struct ConstellationBurst: View {
    @State private var particles: [BurstParticle] = []
    @State private var appeared: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(AstropediaColors.gold)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(appeared ? particle.restOpacity : 0)
                        .scaleEffect(appeared ? 1.0 : 0.1)
                        .position(x: particle.x * geo.size.width, y: particle.y * geo.size.height)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.55)
                                .delay(particle.delay),
                            value: appeared
                        )
                }
            }
            .onAppear {
                if particles.isEmpty {
                    generateParticles()
                }
                appeared = true
            }
            .onDisappear {
                appeared = false
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles() {
        particles = (0..<18).map { _ in
            BurstParticle(
                x: Double.random(in: 0.05...0.95),
                y: Double.random(in: 0.05...0.95),
                size: CGFloat.random(in: 2...5),
                restOpacity: Double.random(in: 0.15...0.35),
                delay: Double.random(in: 0...0.4)
            )
        }
    }
}

nonisolated struct BurstParticle: Identifiable, Sendable {
    let id = UUID()
    let x: Double
    let y: Double
    let size: CGFloat
    let restOpacity: Double
    let delay: Double
}
