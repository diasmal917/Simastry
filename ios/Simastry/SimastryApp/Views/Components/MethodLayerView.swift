import SwiftUI

nonisolated struct MethodSignal: Identifiable {
    let label: String
    let detail: String
    let systemImage: String
    let tint: Color

    var id: String { "\(label)-\(detail)-\(systemImage)" }
}

struct MethodSignalChip: View {
    let signal: MethodSignal

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: signal.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(signal.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(signal.label)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)

                Text(signal.detail)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(signal.tint.opacity(0.09), in: .capsule)
        .overlay {
            Capsule()
                .stroke(signal.tint.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MethodLayerPanel: View {
    let title: String
    let summary: String
    let signals: [MethodSignal]
    var footer: String?
    var accent: Color = SimastryColor.gold

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.3)
                    .textCase(.uppercase)

                Spacer(minLength: 0)
            }

            Text(summary)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(signals) { signal in
                        MethodSignalChip(signal: signal)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)

            if let footer {
                Text(footer)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .tintedGlass(accent.opacity(0.10), cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(accent.opacity(0.14), lineWidth: 0.5)
        }
    }
}
