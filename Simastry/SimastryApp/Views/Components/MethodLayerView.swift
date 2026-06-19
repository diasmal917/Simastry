import SwiftUI

nonisolated struct MethodSignal: Identifiable {
    let label: String
    let detail: String
    let systemImage: String
    let tint: Color
    let source: String?

    init(
        label: String,
        detail: String,
        systemImage: String,
        tint: Color,
        source: String? = nil
    ) {
        self.label = label
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
        self.source = source
    }

    var id: String { "\(label)-\(detail)-\(systemImage)" }

    var sourceHelp: String {
        if let source, !source.isEmpty {
            return "Source: \(source)"
        }

        let normalized = label.lowercased()
        if normalized.contains("message") {
            return "Source: the pasted or current conversation text."
        }
        if normalized.contains("sun") || normalized.contains("moon") || normalized.contains("rising") || normalized.contains("chart") {
            return "Source: saved birth chart placements."
        }
        if normalized.contains("lens") || normalized.contains("guide") || normalized.contains("companion") {
            return "Source: the selected Simastry guide profile."
        }
        if normalized.contains("privacy") {
            return "Source: Simastry privacy rules for this surface."
        }
        return "Source: the Simastry Method layer for this reading."
    }
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
                    .minimumScaleFactor(0.8)

                // Scales down instead of ellipsizing — "Sagittarius core
                // drive" must never render as "Sagittarius core dr…".
                Text(signal.detail)
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(signal.tint.opacity(0.09), in: .capsule)
        .overlay {
            Capsule()
                .stroke(signal.tint.opacity(0.18), lineWidth: 0.5)
        }
        .help(signal.sourceHelp)
        .accessibilityElement(children: .combine)
        .accessibilityHint(signal.sourceHelp)
    }
}

struct MethodSignalCloud: View {
    let signals: [MethodSignal]

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(signals) { signal in
                MethodSignalChip(signal: signal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

            MethodSignalCloud(signals: signals)

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
        .help("Source details are shown on each signal chip.")
    }
}
