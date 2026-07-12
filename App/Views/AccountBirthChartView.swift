import SwiftUI

struct AccountBirthChartView: View {
    @Bindable var viewModel: AppViewModel

    private var birthTimeUnavailable: Bool {
        viewModel.onboardingBirthTimePrecision == .unknown
            || viewModel.natalChartRecord?.birthTimePrecision == .unknown
            || (viewModel.natalChartRecord == nil && viewModel.onboardingBirthTime == nil)
    }

    private var placements: [AccountPlacement] {
        let chart = viewModel.natalChartRecord
        return [
            AccountPlacement(
                role: "Sun",
                sign: viewModel.userSunSign,
                displayValue: chart?.sunEstimate.displayValue,
                systemImage: "sun.max.fill",
                accent: SimastryColor.sunCoral
            ),
            AccountPlacement(
                role: "Moon",
                sign: viewModel.userMoonSign,
                displayValue: chart?.moonEstimate.displayValue,
                systemImage: "moon.stars.fill",
                accent: SimastryColor.celestialBlue
            ),
            AccountPlacement(
                role: "Rising",
                sign: birthTimeUnavailable ? nil : viewModel.userRisingSign,
                displayValue: birthTimeUnavailable ? nil : chart?.risingEstimate?.displayValue,
                systemImage: "sunrise.fill",
                accent: SimastryColor.risingViolet
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                    Text("Your chart can be useful without being complete.")
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text("Simastry shows only placements supported by the birth details on file. A missing birth time means no Rising sign or houses.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: SimastrySpacing.xs) {
                    ForEach(placements) { placement in
                        AccountChartPlacementRow(
                            placement: placement,
                            evidence: placement.displayValue == nil ? "Not available" : viewModel.birthChartProvenance.title
                        )
                    }

                    AccountChartPlacementRow(
                        placement: AccountPlacement(
                            role: "Houses",
                            sign: nil,
                            displayValue: viewModel.natalChartRecord?.houseCusps == nil ? nil : "12 houses",
                            systemImage: "circle.grid.3x3.fill",
                            accent: SimastryColor.gold
                        ),
                        evidence: housesEvidence
                    )
                }
                .padding(SimastrySpacing.md)
                .contentSurface(cornerRadius: SimastryRadius.card, accent: SimastryColor.gold)

                VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
                    Label("Source status", systemImage: "checkmark.shield.fill")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.goldLight)
                    Text(sourceStatusText)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SimastrySpacing.lg)
                .contentSurface(cornerRadius: SimastryRadius.card)

                NavigationLink(value: AccountHubRoute.settings) {
                    Label("Review data controls", systemImage: "hand.raised.fill")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.goldLight)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .interactiveGlass(cornerRadius: SimastryRadius.medium, tint: SimastryColor.gold)
                }
                .buttonStyle(SpringPressStyle())
            }
            .padding(SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("Birth chart")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("accountBirthChart.screen")
    }

    private var housesEvidence: String {
        if viewModel.natalChartRecord?.houseCusps != nil { return "Calculated" }
        return birthTimeUnavailable ? "Birth time required" : "Not yet calculated"
    }

    private var sourceStatusText: String {
        switch viewModel.birthChartProvenance {
        case .calculated:
            "Calculated placements come from the birth details and calculation version saved with this private chart record."
        case .userConfirmed:
            "These placements were confirmed by you and remain distinct from calculated evidence."
        case .previouslySaved:
            "Legacy profile signs remain visible as compatibility data, labeled Previously saved. Confirmed calculation provenance will replace that label after birth details are reviewed."
        case .generalLens:
            "No calculated placements are on file. Simastry can still offer practical guidance without a chart."
        }
    }
}

private struct AccountChartPlacementRow: View {
    let placement: AccountPlacement
    let evidence: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SimastrySpacing.sm) {
                placementIdentity
                Spacer(minLength: SimastrySpacing.xs)
                evidenceText
            }

            VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                placementIdentity
                evidenceText
            }
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private var placementIdentity: some View {
        HStack(spacing: SimastrySpacing.sm) {
            Image(systemName: placement.systemImage)
                .font(SimastryFont.bodyLarge.weight(.semibold))
                .foregroundStyle(placement.sign?.color ?? SimastryColor.textTertiary)
                .frame(width: 36, height: 36)
                .background((placement.sign?.color ?? SimastryColor.textTertiary).opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(placement.role)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textTertiary)
                Text(placement.displayValue ?? "Unavailable")
                    .font(SimastryFont.bodyLarge.weight(.semibold))
                    .foregroundStyle(SimastryColor.textPrimary)
            }
        }
    }

    private var evidenceText: some View {
        Text(evidence)
            .font(SimastryFont.captionSmall.weight(.semibold))
            .foregroundStyle(placement.displayValue == nil ? SimastryColor.amber : SimastryColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
