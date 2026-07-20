import SwiftUI

/// The primary-companion choice during setup. Three recommended companions
/// as swipeable cards with 1:1 finger tracking, a tappable roster for
/// gesture-free navigation, and "See all four" to bring in the last one.
/// Selection is only ever the explicit "Choose <name>" press.
struct CompanionChoiceView: View {
    @Bindable var viewModel: AppViewModel
    /// Called after the explicit choice lands.
    let onChosen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showAllFour = false
    @State private var visibleCardID: CompanionPersonaID?
    @State private var viewedCardIDs: Set<CompanionPersonaID> = []

    private var recommended: [CompanionPersona] {
        viewModel.onboardingRecommendedPersonas
    }

    private var personas: [CompanionPersona] {
        guard showAllFour else { return recommended }
        let remaining = CompanionPersonaRegistry.pilot.filter { persona in
            !recommended.contains(where: { $0.id == persona.id })
        }
        return recommended + remaining
    }

    private var subtitle: String {
        viewModel.hasBirthChartContext
            ? "Recommended from your chart and support style. The choice is always yours."
            : "Recommended from the support style you chose. The choice is always yours."
    }

    var body: some View {
        ZStack {
            SimastryColor.pureBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose who you want beside you")
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                rosterRow
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                cardPager
                    .padding(.top, 14)

                Spacer(minLength: 0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if visibleCardID == nil {
                visibleCardID = personas.first?.id
            }
            recordViewed(visibleCardID)
        }
        .onChange(of: visibleCardID) { _, newValue in
            recordViewed(newValue)
        }
        // No container-level identifier here: an identifier on this ZStack
        // stamps itself onto the roster and See-all-four buttons, hiding
        // their own identifiers from accessibility and UI tests.
    }

    // MARK: - Roster (gesture-free navigation)

    /// Every companion is reachable by a plain tap: portraits jump the pager,
    /// and the trailing control reveals the fourth certified companion.
    private var rosterRow: some View {
        HStack(spacing: 10) {
            ForEach(personas) { persona in
                Button {
                    HapticManager.selection()
                    withAnimation(reduceMotion ? nil : .spring(SimastrySpring.settle)) {
                        visibleCardID = persona.id
                    }
                } label: {
                    Image(persona.profileImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44, alignment: .top)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(
                                visibleCardID == persona.id ? SimastryColor.gold : .white.opacity(0.18),
                                lineWidth: visibleCardID == persona.id ? 2 : 1
                            )
                        }
                        .opacity(visibleCardID == persona.id ? 1 : 0.72)
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Show \(persona.displayName)")
                .accessibilityAddTraits(visibleCardID == persona.id ? .isSelected : [])
                .accessibilityIdentifier("onboarding.companion.roster.\(persona.id.rawValue)")
            }

            Spacer(minLength: 0)

            if !showAllFour {
                Button {
                    HapticManager.buttonPress()
                    withAnimation(reduceMotion ? nil : .spring(SimastrySpring.settle)) {
                        showAllFour = true
                    }
                } label: {
                    Text("See all four")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SimastryColor.offWhite)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .simastryGlassPill(interactive: true)
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityIdentifier("onboarding.companion.seeAllFour")
            }
        }
    }

    // MARK: - Cards

    /// Paged horizontal scroll: native 1:1 tracking with a view-aligned
    /// settle. Everything it does is also possible from the roster above.
    private var cardPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(personas) { persona in
                    companionCard(persona)
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                        .id(persona.id)
                }
            }
            .scrollTargetLayout()
        }
        // Margins, not padding: containerRelativeFrame sizes cards against
        // the container minus these margins, so content never runs past the
        // screen edge.
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visibleCardID)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func companionCard(_ persona: CompanionPersona) -> some View {
        let presentation = CompanionOnboardingPresentation.presentation(for: persona.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 210)
                    .overlay(alignment: .top) {
                        // Top-anchored fill keeps the portrait's face in
                        // frame — same rule the chooser thumbnails follow.
                        Image(persona.cardImageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(persona.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("AI")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(SimastryColor.midnight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(SimastryColor.gold, in: Capsule())

                    Spacer(minLength: 0)

                    // Zodiac stays quiet metadata — a word, not a hero.
                    Text(persona.sign.displayName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(SimastryColor.textTertiary)
                }
                .padding(.top, 14)

                if let presentation {
                    Text(presentation.anchor)
                        .font(.headline)
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    Text(presentation.bestWhen)
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("IN THEIR OWN WORDS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SimastryColor.textTertiary)
                            .tracking(1.1)

                        Text("“\(presentation.sampleResponse)”")
                            .font(.callout)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.92))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 12)
                }

                Button {
                    choose(persona)
                } label: {
                    Text("Choose \(persona.displayName)")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(SpringPressStyle())
                .padding(.top, 16)
                .accessibilityIdentifier("onboarding.companion.choose.\(persona.id.rawValue)")

                Spacer(minLength: 20)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel(persona))
    }

    private func cardAccessibilityLabel(_ persona: CompanionPersona) -> String {
        let presentation = CompanionOnboardingPresentation.presentation(for: persona.id)
        let anchor = presentation?.anchor ?? persona.supportPromise
        let bestWhen = presentation?.bestWhen ?? ""
        return "\(persona.displayName), AI companion. \(persona.sign.displayName). \(anchor) \(bestWhen)"
    }

    // MARK: - Selection

    private func choose(_ persona: CompanionPersona) {
        // The one meaningful commitment haptic in the flow.
        HapticManager.commit()
        viewModel.chooseOnboardingCompanion(persona.id)
        onChosen()
    }

    private func recordViewed(_ id: CompanionPersonaID?) {
        guard let id, !viewedCardIDs.contains(id) else { return }
        viewedCardIDs.insert(id)
        viewModel.analytics.track(.onboardingCompanionViewed, key: "companion", value: id.rawValue)
    }
}
