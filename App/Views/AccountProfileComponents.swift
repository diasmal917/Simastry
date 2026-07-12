import SwiftUI

struct AccountProfileSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.textPrimary)
            Text(subtitle)
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AccountProvenanceRow: View {
    let title: String
    let value: String
    let evidence: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: SimastrySpacing.sm) {
            Image(systemName: systemImage)
                .font(SimastryFont.bodySmall.weight(.semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textTertiary)
                Text(value)
                    .font(SimastryFont.bodySmall.weight(.semibold))
                    .foregroundStyle(SimastryColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(evidence)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
