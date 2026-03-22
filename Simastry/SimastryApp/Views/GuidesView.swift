import SwiftUI

nonisolated private enum GuidesSheet: String, Identifiable, Sendable {
    case astropediaLibrary

    var id: String { rawValue }
}

struct GuidesView: View {
    @Bindable var viewModel: AppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedSign: ZodiacSign = .aries
    @State private var activeSheet: GuidesSheet?
    @State private var hasInitialized: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        signPickerSection
                        featuredGuideSection
                        nextStepSection
                        learningSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Guides")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .astropediaLibrary:
                    AstropediaView(viewModel: viewModel)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationContentInteraction(.scrolls)
                }
            }
            .task {
                guard !hasInitialized else { return }
                hasInitialized = true
                selectedSign = defaultSign
            }
            .onChange(of: viewModel.guideFocusSign) { _, newSign in
                if let sign = newSign {
                    withAnimation(sectionAnimation) {
                        selectedSign = sign
                    }
                    viewModel.guideFocusSign = nil
                }
            }
        }
    }

    private var defaultSign: ZodiacSign {
        if let focusSign = viewModel.guideFocusSign {
            viewModel.guideFocusSign = nil
            return focusSign
        }

        if let companionSunSign = viewModel.primaryCompanion.flatMap({ ZodiacSign(rawValue: $0.sunSign) }) {
            return companionSunSign
        }

        if let userSunSign = viewModel.userSunSign {
            return userSunSign
        }

        return .aries
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to talk to every sign")
                .font(.title2.weight(.bold))
                .foregroundStyle(SimastryColor.offWhite)

            Text("Practical communication playbooks — less theory, more how to text them, reach them, and not lose the room.")
                .font(.subheadline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a sign")
                .font(.headline)
                .foregroundStyle(SimastryColor.offWhite)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ZodiacSign.allCases) { sign in
                        Button {
                            HapticManager.zodiacSelection()
                            withAnimation(sectionAnimation) {
                                selectedSign = sign
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(sign.glyph)
                                    .font(SimastryFont.displayMedium)
                                    .foregroundStyle(sign.color)
                                    .frame(width: 48, height: 48)
                                    .background(sign.color.opacity(selectedSign == sign ? 0.22 : 0.10), in: Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(selectedSign == sign ? sign.color.opacity(0.5) : .clear, lineWidth: 2)
                                    }

                                Text(sign.displayName)
                                    .font(SimastryFont.labelSmall)
                                    .foregroundStyle(selectedSign == sign ? sign.color : SimastryColor.mutedSilver)
                            }
                            .frame(width: 62)
                        }
                        .buttonStyle(SpringPressStyle())
                        .accessibilityLabel("\(sign.displayName) guide")
                        .accessibilityHint(selectedSign == sign ? "Currently selected" : "Shows the communication guide")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private var featuredGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(selectedSign.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(selectedSign.color)

                Text(selectedGuideSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
            }

            CommunicationGuideView(sign: selectedSign)
                .id(selectedSign)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        }
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Use this guide")
                .font(.headline)
                .foregroundStyle(SimastryColor.offWhite)

            ViewThatFits {
                HStack(spacing: 12) {
                    nextStepCard(
                        title: "Try Simulate",
                        subtitle: "Test a real conversation with a \(selectedSign.displayName).",
                        systemImage: "wand.and.stars",
                        accent: SimastryColor.risingViolet
                    ) {
                        viewModel.selectedTab = 2
                    }

                    nextStepCard(
                        title: "Open Companions",
                        subtitle: "See how this sign plays out in your dynamic.",
                        systemImage: "sparkles",
                        accent: SimastryColor.sunCoral
                    ) {
                        viewModel.selectedTab = 1
                    }
                }

                VStack(spacing: 12) {
                    nextStepCard(
                        title: "Try Simulate",
                        subtitle: "Test a real conversation with a \(selectedSign.displayName).",
                        systemImage: "wand.and.stars",
                        accent: SimastryColor.risingViolet
                    ) {
                        viewModel.selectedTab = 2
                    }

                    nextStepCard(
                        title: "Open Companions",
                        subtitle: "See how this sign plays out in your dynamic.",
                        systemImage: "sparkles",
                        accent: SimastryColor.sunCoral
                    ) {
                        viewModel.selectedTab = 1
                    }
                }
            }
        }
    }

    private var learningSection: some View {
        Button {
            HapticManager.buttonPress()
            activeSheet = .astropediaLibrary
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.title3)
                    .foregroundStyle(AstropediaColors.gold)
                    .frame(width: 42, height: 42)
                    .background(AstropediaColors.gold.opacity(0.14), in: .rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Astropedia Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("Deeper learning — chart reading, compatibility theory, and more.")
                        .font(.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(SimastryColor.gold)
            }
            .padding(16)
            .simastryGlass(cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
    }

    private var selectedGuideSubtitle: String {
        switch selectedSign.element {
        case .fire:
            return "Best with confidence and directness."
        case .earth:
            return "Best with steadiness and follow-through."
        case .air:
            return "Best with curiosity and lightness."
        case .water:
            return "Best with empathy and emotional safety."
        }
    }

    private var sectionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(SimastrySpring.smooth)
    }

    private func nextStepCard(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tintedGlass(accent.opacity(0.12), cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
    }
}
