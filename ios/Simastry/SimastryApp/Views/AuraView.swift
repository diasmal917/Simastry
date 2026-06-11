import SwiftUI
import UIKit

struct AuraView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingInfo = false
    @State private var showingShare = false

    private var auras: [ChartAura] {
        ChartAura.makeAll(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    private var summary: ChartAuraSummary {
        ChartAuraSummary.make(from: auras)
    }

    private var communicationType: CommunicationTypeProfile? {
        CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()
                AuraStarfield()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        auraHero
                        barsCard
                        AuraSummaryCard(summary: summary)
                        methodPanel
                        shareButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Aura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
            .sheet(isPresented: $showingShare) {
                AuraShareSheet(auras: auras, summary: summary)
            }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var rankedAuras: [ChartAura] {
        auras.sorted { $0.strength > $1.strength }
    }

    private var heroSign: ZodiacSign? {
        summary.dominantSign ?? viewModel.userSunSign
    }

    private var heroOrbColors: [Color] {
        let primary = heroSign?.color ?? SimastryColor.gold
        let secondary = rankedAuras
            .dropFirst()
            .first(where: { $0.strength > 0 })?
            .sign.color ?? SimastryColor.celestialBlue
        return [primary, secondary]
    }

    private var heroLevelLine: String {
        guard let heroSign,
              let dominant = rankedAuras.first(where: { $0.sign == heroSign }),
              dominant.strength > 0 else {
            return "Add your chart signals to reveal your aura"
        }
        return "\(heroSign.displayName) · \(dominant.level.rawValue) aura"
    }

    // Compact on purpose: the meters are the point of this screen, so the
    // hero stays short enough that they're visible on open.
    private var auraHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MY AURA")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(1.6)

                    Text(communicationType?.title ?? "Your chart signals")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                if let heroSign {
                    ZodiacIconView(sign: heroSign, size: 38, showsGlow: true)
                        .accessibilityHidden(true)
                }

                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About My Aura")
                .popover(isPresented: $showingInfo) {
                    infoPopover
                        .presentationCompactAdaptation(.popover)
                }
            }

            Text(heroLevelLine)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.92))

            Text("Your chart is the sky you were born under. Your aura is how that sky comes through when you speak.")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(SimastryColor.offWhite.opacity(0.74))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tintedGlass(heroOrbColors.first?.opacity(0.10) ?? SimastryColor.gold.opacity(0.10), cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke((heroOrbColors.first ?? SimastryColor.gold).opacity(0.18), lineWidth: 0.8)
        }
    }

    private var infoPopover: some View {
        Text("Your aura is a visual summary of your chart signals. Sun shows core drive, Moon shows emotional reaction, and Rising shows first response. Simastry translates those signals into communication energy.")
            .font(SimastryFont.bodySmall)
            .foregroundStyle(SimastryColor.offWhite)
            .lineSpacing(3)
            .padding(16)
            .frame(width: 284)
            .presentationBackground(SimastryColor.surface)
    }

    private var methodPanel: some View {
        MethodLayerPanel(
            title: "Why This Aura",
            summary: auraMethodSummary,
            signals: methodSignals,
            footer: "Astronomy calculates placements. Astrology interprets them. Simastry translates them into communication guidance.",
            accent: communicationType?.accent ?? SimastryColor.gold
        )
    }

    private var auraMethodSummary: String {
        if viewModel.hasAuraWalletContext && viewModel.useAuraWalletForAura {
            return "This uses your saved Sun, Moon, and Rising as chart signals. Once the lookup provider is connected, your aura can also reflect the Zodiacs you hold — a display of your collection, never a key to app features."
        }
        return "This uses your saved Sun, Moon, and Rising as chart signals, then maps those placements to sign, element, and modality strengths."
    }

    private var methodSignals: [MethodSignal] {
        var signals: [MethodSignal] = []
        if let sun = viewModel.userSunSign {
            signals.append(MethodSignal(label: "Sun", detail: "\(sun.displayName) core drive", systemImage: "sun.max.fill", tint: sun.color))
        }
        if let moon = viewModel.userMoonSign {
            signals.append(MethodSignal(label: "Moon", detail: "\(moon.displayName) reaction", systemImage: "moon.stars.fill", tint: moon.color))
        }
        if let rising = viewModel.userRisingSign {
            signals.append(MethodSignal(label: "Rising", detail: "\(rising.displayName) first response", systemImage: "arrow.up.right.circle.fill", tint: rising.color))
        }
        if let typeSignal = CommunicationTypeProfile.methodSignal(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            signals.append(typeSignal)
        }
        if viewModel.hasAuraWalletContext && viewModel.useAuraWalletForAura {
            signals.append(MethodSignal(
                label: "Aura wallet",
                detail: "Read-only \(viewModel.auraWalletShortAddress)",
                systemImage: "wallet.pass.fill",
                tint: SimastryColor.gold
            ))
        }
        return signals
    }

    private var barsCard: some View {
        VStack(spacing: 14) {
            ForEach(Array(auras.enumerated()), id: \.element.id) { index, aura in
                AuraRow(aura: aura)
                if index < auras.count - 1 {
                    Divider().overlay(SimastryColor.offWhite.opacity(0.09))
                }
            }
        }
        .padding(16)
        .glossyCard(cornerRadius: 22)
    }

    private var shareButton: some View {
        Button {
            showingShare = true
        } label: {
            Label("Share Aura Card", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.simastryPrimary)
    }
}

private struct AuraSummaryCard: View {
    var summary: ChartAuraSummary

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                Text("Aura overview")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.1)
                    .textCase(.uppercase)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                AuraStatTile(
                    title: "Dominant Aura",
                    value: summary.dominantSign?.displayName ?? "—",
                    sign: summary.dominantSign
                )
                AuraStatTile(
                    title: "Strongest Elements",
                    value: summary.strongestElements.isEmpty
                        ? "—"
                        : summary.strongestElements.map(\.displayName).joined(separator: " + ")
                )
                AuraStatTile(
                    title: "Chart Signals",
                    value: "\(summary.chartSignalCount) of 3"
                )
                AuraStatTile(
                    title: "Lit Bars",
                    value: "\(summary.litBars)"
                )
            }
        }
        .padding(16)
        .glossyCard(cornerRadius: 22)
    }
}

private struct AuraStatTile: View {
    var title: String
    var value: String
    var sign: ZodiacSign?

    init(title: String, value: String, sign: ZodiacSign? = nil) {
        self.title = title
        self.value = value
        self.sign = sign
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.deepMuted)
                .tracking(0.8)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 7) {
                if let sign {
                    ZodiacIconView(sign: sign, size: 24, showsGlow: false)
                }

                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .tintedGlass((sign?.color ?? SimastryColor.gold).opacity(0.08), cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct AuraRow: View {
    var aura: ChartAura
    @State private var showingSignInfo = false

    var body: some View {
        HStack(spacing: 13) {
            Button {
                showingSignInfo = true
            } label: {
                ZodiacIconView(sign: aura.sign, size: 38, showsGlow: aura.strength > 0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About the \(aura.sign.displayName) aura")
            .popover(isPresented: $showingSignInfo) {
                signInfoPopover
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Button {
                        showingSignInfo = true
                    } label: {
                        Text(aura.sign.displayName)
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)

                    Spacer(minLength: 8)

                    AuraLevelBadge(aura: aura)
                }

                AuraTraitsLine(aura: aura)
                AuraBar(aura: aura)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(aura.sign.displayName), \(aura.level.rawValue) aura")
    }

    private var signInfoPopover: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                ZodiacIconView(sign: aura.sign, size: 22, showsGlow: false)
                Text("The \(aura.sign.displayName) aura")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Text(aura.sign.auraDescription)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(aura.level.rawValue) in your chart right now.")
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(aura.strength > 0 ? aura.sign.color : SimastryColor.deepMuted)
        }
        .padding(16)
        .frame(width: 264)
        .presentationBackground(SimastryColor.surface)
        .presentationCompactAdaptation(.popover)
    }
}

private struct AuraTraitsLine: View {
    var aura: ChartAura

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(aura.traits.enumerated()), id: \.offset) { index, trait in
                if index > 0 {
                    Text("·")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                }

                AuraWord(
                    trait: trait,
                    milestone: ChartAuraScale.milestones[index],
                    reached: aura.reached(ChartAuraScale.milestones[index])
                )
            }
            Spacer(minLength: 0)
        }
    }
}

private struct AuraWord: View {
    var trait: AuraTrait
    var milestone: ChartAuraMilestone
    var reached: Bool
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Text(trait.word)
                .font(SimastryFont.captionSmall.weight(reached ? .semibold : .regular))
                .foregroundStyle(reached ? SimastryColor.offWhite : SimastryColor.deepMuted)
                // Dotted underline invites the tap — these words all explain
                // themselves in a popover.
                .underline(pattern: .dot, color: (reached ? SimastryColor.gold : SimastryColor.deepMuted).opacity(0.55))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trait.word), \(reached ? "lit" : "not yet lit")")
        .accessibilityHint(trait.meaning)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(trait.word)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    if reached {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(SimastryColor.gold)
                    }
                }

                Text(trait.meaning)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reached
                    ? "Lit in your aura."
                    : "Lights up at \(milestone.level.rawValue) aura.")
                    .font(SimastryFont.captionSmall.weight(.semibold))
                    .foregroundStyle(reached ? SimastryColor.gold : SimastryColor.deepMuted)
            }
            .padding(16)
            .frame(width: 248)
            .presentationBackground(SimastryColor.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct AuraLevelBadge: View {
    var aura: ChartAura

    var body: some View {
        HStack(spacing: 4) {
            if aura.level == .dominant {
                Image(systemName: "sparkles")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.gold)
            }

            Text(aura.level.rawValue)
                .font(SimastryFont.caption.weight(.semibold))
                .foregroundStyle(aura.strength > 0 ? aura.sign.color : SimastryColor.deepMuted)
        }
    }
}

private struct AuraBar: View {
    var aura: ChartAura
    var height: CGFloat = 14
    var animated = true
    var showMilestones = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: Double = 0

    private var shown: Double { animated ? fill : aura.progress }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay { Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1) }

                if aura.strength > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [aura.sign.color.opacity(0.68), aura.sign.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(height, geo.size.width * shown))
                        .shadow(color: aura.sign.color.opacity(0.46), radius: height * 0.55)
                }
            }
            .overlay {
                if showMilestones {
                    ForEach(ChartAuraScale.milestones) { milestone in
                        AuraMilestoneDot(
                            milestone: milestone,
                            word: word(for: milestone),
                            reached: aura.reached(milestone),
                            barHeight: height
                        )
                        .position(
                            x: min(max(geo.size.width * milestone.progress, height * 0.5), geo.size.width - height * 0.5),
                            y: geo.size.height / 2
                        )
                    }
                }
            }
        }
        .frame(height: height)
        .onAppear {
            guard animated else {
                fill = aura.progress
                return
            }
            if reduceMotion {
                fill = aura.progress
            } else {
                withAnimation(.smooth(duration: 0.72).delay(0.05)) {
                    fill = aura.progress
                }
            }
        }
    }

    private func word(for milestone: ChartAuraMilestone) -> String {
        guard let index = ChartAuraScale.milestones.firstIndex(where: { $0.id == milestone.id }),
              index < aura.traits.count else { return "" }
        return aura.traits[index].word
    }
}

private struct AuraMilestoneDot: View {
    var milestone: ChartAuraMilestone
    var word: String
    var reached: Bool
    var barHeight: CGFloat
    @State private var showing = false

    private var dotSize: CGFloat { max(6, barHeight * 0.62) }

    var body: some View {
        Button {
            showing = true
        } label: {
            Circle()
                .fill(reached ? Color.white : Color.black.opacity(0.35))
                .frame(width: dotSize, height: dotSize)
                .overlay { Circle().strokeBorder(Color.white.opacity(reached ? 0.95 : 0.35), lineWidth: 1) }
                .shadow(color: reached ? Color.white.opacity(0.55) : .clear, radius: 2)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(milestone.level.rawValue) check-in, \(reached ? "reached" : "not reached")")
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(milestone.level.rawValue) aura")
                    .font(SimastryFont.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(SimastryColor.gold)

                Text(reached
                    ? "Reached — \(word) is lit in your aura."
                    : "This lights once your Sun, Moon, Rising, element, or modality gives this sign enough signal.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 248)
            .presentationBackground(SimastryColor.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct AuraShareSheet: View {
    var auras: [ChartAura]
    var summary: ChartAuraSummary

    @Environment(\.dismiss) private var dismiss
    @State private var revealStrength = false
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        AuraShareCard(auras: auras, summary: summary, revealStrength: revealStrength)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [SimastryColor.goldLight.opacity(0.56), SimastryColor.goldDark.opacity(0.24)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 14)

                        Toggle(isOn: $revealStrength) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show aura strength")
                                    .font(SimastryFont.labelLarge)
                                    .foregroundStyle(SimastryColor.offWhite)
                                Text("Off by default. Your exact birth details are never shown.")
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.deepMuted)
                            }
                        }
                        .tint(SimastryColor.gold)
                        .padding(16)
                        .simastryGlass(cornerRadius: 18)

                        if let shareImage {
                            ShareLink(
                                item: shareImage,
                                preview: SharePreview("My Aura", image: shareImage)
                            ) {
                                Label("Share Aura Card", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.simastryPrimary)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
            .task { render() }
            .onChange(of: revealStrength) { _, _ in render() }
        }
        .presentationBackground {
            CelestialBackground()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(
            content: AuraShareCard(auras: auras, summary: summary, revealStrength: revealStrength)
                .frame(width: 380)
        )
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

private struct AuraShareCard: View {
    var auras: [ChartAura]
    var summary: ChartAuraSummary
    var revealStrength: Bool

    /// The user's actual placements, recovered from the aura sources, so the
    /// card can lead with the same glyph trio as the main Simastry card.
    private var chartSigns: (sun: ZodiacSign, moon: ZodiacSign, rising: ZodiacSign)? {
        guard let sun = auras.first(where: { $0.sources.contains(.sun) })?.sign,
              let moon = auras.first(where: { $0.sources.contains(.moon) })?.sign,
              let rising = auras.first(where: { $0.sources.contains(.rising) })?.sign else {
            return nil
        }
        return (sun, moon, rising)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("S I M A S T R Y")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.gold)
                .tracking(2)
                .frame(maxWidth: .infinity)

            Text("My Aura")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(SimastryColor.offWhite)
                .frame(maxWidth: .infinity)

            if let chartSigns {
                ShareGlyphTrio(
                    sun: chartSigns.sun,
                    moon: chartSigns.moon,
                    rising: chartSigns.rising,
                    circleSize: 48,
                    iconSize: 28,
                    spacing: 10
                )
            }

            VStack(spacing: 9) {
                ForEach(auras) { aura in
                    shareRow(aura)
                }
            }
            .padding(.top, 2)

            Divider().overlay(SimastryColor.gold.opacity(0.3))

            HStack(alignment: .top) {
                metric("Dominant", summary.dominantSign?.displayName ?? "—")
                Spacer()
                metric("Signals", "\(summary.chartSignalCount) of 3")
                Spacer()
                metric("Lit bars", "\(summary.litBars)")
            }

            Text(AppConfig.universalLinkHost)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.gold.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                SimastryColor.midnight
                RadialGradient(
                    colors: [SimastryColor.gold.opacity(0.12), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
                RadialGradient(
                    colors: [SimastryColor.risingViolet.opacity(0.13), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 280
                )
            }
        }
    }

    private func shareRow(_ aura: ChartAura) -> some View {
        HStack(spacing: 10) {
            ZodiacIconView(sign: aura.sign, size: 22, showsGlow: false)
            Text(aura.sign.displayName)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(SimastryColor.offWhite)
                .frame(width: 70, alignment: .leading)
            AuraBar(aura: aura, height: 8, animated: false, showMilestones: false)
            Text(revealStrength ? "\(aura.strength)" : aura.level.rawValue)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(aura.strength > 0 ? aura.sign.color : SimastryColor.deepMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(SimastryColor.deepMuted)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct AuraStarfield: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED_C0DE
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((seed >> 11) & 0xFFFFFF) / Double(0xFFFFFF)
            }
            for _ in 0..<90 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.4 + next() * 1.1
                let opacity = 0.05 + next() * 0.30
                let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ChartAura: Identifiable {
    var sign: ZodiacSign
    var strength: Int
    var sources: Set<ChartAuraSource>

    var id: ZodiacSign { sign }
    var level: ChartAuraLevel { ChartAuraScale.level(for: strength) }
    var progress: Double { ChartAuraScale.progress(for: strength) }
    var traits: [AuraTrait] { sign.auraTraits }

    func reached(_ milestone: ChartAuraMilestone) -> Bool {
        strength >= milestone.strength
    }

    static func makeAll(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> [ChartAura] {
        ZodiacSign.allCases.map { sign in
            var score = 0
            var sources: Set<ChartAuraSource> = []

            if let sun {
                if sign == sun {
                    score += 52
                    sources.insert(.sun)
                } else {
                    if sign.element == sun.element { score += 10 }
                    if sign.modality == sun.modality { score += 6 }
                }
            }

            if let moon {
                if sign == moon {
                    score += 36
                    sources.insert(.moon)
                } else {
                    if sign.element == moon.element { score += 8 }
                    if sign.modality == moon.modality { score += 4 }
                }
            }

            if let rising {
                if sign == rising {
                    score += 30
                    sources.insert(.rising)
                } else {
                    if sign.element == rising.element { score += 7 }
                    if sign.modality == rising.modality { score += 4 }
                }
            }

            return ChartAura(sign: sign, strength: min(score, 100), sources: sources)
        }
    }
}

private enum ChartAuraSource: Hashable {
    case sun
    case moon
    case rising
}

private enum ChartAuraLevel: String {
    case quiet = "Quiet"
    case trace = "Trace"
    case present = "Present"
    case clear = "Clear"
    case strong = "Strong"
    case dominant = "Dominant"
}

private struct ChartAuraMilestone: Identifiable {
    var level: ChartAuraLevel
    var strength: Int

    var id: Int { strength }
    var progress: Double { ChartAuraScale.progress(for: strength) }
}

private enum ChartAuraScale {
    static let milestones: [ChartAuraMilestone] = [
        ChartAuraMilestone(level: .clear, strength: 34),
        ChartAuraMilestone(level: .strong, strength: 60),
        ChartAuraMilestone(level: .dominant, strength: 82)
    ]

    static func level(for strength: Int) -> ChartAuraLevel {
        if strength <= 0 { return .quiet }
        if strength < 14 { return .trace }
        if strength < 34 { return .present }
        if strength < 60 { return .clear }
        if strength < 82 { return .strong }
        return .dominant
    }

    static func progress(for strength: Int) -> Double {
        let value = Double(max(0, min(strength, 100)))
        if strength <= 0 { return 0 }
        if strength < 14 { return 0.12 + value / 14 * 0.12 }
        if strength < 34 { return 0.24 + ((value - 14) / 20) * 0.28 }
        if strength < 60 { return 0.52 + ((value - 34) / 26) * 0.26 }
        if strength < 82 { return 0.78 + ((value - 60) / 22) * 0.14 }
        return 0.92 + ((value - 82) / 18) * 0.08
    }
}

private struct ChartAuraSummary {
    var dominantSign: ZodiacSign?
    var strongestElements: [ZodiacElement]
    var chartSignalCount: Int
    var litBars: Int

    static func make(from auras: [ChartAura]) -> ChartAuraSummary {
        let strongest = auras.max { $0.strength < $1.strength }
        let dominantSign = (strongest?.strength ?? 0) > 0 ? strongest?.sign : nil
        var totals: [ZodiacElement: Int] = [:]
        var sourceCount: Set<ChartAuraSource> = []

        for aura in auras {
            totals[aura.sign.element, default: 0] += aura.strength
            sourceCount.formUnion(aura.sources)
        }

        let topTwo = totals
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map(\.key)
        let ordered = ZodiacElement.allCases.filter { topTwo.contains($0) }

        return ChartAuraSummary(
            dominantSign: dominantSign,
            strongestElements: ordered,
            chartSignalCount: sourceCount.count,
            litBars: auras.filter { $0.strength >= ChartAuraScale.milestones.first?.strength ?? 34 }.count
        )
    }
}

private struct AuraTrait {
    var word: String
    var meaning: String
}

private extension ZodiacElement {
    var displayName: String {
        rawValue.capitalized
    }
}

private extension ZodiacSign {
    /// One-paragraph explanation of what this sign's aura is, composed from
    /// its trait words plus an element flavor — shown when the sign is tapped.
    var auraDescription: String {
        let words = auraTraits.map(\.word)
        let flavor: String = switch element {
        case .fire: "heat, momentum, and directness"
        case .earth: "steadiness, proof, and patience"
        case .air: "ideas, questions, and social ease"
        case .water: "feeling, depth, and atmosphere"
        }
        return "The \(displayName) aura runs on \(words[0]), \(words[1]), and \(words[2]). When it's lit in a chart, it colors communication with \(flavor)."
    }

    var auraTraits: [AuraTrait] {
        switch self {
        case .aries:
            [
                AuraTrait(word: "Courage", meaning: "You meet tension directly and name what needs movement."),
                AuraTrait(word: "Action", meaning: "You feel clearest when the next step is visible."),
                AuraTrait(word: "Heat", meaning: "Your presence can bring urgency, drive, and spark.")
            ]
        case .taurus:
            [
                AuraTrait(word: "Stability", meaning: "You help conversations slow down enough to become trustworthy."),
                AuraTrait(word: "Value", meaning: "You notice what is worth keeping, repairing, and protecting."),
                AuraTrait(word: "Beauty", meaning: "Your tone can make steadiness feel sensual and safe.")
            ]
        case .gemini:
            [
                AuraTrait(word: "Curiosity", meaning: "You keep doors open by asking better questions."),
                AuraTrait(word: "Language", meaning: "You metabolize feeling through words, options, and reframes."),
                AuraTrait(word: "Movement", meaning: "Your energy keeps conversations from getting stuck.")
            ]
        case .cancer:
            [
                AuraTrait(word: "Care", meaning: "You sense emotional weather before people say it directly."),
                AuraTrait(word: "Memory", meaning: "You hold subtext, history, and small moments closely."),
                AuraTrait(word: "Protection", meaning: "Your instinct is to shelter what feels vulnerable.")
            ]
        case .leo:
            [
                AuraTrait(word: "Presence", meaning: "Your warmth is felt before the full sentence arrives."),
                AuraTrait(word: "Creativity", meaning: "You turn feeling into expression, humor, and performance."),
                AuraTrait(word: "Radiance", meaning: "Your generosity can make other people feel brave.")
            ]
        case .virgo:
            [
                AuraTrait(word: "Craft", meaning: "You refine a messy exchange until it becomes useful."),
                AuraTrait(word: "Order", meaning: "You lower anxiety by naming details and next steps."),
                AuraTrait(word: "Refinement", meaning: "You notice the small signals other people miss.")
            ]
        case .libra:
            [
                AuraTrait(word: "Harmony", meaning: "You search for the fair tone that keeps both people intact."),
                AuraTrait(word: "Beauty", meaning: "You bring grace, timing, and tact to difficult moments."),
                AuraTrait(word: "Attraction", meaning: "People are drawn to your ease and social intelligence.")
            ]
        case .scorpio:
            [
                AuraTrait(word: "Depth", meaning: "You listen for what sits underneath the message."),
                AuraTrait(word: "Power", meaning: "Your focus is quiet, intense, and hard to ignore."),
                AuraTrait(word: "Truth", meaning: "You prefer emotional honesty over a polished surface.")
            ]
        case .sagittarius:
            [
                AuraTrait(word: "Freedom", meaning: "You need room for honesty, humor, and clean air."),
                AuraTrait(word: "Belief", meaning: "You look for the larger meaning inside a messy exchange."),
                AuraTrait(word: "Expansion", meaning: "You stretch conversations toward more possibility.")
            ]
        case .capricorn:
            [
                AuraTrait(word: "Structure", meaning: "You trust maturity, restraint, and clear expectations."),
                AuraTrait(word: "Time", meaning: "You let serious conversations unfold through proof."),
                AuraTrait(word: "Ambition", meaning: "You want the relationship to become stronger, not louder.")
            ]
        case .aquarius:
            [
                AuraTrait(word: "Future", meaning: "You read patterns from distance and imagine what comes next."),
                AuraTrait(word: "Networks", meaning: "You connect ideas, people, and hidden social currents."),
                AuraTrait(word: "Originality", meaning: "Your best replies leave room for a new frame.")
            ]
        case .pisces:
            [
                AuraTrait(word: "Dream", meaning: "You sense possibility before it has practical language."),
                AuraTrait(word: "Spirit", meaning: "You hear the emotional atmosphere behind the words."),
                AuraTrait(word: "Compassion", meaning: "Your softness can make the truth easier to receive.")
            ]
        }
    }
}
