import SwiftUI

struct UsageRingView: View {
    let used: Int
    let limit: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SimastryColor.mutedSilver.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progress > 0.8 ? SimastryColor.amber : SimastryColor.gold,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(used)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SimastryColor.gold)
                Text("of \(limit) min")
                    .font(.system(size: 10))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
        }
        .frame(width: 72, height: 72)
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth)) {
                animatedProgress = progress
            }
        }
    }
}
