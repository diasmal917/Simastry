import SwiftUI

/// The guest's first Compass: the real instrument (dial + strip + detail),
/// computed on-device from today's sky with zero personal data, plus three
/// one-tap guest reads that run the same local general-lens engine the old
/// first-prediction form used. No account, no network, no credits — the
/// honest proof-before-signup moment the funnel is built around. Hosted by
/// `AppScreen.firstPrediction` (the routing case predates this view).
struct GuestCompassView: View {
    @Bindable var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dayWindows: DayWindowsResult?
    @State private var computedDayWindowsKey: String?
    @State private var selectedWindowID: String?
    @State private var result: PredictionResult?
    @State private var errorMessage: String?
    @State private var isGenerating = false
    /// One free guest read per session: after it completes, the chips hand
    /// off to sign-up instead of running another read. UX framing, not
    /// enforcement — guests have no persistence to enforce against.
    @State private var hasUsedGuestRead = false
    /// Drives the one-shot entrance stagger, mirroring the authed Compass's
    /// `instrumentAppeared`. Flips false→true exactly once.
    @State private var instrumentAppeared = false

    private let localPredictionService = PredictionService()

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                    guestReveal(header, step: 0)

                    guestReveal(CompassDialFraming(), step: 0)

                    TimelineView(.everyMinute) { context in
                        VStack(alignment: .leading, spacing: SimastrySpacing.md) {
                            guestReveal(
                                CompassNowDial(result: dayWindows, now: context.date, idPrefix: "guestCompass"),
                                step: 1
                            )
                            guestReveal(
                                CompassTodayStrip(
                                    result: dayWindows,
                                    selection: $selectedWindowID,
                                    now: context.date,
                                    idPrefix: "guestCompass"
                                ),
                                step: 2
                            )
                        }
                        .task(id: dayWindowsTaskKey(for: context.date)) {
                            guard computedDayWindowsKey != dayWindowsTaskKey(for: context.date) else { return }
                            await recomputeDayWindows(now: context.date)
                        }
                    }

                    if let selectedWindow {
                        CompassWindowDetailCard(window: selectedWindow, idPrefix: "guestCompass") {
                            withAnimation(reduceMotion ? nil : SimastryMotion.instrumentExit) {
                                selectedWindowID = nil
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top))
                                    .animation(reduceMotion ? nil : SimastryMotion.instrumentEnter),
                                removal: .opacity
                                    .animation(reduceMotion ? nil : SimastryMotion.instrumentExit)
                            )
                        )
                    }

                    guestReveal(CompassBearingsRow(items: guestBearingItems, creditCaption: nil), step: 3)

                    if isGenerating {
                        workingRow
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    guestReveal(signupFooter, step: 4)

                    guestReveal(privacyLine, step: 4)
                }
                .padding(.horizontal, SimastrySpacing.lg)
                .padding(.top, SimastrySpacing.lg)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            instrumentAppeared = true
        }
        .sheet(item: $result, onDismiss: { hasUsedGuestRead = true }) { generated in
            SimulationResultView(result: generated, userSunSign: viewModel.userSunSign)
        }
        .onChange(of: dayWindows) { _, newValue in
            guard let selectedWindowID else { return }
            if newValue?.windows.contains(where: { $0.id == selectedWindowID }) != true {
                self.selectedWindowID = nil
            }
        }
    }

    // MARK: - Sections

    /// The authed Compass's staggered entrance, verbatim: opacity + 8pt
    /// rise on `instrumentEnter` with 50ms steps, opacity-only under Reduce
    /// Motion, one-shot by construction.
    private func guestReveal(_ view: some View, step: Int) -> some View {
        view
            .opacity(instrumentAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (instrumentAppeared ? 0 : 8))
            .animation(
                SimastryMotion.instrumentEnter.delay(reduceMotion ? 0 : Double(step) * 0.05),
                value: instrumentAppeared
            )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            Text("Compass")
                .font(SimastryFont.displayLarge)
                .foregroundStyle(SimastryColor.offWhite)
            Label(localization.string("guestCompass.freeLine"), systemImage: "checkmark.seal")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
    }

    private var workingRow: some View {
        HStack(spacing: SimastrySpacing.sm) {
            ProgressView()
                .tint(SimastryColor.gold)
            Text(localization.string("guestCompass.working"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
    }

    private var signupFooter: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            if hasUsedGuestRead {
                Text(localization.string("guestCompass.oneReadHint"))
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GoldButton(localization.string("guestCompass.keepButton"), isEnabled: !isGenerating) {
                HapticManager.buttonPress()
                goToSignUp()
            }
            .accessibilityIdentifier("guestCompass.keepButton")

            SecondaryButton(title: localization.string("guestCompass.chartButton")) {
                viewModel.continueGuestIntoSetupFlow()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: SimastryIcon.privacy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.78))

            Text(localization.string("guestCompass.privacy"))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Windows

    private var selectedWindow: DayWindow? {
        guard let selectedWindowID, let dayWindows else { return nil }
        return dayWindows.windows.first { $0.id == selectedWindowID }
    }

    private func dayWindowsTaskKey(for date: Date) -> String {
        DailyGuidance.dateKey(for: date)
    }

    @MainActor
    private func recomputeDayWindows(now: Date) async {
        // Guest inputs on purpose: nil natal signs and nil location. The
        // engine's moon-based windows need no personal data, and the
        // provenance gate withholds the natal context line — nothing on
        // this screen implies personalization that does not exist. Style is
        // fixed to practical: the plain-language default, and guests have
        // no style setting yet.
        let inputs = DayWindowsEngine.Inputs(
            date: now,
            timeZone: .current,
            natalSun: nil,
            natalMoon: nil,
            natalRising: nil,
            style: .practical
        )
        dayWindows = await DayWindowsEngine.windows(for: inputs)
        computedDayWindowsKey = dayWindowsTaskKey(for: now)
    }

    // MARK: - Guest bearings

    /// Same deterministic day-picked questions as the authed bearing cards,
    /// drawn from the shared suggested-question banks.
    private func dayPickedQuestion(from category: FutureQuestionCategory, salt: Int) -> String {
        let bank = category.suggestedQuestions
        guard !bank.isEmpty else { return category.defaultQuestion }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return bank[abs(day + salt) % bank.count]
    }

    private var guestBearingItems: [CompassBearingItem] {
        let work = dayPickedQuestion(from: .careerSuccess, salt: 0)
        let love = dayPickedQuestion(from: .loveTiming, salt: 1)
        let money = dayPickedQuestion(from: .moneyDirection, salt: 2)

        return [
            CompassBearingItem(
                id: "guestCompass.bearing.work",
                title: localization.string("guestCompass.bearing.work"),
                question: work,
                systemImage: "briefcase.fill",
                tokenID: "career",
                action: { runGuestBearing(category: .careerSuccess, question: work) }
            ),
            CompassBearingItem(
                id: "guestCompass.bearing.love",
                title: localization.string("guestCompass.bearing.love"),
                question: love,
                systemImage: "heart.fill",
                tokenID: "love",
                action: { runGuestBearing(category: .loveTiming, question: love) }
            ),
            CompassBearingItem(
                id: "guestCompass.bearing.money",
                title: localization.string("guestCompass.bearing.money"),
                question: money,
                systemImage: "banknote.fill",
                tokenID: "money",
                action: { runGuestBearing(category: .moneyDirection, question: money) }
            )
        ]
    }

    /// The one free guest read: the same fully local general-lens engine
    /// `FirstPredictionView` used — `PredictionService` with no reply
    /// channel provably composes on-device (no network, no account, no
    /// credit gate). After the first completed read, chips route to
    /// sign-up.
    private func runGuestBearing(category: FutureQuestionCategory, question: String) {
        guard !isGenerating else { return }
        HapticManager.buttonPress()
        guard !hasUsedGuestRead else {
            goToSignUp()
            return
        }

        isGenerating = true
        errorMessage = nil

        let request = PredictionRequest(
            mode: .whatWillTheySay,
            category: category,
            conversationText: "",
            userSunSign: viewModel.userSunSign,
            userMoonSign: viewModel.userMoonSign,
            userRisingSign: viewModel.userRisingSign,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: question,
            hypotheticalReply: nil
        )

        Task { @MainActor in
            defer { isGenerating = false }
            do {
                result = try await localPredictionService.generatePrediction(request: request, tier: "free")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func goToSignUp() {
        withAnimation(.spring(SimastrySpring.smooth)) {
            viewModel.currentScreen = .signUp
        }
    }
}
