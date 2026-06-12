import SwiftUI

struct OnboardingProgressView: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let step: Int
    let totalSteps: Int
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(SimastryFont.overline)
                    .tracking(1.8)
                    .foregroundStyle(SimastryColor.gold)

                Spacer()

                Text("Step \(step) of \(totalSteps)")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    let isReached = index + 1 <= step

                    HStack(spacing: 5) {
                        Circle()
                            .fill(isReached ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.14)))
                            .frame(width: 6, height: 6)

                        Text(label)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(isReached ? SimastryColor.offWhite : SimastryColor.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(isReached ? AnyShapeStyle(SimastryColor.gold.opacity(0.12)) : AnyShapeStyle(Color.white.opacity(0.05)), in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(isReached ? SimastryColor.gold.opacity(0.30) : .white.opacity(0.07), lineWidth: 0.6)
                    }
                }
            }
        }
        .padding(18)
        .heroGlass(SimastryColor.gold, cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Step \(step) of \(totalSteps). \(subtitle)")
    }
}
