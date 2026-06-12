import SwiftUI

/// "Did it land?" chips — shared by the prediction history rows and the
/// result sheet so the two surfaces can't drift apart.
struct OutcomeChipRow: View {
    let currentOutcome: PredictionOutcome?
    let onSelect: (PredictionOutcome?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(currentOutcome == nil ? "Did this land?" : "Outcome")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)

            Spacer(minLength: 0)

            chip(.landed)
            chip(.missed)
        }
    }

    private func chip(_ outcome: PredictionOutcome) -> some View {
        let isSelected = currentOutcome == outcome
        let tint = outcome == .landed ? SimastryColor.gold : SimastryColor.deepMuted

        return Button {
            HapticManager.buttonPress()
            onSelect(isSelected ? nil : outcome)
        } label: {
            Label(outcome.title, systemImage: outcome.systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.mutedSilver)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? tint : Color.white.opacity(0.05), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? tint.opacity(0.6) : .white.opacity(0.09), lineWidth: 0.6)
                }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(outcome.title)\(isSelected ? ", selected" : "")")
    }
}
