import SwiftUI

struct ConcentricGoldRings: View {
    let readingChanged: Bool
    @State private var breathing: Bool = false
    @State private var pulse1: CGFloat = 1.0
    @State private var pulse2: CGFloat = 1.0
    @State private var pulse3: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                Circle()
                    .stroke(AstropediaColors.ringStroke, lineWidth: 1)
                    .frame(width: width * 0.6)
                    .scaleEffect(pulse1 * (breathing ? 1.02 : 1.0))

                Circle()
                    .stroke(AstropediaColors.ringStroke, lineWidth: 1)
                    .frame(width: width * 0.75)
                    .scaleEffect(pulse2 * (breathing ? 1.02 : 1.0))

                Circle()
                    .stroke(AstropediaColors.ringStroke, lineWidth: 1)
                    .frame(width: width * 0.9)
                    .scaleEffect(pulse3 * (breathing ? 1.02 : 1.0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 3.0, dampingFraction: 0.5).repeatForever(autoreverses: true), value: breathing)
            .onAppear {
                breathing = true
            }
            .onChange(of: readingChanged) { _, _ in
                triggerPulse()
            }
        }
    }

    private func triggerPulse() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            pulse1 = 1.08
        }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                pulse2 = 1.08
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                pulse3 = 1.08
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                pulse1 = 1.0
                pulse2 = 1.0
                pulse3 = 1.0
            }
        }
    }
}
