import SwiftUI

struct OnboardingProgressView: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let step: Int
    let totalSteps: Int
    let labels: [String]

    private var progress: Double {
        let safeTotal = max(totalSteps, 1)
        return Double(step) / Double(safeTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(SimastryColor.gold)

                Spacer()

                Text("Step \(step) of \(totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [SimastryColor.gold.opacity(0.95), SimastryColor.amber.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * CGFloat(progress), 10))
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(index + 1 <= step ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(index + 1 <= step ? SimastryColor.gold : .white.opacity(0.06), in: .capsule)
                }
            }
        }
        .padding(18)
        .goldGlassRect(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(SimastryColor.gold.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Step \(step) of \(totalSteps). \(subtitle)")
    }
}
