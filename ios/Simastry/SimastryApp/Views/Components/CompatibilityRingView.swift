import SwiftUI

struct CompatibilityRingView: View {
    let score: Int
    let size: CGFloat
    @State private var animatedProgress: Double = 0

    init(score: Int, size: CGFloat = 56) {
        self.score = score
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SimastryColor.mutedSilver.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(SimastryColor.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(score)%")
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundStyle(SimastryColor.gold)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth)) {
                animatedProgress = Double(score) / 100.0
            }
        }
    }
}
