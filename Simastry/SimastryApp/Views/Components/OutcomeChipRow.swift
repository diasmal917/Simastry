import SwiftUI

struct OutcomeChipRow: View {
    let currentOutcome: PredictionOutcome?
    let onSelect: (PredictionOutcome?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            outcomeButton(.landed)
            outcomeButton(.missed)
            if currentOutcome != nil {
                Button("Clear") { onSelect(nil) }
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .buttonStyle(.plain)
            }
        }
    }

    private func outcomeButton(_ outcome: PredictionOutcome) -> some View {
        Button { onSelect(outcome) } label: {
            Label(outcome.title, systemImage: outcome.systemImage)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(currentOutcome == outcome ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(currentOutcome == outcome ? SimastryColor.gold : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
