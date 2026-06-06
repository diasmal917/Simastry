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
                    .font(SimastryFont.overline)
                    .tracking(1.4)
                    .foregroundStyle(SimastryColor.midnight.opacity(0.72))

                Spacer()

                Text("Step \(step) of \(totalSteps)")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.midnight.opacity(0.62))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SimastryFont.titleLarge)
                    .foregroundStyle(SimastryColor.midnight)

                Text(subtitle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.midnight.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SimastryColor.midnight.opacity(0.10))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [SimastryColor.midnight.opacity(0.62), SimastryColor.midnight.opacity(0.42)],
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
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.midnight.opacity(index + 1 <= step ? 0.86 : 0.62))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(index + 1 <= step ? .white.opacity(0.35) : .white.opacity(0.14), in: .capsule)
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
