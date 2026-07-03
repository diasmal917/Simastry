import SwiftUI

/// Long-term communication read for two charts — commitment styles, how you
/// fight, how you repair, how money talk goes. Reflection, never fate.
struct CoupleReadView: View {
    @Environment(\.dismiss) private var dismiss

    let nameA: String
    let sunA: ZodiacSign
    let nameB: String
    let sunB: ZodiacSign

    private var read: CoupleRead {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return CoupleReadComposer.read(nameA: nameA, sunA: sunA, nameB: nameB, sunB: sunB, seed: dayOfYear)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroCard
                    commitmentCard
                    patternCard(
                        title: "HOW YOU FIGHT",
                        icon: "bolt.horizontal.fill",
                        tint: SimastryColor.amber,
                        body: read.fight
                    )
                    patternCard(
                        title: "THE REPAIR MOVE",
                        icon: "arrow.triangle.merge",
                        tint: SimastryColor.celestialBlue,
                        body: read.repair
                    )
                    patternCard(
                        title: "MONEY TALK",
                        icon: "creditcard.fill",
                        tint: SimastryColor.gold,
                        body: read.moneyTalk
                    )
                    honestyFooter
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Couple Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                signColumn(name: nameA, sign: sunA)

                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SimastryColor.gold)

                signColumn(name: nameB, sign: sunB)

                Spacer()
            }

            Text(read.headline)
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            if let signalLine = read.signalLine {
                VStack(alignment: .leading, spacing: 4) {
                    if let signalName = read.signalName {
                        Text(signalName.uppercased())
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.gold)
                            .tracking(1)
                    }

                    Text(signalLine)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroGlass(SimastryColor.gold, cornerRadius: 22)
    }

    private func signColumn(name: String, sign: ZodiacSign) -> some View {
        HStack(spacing: 8) {
            ShareGlyphCircle(sign: sign, circleSize: 38, iconSize: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(sign.displayName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(sign.color)
            }
        }
    }

    private var commitmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("COMMITMENT STYLES")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            ForEach([read.commitmentA, read.commitmentB], id: \.self) { line in
                Text(line)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private func patternCard(title: String, icon: String, tint: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            Text(body)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: tint.opacity(0.6))
    }

    private var honestyFooter: some View {
        Text("How you two tend to communicate about commitment — not a prediction of where it goes. Patterns, never fate.")
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
