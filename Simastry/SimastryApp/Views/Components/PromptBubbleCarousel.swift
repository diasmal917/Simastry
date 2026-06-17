import SwiftUI

struct PromptBubbleCarousel: View {
    let prompts: [String]
    let isEnabled: Bool
    var onSelect: (String) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting: Bool = false

    private var rows: [[String]] {
        let firstRow = prompts.enumerated().compactMap { index, prompt in
            index.isMultiple(of: 2) ? prompt : nil
        }
        let secondRow = prompts.enumerated().compactMap { index, prompt in
            index.isMultiple(of: 2) ? nil : prompt
        }
        return [firstRow, secondRow].filter { !$0.isEmpty }
    }

    var body: some View {
        if isEnabled && !prompts.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    bubbleRow(row, index: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                isDrifting = true
            }
            .onDisappear {
                isDrifting = false
            }
        }
    }

    private func bubbleRow(_ prompts: [String], index: Int) -> some View {
        HStack(spacing: 9) {
            ForEach(prompts, id: \.self) { prompt in
                Button {
                    HapticManager.buttonPress()
                    onSelect(prompt)
                } label: {
                    Text(prompt)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.07), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.09), lineWidth: 1)
                        }
                }
                .buttonStyle(SpringPressStyle())
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .offset(x: rowOffset(for: index))
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 5.6 + Double(index) * 0.8).repeatForever(autoreverses: true),
            value: isDrifting
        )
    }

    private func rowOffset(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }
        if index.isMultiple(of: 2) {
            return isDrifting ? -36 : 0
        }
        return isDrifting ? 18 : -24
    }
}
