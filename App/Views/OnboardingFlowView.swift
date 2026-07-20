import SwiftUI

/// The setup flow that follows the welcome screen: one meaningful question
/// per screen, ending inside the user's chosen task — never on a completion
/// page. Steps are a NavigationStack path so entering and leaving a screen
/// follow the same spatial route, and progress persists for safe resume.
struct OnboardingFlowView: View {
    @Bindable var viewModel: AppViewModel

    enum Step: Hashable {
        case chartChoice
        case birthDetails
        case chartSummary
        case supportStyle
        case companion
        case person
    }

    @State private var path: [Step] = []
    @State private var restoredResumePoint = false

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingGoalStep(viewModel: viewModel) {
                path.append(.chartChoice)
            }
            .navigationDestination(for: Step.self) { step in
                destination(for: step)
            }
        }
        .tint(SimastryColor.gold)
        .onAppear(perform: restoreResumePointIfNeeded)
        .accessibilityIdentifier("onboarding.flow")
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .chartChoice:
            OnboardingChartChoiceStep(
                viewModel: viewModel,
                onAddChart: { path.append(.birthDetails) },
                onSkip: {
                    viewModel.recordOnboardingChartDecision(added: false)
                    advanceAfterChart()
                }
            )
        case .birthDetails:
            BirthDetailsView(
                viewModel: viewModel,
                onExit: { path.removeAll { $0 == .birthDetails } },
                onCalculated: {
                    viewModel.recordOnboardingChartDecision(added: true)
                    path.append(.chartSummary)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        case .chartSummary:
            OnboardingChartSummaryStep(viewModel: viewModel) {
                advanceAfterChart()
            }
        case .supportStyle:
            OnboardingSupportStyleStep(viewModel: viewModel) {
                path.append(.companion)
            }
        case .companion:
            CompanionChoiceView(viewModel: viewModel) {
                if viewModel.onboardingProgress.goal?.involvesAPerson == true {
                    path.append(.person)
                } else {
                    viewModel.recordOnboardingPerson(nil)
                    viewModel.finishOnboardingFlow()
                }
            }
        case .person:
            OnboardingPersonStep(viewModel: viewModel) {
                viewModel.finishOnboardingFlow()
            }
        }
    }

    /// Support style and companion choice belong to the companion experience.
    /// Under the preserved expert-archive rollback, the flow hands off to the
    /// legacy expert screen after the chart, exactly as before the redesign.
    private func advanceAfterChart() {
        if viewModel.experienceMode.isCompanionExperience {
            path.append(.supportStyle)
        } else {
            withAnimation(SimastryMotion.stateChange) {
                viewModel.currentScreen = .firstExpertRead
            }
        }
    }

    /// Rebuilds the path for an interrupted setup so the user resumes at the
    /// step they left, with everything before it still reachable via back.
    private func restoreResumePointIfNeeded() {
        guard !restoredResumePoint else { return }
        restoredResumePoint = true
        viewModel.restoreOnboardingChartForResume()

        switch viewModel.onboardingProgress.resumeStage {
        case .goal:
            path = []
        case .chart:
            path = [.chartChoice]
        case .supportStyle:
            path = [.chartChoice, .supportStyle]
        case .companion:
            path = [.chartChoice, .supportStyle, .companion]
        case .person:
            path = [.chartChoice, .supportStyle, .companion, .person]
        case .account:
            viewModel.finishOnboardingFlow()
        }
    }
}

// MARK: - Shared step scaffolding

/// One step = one large title, an optional supporting line, and content.
/// Plain ink background; the navigation bar supplies back and spatial
/// continuity. No progress theater, no decorative motion.
private struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            SimastryColor.pureBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                    }

                    content
                        .padding(.top, 28)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// A large native selection row: symbol, title, supporting line. The whole
/// row is one button with a combined accessibility label.
private struct OnboardingSelectionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accessibilityID: String?
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 40, height: 40)
                    .background(SimastryColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(SimastryColor.offWhite)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SimastryColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(SpringPressStyle())
        // The Button combines its texts into one spoken label on its own;
        // adding a custom element here would bury the button trait (and its
        // identifier) inside a plain container.
        .modifier(OptionalAccessibilityID(id: accessibilityID))
    }
}

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

// MARK: - Step 1 · Goal

private struct OnboardingGoalStep: View {
    @Bindable var viewModel: AppViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "What do you need help with?",
            subtitle: "Choose one. Everything else will still be available later."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingGoal.allCases) { goal in
                    OnboardingSelectionRow(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        systemImage: goal.systemImage,
                        accessibilityID: "onboarding.goal.\(goal.rawValue)"
                    ) {
                        viewModel.selectOnboardingGoal(goal)
                        onContinue()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    HapticManager.buttonPress()
                    withAnimation(SimastryMotion.stateChange) {
                        viewModel.currentScreen = .landing
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Back to welcome")
            }
        }
        .accessibilityIdentifier("onboarding.goalStep")
    }
}

// MARK: - Step 2 · Optional chart

private struct OnboardingChartChoiceStep: View {
    @Bindable var viewModel: AppViewModel
    let onAddChart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "Make it personal",
            subtitle: "Your birth chart can help Simastry adapt its language and perspective. It never determines what you—or anyone else—will do."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 10) {
                    Button {
                        HapticManager.buttonPress()
                        onAddChart()
                    } label: {
                        Text("Add my birth details")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("onboarding.chart.add")

                    Button {
                        HapticManager.buttonPress()
                        onSkip()
                    } label: {
                        Text("Continue without a chart")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .simastryGlass(cornerRadius: 24)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("onboarding.chart.skip")
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(SimastryColor.gold.opacity(0.75))
                        .accessibilityHidden(true)

                    Text("Your birth details are private and under your control.")
                        .font(.footnote)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("onboarding.chartStep")
    }
}

// MARK: - Step 2b · Chart summary

/// After calculation: a restrained text summary of Sun, Moon, and Rising.
/// No wheel, no ceremony — the signs read as context the user just earned.
private struct OnboardingChartSummaryStep: View {
    @Bindable var viewModel: AppViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "Your chart context",
            subtitle: "Simastry uses these placements as language and perspective—never as a verdict on you or anyone else."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    placementRow(role: "Sun", sign: viewModel.userSunSign, detail: "How you assert and decide")
                    Divider().overlay(.white.opacity(0.08))
                    placementRow(role: "Moon", sign: viewModel.userMoonSign, detail: "What you need to feel steady")
                    Divider().overlay(.white.opacity(0.08))
                    placementRow(
                        role: "Rising",
                        sign: viewModel.userRisingSign,
                        detail: viewModel.userRisingSign == nil
                            ? "Needs an exact birth time"
                            : "How you come across first"
                    )
                }
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                }

                Button {
                    HapticManager.buttonPress()
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityIdentifier("onboarding.chartSummary.continue")
            }
        }
        .accessibilityIdentifier("onboarding.chartSummaryStep")
    }

    private func placementRow(role: String, sign: ZodiacSign?, detail: String) -> some View {
        HStack(spacing: 12) {
            Text(role)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SimastryColor.mutedSilver)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(sign?.displayName ?? "Not calculated")
                    .font(.headline)
                    .foregroundStyle(sign == nil ? SimastryColor.mutedSilver : SimastryColor.offWhite)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(role): \(sign?.displayName ?? "not calculated"). \(detail)")
    }
}

// MARK: - Step 3 · Support style

private struct OnboardingSupportStyleStep: View {
    @Bindable var viewModel: AppViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "How should your companion support you?",
            subtitle: "Choose what would feel most useful right now. You can change this later."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingSupportStyle.allCases) { style in
                    OnboardingSelectionRow(
                        title: style.title,
                        subtitle: style.subtitle,
                        systemImage: style.systemImage,
                        accessibilityID: "onboarding.style.\(style.rawValue)"
                    ) {
                        viewModel.selectOnboardingSupportStyle(style)
                        onContinue()
                    }
                }
            }
        }
        .accessibilityIdentifier("onboarding.styleStep")
    }
}

// MARK: - Step 5 · Who is this about?

/// Person-centered goals ask for the real person before entering the product.
/// Manual entry only — Contacts permission is never requested here.
private struct OnboardingPersonStep: View {
    @Bindable var viewModel: AppViewModel
    let onContinue: () -> Void

    @State private var showAddPerson = false

    var body: some View {
        OnboardingStepScaffold(
            title: "Who is this about?",
            subtitle: "Saved privately on this iPhone. You can add details or remove them at any time."
        ) {
            VStack(spacing: 10) {
                OnboardingSelectionRow(
                    title: "Add a person",
                    subtitle: "A private record only you can see.",
                    systemImage: "person.badge.plus",
                    accessibilityID: "onboarding.person.add"
                ) {
                    showAddPerson = true
                }

                OnboardingSelectionRow(
                    title: "Not about someone specific",
                    subtitle: "You can add people whenever you like.",
                    systemImage: "arrow.right",
                    accessibilityID: "onboarding.person.skip"
                ) {
                    viewModel.recordOnboardingPerson(nil)
                    onContinue()
                }
            }
        }
        .sheet(
            isPresented: $showAddPerson,
            onDismiss: {
                // Continue only when a person was actually saved; a cancelled
                // sheet returns to the question.
                if viewModel.onboardingProgress.personDecided {
                    onContinue()
                }
            }
        ) {
            AddRelationshipPersonView(viewModel: viewModel) { person, _ in
                viewModel.recordOnboardingPerson(person.id)
            }
            .preferredColorScheme(.dark)
        }
        .accessibilityIdentifier("onboarding.personStep")
    }
}
