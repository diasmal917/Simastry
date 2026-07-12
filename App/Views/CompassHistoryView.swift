import SwiftUI

struct CompassHistoryView: View {
    @Bindable var viewModel: AppViewModel
    @State private var history: [PredictionResult] = []
    @State private var selectedResult: PredictionResult?
    @State private var showsClearConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SimastrySpacing.sm) {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No readings yet",
                        systemImage: "location.north.circle",
                        description: Text("Ask Compass a question and your reading will appear here.")
                    )
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .padding(.top, 80)
                } else {
                    ForEach(history) { result in
                        historyRow(result)
                    }
                }
            }
            .padding(.horizontal, SimastrySpacing.lg)
            .padding(.vertical, SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.tabBarEndClearance)
        }
        .background { CelestialBackground() }
        .navigationTitle("Reading history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        showsClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear all readings?",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear all readings", role: .destructive) {
                viewModel.predictionService.clearHistory()
                loadHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes reading history stored on this iPhone.")
        }
        .sheet(item: $selectedResult) { result in
            SimulationResultView(
                result: result,
                userSunSign: viewModel.userSunSign,
                onSaveFollowUp: { followUp in
                    viewModel.predictionService.setFollowUp(followUp, for: result.id)
                    viewModel.notificationService.cancelPredictionOutcomeFollowUp()
                    StreakManager.shared.recordMeaningfulAction(.outcomeCheckIn)
                    loadHistory()
                    viewModel.predictFollowUpPending = history.contains {
                        $0.isMessageOutcome && $0.followUp == nil
                    }
                },
                onSetHelpfulness: { helpfulness in
                    viewModel.predictionService.setHelpfulness(helpfulness, for: result.id)
                    loadHistory()
                }
            )
        }
        .task { loadHistory() }
    }

    private func historyRow(_ result: PredictionResult) -> some View {
        HStack(spacing: SimastrySpacing.xs) {
            Button {
                selectedResult = result
            } label: {
                HStack(spacing: SimastrySpacing.sm) {
                    Image(systemName: result.categoryOrDefault.systemImage)
                        .font(.headline)
                        .foregroundStyle(result.categoryOrDefault.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            result.categoryOrDefault.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 13)
                        )

                    VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                        Text(result.historyTitle)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(result.contextQuality?.title ?? "Legacy reading")
                            Text("•")
                            Text(result.createdAt, style: .relative)
                        }
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SimastryColor.deepMuted)
                }
                .padding(SimastrySpacing.sm)
                .contentSurface(cornerRadius: SimastryRadius.medium)
            }
            .buttonStyle(CompassPressStyle())

            Button(role: .destructive) {
                viewModel.predictionService.deleteHistoryItem(id: result.id)
                loadHistory()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(SimastryColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(CompassPressStyle())
            .accessibilityLabel("Delete reading")
        }
    }

    private func loadHistory() {
        history = viewModel.predictionService.loadHistory()
    }
}
