import SwiftUI

struct PredictionTopUpView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false
    @State private var isPurchasing: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                if viewModel.isRevenueCatAvailable {
                    packCards
                } else {
                    purchasesUnavailableCard
                }
                upgradePrompt
                bonusBalanceSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .presentationContentInteraction(.scrolls)
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SimastryColor.risingViolet, SimastryColor.celestialBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.variableColor.iterative, isActive: appeared)

            Text("Out of Predictions")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("You've used all your predictions for today. Get more instantly, or upgrade for a higher daily limit.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Pack Cards

    private var packCards: some View {
        VStack(spacing: 14) {
            ForEach(PredictionPack.allCases, id: \.rawValue) { pack in
                packCard(pack)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var purchasesUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Prediction packs unavailable", systemImage: "lock.shield.fill")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Consumable prediction packs will appear here after App Store products are configured. No credits are granted without a verified purchase.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glossyCard(cornerRadius: 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func packCard(_ pack: PredictionPack) -> some View {
        let isRecommended = pack == .medium
        let isBestValue = pack == .large

        return Button {
            Task {
                guard !isPurchasing else { return }
                isPurchasing = true
                await viewModel.purchasePredictionPack(pack)
                isPurchasing = false
                dismiss()
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(pack.count)")
                            .font(SimastryFont.titleLarge)
                            .foregroundStyle(isBestValue ? SimastryColor.gold : SimastryColor.offWhite)

                        Text("predictions")
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    if let savings = pack.savings {
                        Text(savings)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(isBestValue ? Color(red: 20/255, green: 18/255, blue: 12/255) : SimastryColor.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    isBestValue
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [SimastryColor.goldDark, SimastryColor.gold, SimastryColor.goldLight],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        : AnyShapeStyle(SimastryColor.gold.opacity(0.16))
                                )
                            )
                    }
                }

                Spacer()

                Text(pack.price)
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)
            }
            .padding(18)
            .background {
                if isBestValue {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(SimastryColor.gold.opacity(0.04))
                }
            }
            .glossyCard(cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isRecommended || isBestValue
                            ? LinearGradient(
                                colors: [SimastryColor.goldLight.opacity(0.5), SimastryColor.gold.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.clear, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isRecommended || isBestValue ? 1 : 0
                    )
            }
        }
        .buttonStyle(SpringPressStyle())
        .disabled(isPurchasing)
        .opacity(isPurchasing ? 0.6 : 1)
        .accessibilityLabel("Buy \(pack.count) predictions for \(pack.price)")
    }

    // MARK: - Upgrade Prompt

    private var upgradePrompt: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.showUpsell = true
            }
        } label: {
            HStack(spacing: 6) {
                Text("Or upgrade your plan for more daily predictions")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open subscription upgrade options")
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Bonus Balance

    @ViewBuilder
    private var bonusBalanceSection: some View {
        if viewModel.bonusPredictions > 0 {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)

                Text("You have \(viewModel.bonusPredictions) bonus prediction\(viewModel.bonusPredictions == 1 ? "" : "s") remaining")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(14)
            .surfaceCard(cornerRadius: 16, accent: SimastryColor.risingViolet.opacity(0.6))
            .opacity(appeared ? 1 : 0)
        }
    }
}
