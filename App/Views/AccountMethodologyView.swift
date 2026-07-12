import SwiftUI

struct AccountMethodologyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                    Text("Useful first. Astrology optional.")
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text("Simastry separates the information you provide, what can be calculated, and the interpretation offered as a reflective lens.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AccountMethodCard(
                    title: "User-confirmed",
                    detail: "Facts you entered or explicitly confirmed, such as a birthday, place, or the outcome of a conversation.",
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: SimastryColor.celestialBlue
                )

                AccountMethodCard(
                    title: "Calculated",
                    detail: "Placements or timing produced from sufficient birth and transit data. Missing inputs stay missing; they are never guessed.",
                    systemImage: "function",
                    tint: SimastryColor.gold
                )

                AccountMethodCard(
                    title: "General lens",
                    detail: "An interpretation or practical reflection. It can suggest another perspective, but it is not an observed fact or certainty.",
                    systemImage: "sparkles",
                    tint: SimastryColor.risingViolet
                )

                Text("Simastry is for reflection and communication support. It does not replace medical, legal, financial, or mental-health advice.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SimastrySpacing.xs)
            }
            .padding(SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("How Simastry works")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("accountMethodology.screen")
    }
}

private struct AccountMethodCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: SimastrySpacing.md) {
            Image(systemName: systemImage)
                .font(SimastryFont.titleMedium)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.textPrimary)
                Text(detail)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SimastrySpacing.lg)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: tint)
        .accessibilityElement(children: .combine)
    }
}
