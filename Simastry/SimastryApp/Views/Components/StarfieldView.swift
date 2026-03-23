import SwiftUI

struct StarfieldView: View {
    @State private var stars: [StarParticle] = StarParticle.generateField(count: 50)

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let point = CGPoint(
                    x: star.x * size.width,
                    y: star.y * size.height
                )
                let rect = CGRect(
                    x: point.x - star.size / 2,
                    y: point.y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.opacity = star.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(SimastryColor.gold)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

nonisolated struct StarParticle: Sendable {
    let x: Double
    let y: Double
    let size: Double
    let opacity: Double

    static func generateField(count: Int) -> [StarParticle] {
        (0..<count).map { _ in
            StarParticle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                size: Double.random(in: 0.8...2.5),
                opacity: Double.random(in: 0.08...0.35)
            )
        }
    }
}
