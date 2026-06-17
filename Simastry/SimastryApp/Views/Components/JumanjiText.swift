import SwiftUI

struct JumanjiText: View {
    let text: String
    @State private var revealedCount: Int = 0
    @State private var hapticCounter: Int = 0

    private var words: [String] {
        text.components(separatedBy: " ")
    }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(AstropediaColors.text)
                    .opacity(revealedCount > index ? 1 : 0)
                    .offset(y: revealedCount > index ? 0 : 4)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.75)
                            .delay(Double(index) * 0.045),
                        value: revealedCount
                    )
            }
        }
        .onChange(of: text) { _, _ in
            revealedCount = 0
            hapticCounter = 0
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                revealedCount = words.count
                fireStaggeredHaptics()
            }
        }
        .onAppear {
            revealedCount = words.count
        }
    }

    private func fireStaggeredHaptics() {
        let totalWords = words.count
        let hapticInterval = max(1, totalWords / 5)
        for i in stride(from: 0, to: totalWords, by: hapticInterval) {
            let delay = Double(i) * 0.045
            Task {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                HapticManager.signConfirmed()
            }
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}
