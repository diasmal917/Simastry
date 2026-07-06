import SwiftUI
import Foundation

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var showResumeLoading = false
    @State private var shouldShowResumeLoadingOnActive = false
    @State private var resumeLoadingTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch viewModel.currentScreen {
                case .landing:
                    LandingView(viewModel: viewModel)
                case .ageGate:
                    AgeGateView(viewModel: viewModel)
                case .firstReadChoice:
                    FirstReadChoiceView(viewModel: viewModel)
                case .firstPrediction:
                    FirstPredictionView(viewModel: viewModel)
                case .firstRead:
                    FirstReadView(viewModel: viewModel)
                case .birthDetails:
                    BirthDetailsView(viewModel: viewModel)
                case .firstExpertRead:
                    FirstExpertReadView(viewModel: viewModel)
                case .signUp:
                    SignUpView(viewModel: viewModel)
                case .signIn:
                    SignInView(viewModel: viewModel)
                case .loading:
                    loadingView
                case .home:
                    MainTabView(viewModel: viewModel)
                }
            }
            .animation(.spring(SimastrySpring.smooth), value: viewModel.currentScreen == .home)

            ToastOverlay(message: $viewModel.toastMessage)

            if showsFloatingOnboardingLanguageMenu {
                VStack {
                    HStack {
                        Spacer()
                        OnboardingLanguageMenu()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 18)

                    Spacer()
                }
                .transition(.opacity)
                .zIndex(5)
            }

            if showResumeLoading {
                ResumeVeilView()
                    .transition(.opacity)
                    .zIndex(20)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            #if DEBUG
            if viewModel.applyDebugPreviewStateIfRequested() {
                return
            }
            #endif

            await viewModel.checkAuthState()
            viewModel.consumePendingShortcutDestination()
            if let pendingDeepLinkURL = AppDelegate.pendingDeepLinkURL {
                AppDelegate.pendingDeepLinkURL = nil
                viewModel.handleDeepLink(pendingDeepLinkURL)
            }
        }
        .onOpenURL { url in
            Task {
                await viewModel.handleIncomingURL(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .simastryDeepLinkReceived)) { notification in
            guard let url = notification.object as? URL else { return }
            viewModel.handleDeepLink(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                shouldShowResumeLoadingOnActive = viewModel.currentScreen != .loading
                AnalyticsService.shared.endSession()
            } else if newPhase == .inactive {
                shouldShowResumeLoadingOnActive = viewModel.currentScreen != .loading
            } else if newPhase == .active {
                resumeLoadingTask?.cancel()
                let shouldVeil = shouldShowResumeLoadingOnActive && viewModel.currentScreen != .loading
                shouldShowResumeLoadingOnActive = false
                resumeLoadingTask = Task { @MainActor in
                    // Delay-to-show: only veil if the refresh actually lags, so a
                    // quick resume never flashes an overlay.
                    let showTask: Task<Void, Never>? = shouldVeil ? Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        if !Task.isCancelled { showResumeVeil() }
                    } : nil
                    // Safety cap so a stalled refresh can never leave the veil stuck.
                    let capTask: Task<Void, Never>? = shouldVeil ? Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1600))
                        if !Task.isCancelled { hideResumeLoading() }
                    } : nil

                    await viewModel.refreshRealtimeSurfaces()
                    viewModel.consumePendingShortcutDestination()

                    showTask?.cancel()
                    capTask?.cancel()
                    hideResumeLoading()
                }
            }
        }
        .onChange(of: viewModel.showUpsell) { _, wantsUpsell in
            guard wantsUpsell, !viewModel.isRevenueCatAvailable else { return }
            viewModel.showUpsell = false
            viewModel.showToast("Beta access active", subtitle: "Purchases are unavailable in this build.", isError: false)
        }
        .sheet(isPresented: upsellBinding) {
            UpsellModalView(viewModel: viewModel)
        }
    }

    private var upsellBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showUpsell && viewModel.isRevenueCatAvailable },
            set: { isPresented in
                if !isPresented {
                    viewModel.showUpsell = false
                }
            }
        )
    }

    private var showsFloatingOnboardingLanguageMenu: Bool {
        switch viewModel.currentScreen {
        case .landing, .ageGate, .firstReadChoice, .firstPrediction, .firstRead, .birthDetails, .firstExpertRead, .signIn, .signUp:
            true
        case .loading, .home:
            false
        }
    }

    private var loadingView: some View {
        SimastryLaunchView(onRetry: {
            Task { await viewModel.checkAuthState() }
        })
    }

    private func showResumeVeil() {
        guard !showResumeLoading else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            showResumeLoading = true
        }
    }

    private func hideResumeLoading() {
        guard showResumeLoading else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showResumeLoading = false
        }
    }
}

struct OnboardingLanguageMenu: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        Menu {
            ForEach(LocalizationManager.Language.allCases) { language in
                Button {
                    HapticManager.buttonPress()
                    localization.currentLanguage = language
                } label: {
                    Label {
                        Text("\(language.shortCode) · \(language.displayName)")
                    } icon: {
                        if language == localization.currentLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(SimastryColor.offWhite)
            .frame(width: 42, height: 42)
            .contentShape(Capsule())
            .simastryGlassPill(interactive: true)
        }
        .menuStyle(.button)
        .accessibilityLabel(localization.string("language.change"))
        .accessibilityValue(localization.currentLanguage.displayName)
    }
}

/// A calm, slowly breathing celestial glow used as the app's loading motif.
/// No spinner gimmick — a soft gold/blue radial glow and a thin ring that
/// expand and fade in a slow ~2.4s cycle. Static when Reduce Motion is on.
struct BreathingCelestialGlow: View {
    var diameter: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SimastryColor.gold.opacity(0.5),
                            SimastryColor.celestialBlue.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: diameter * 0.5
                    )
                )
                .frame(width: diameter, height: diameter)
                .blur(radius: 8)
                .scaleEffect(reduceMotion ? 1.0 : (breathe ? 1.1 : 0.82))
                .opacity(reduceMotion ? 0.85 : (breathe ? 0.95 : 0.5))

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [SimastryColor.gold.opacity(0.7), SimastryColor.celestialBlue.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
                .frame(width: diameter * 0.42, height: diameter * 0.42)
                .scaleEffect(reduceMotion ? 1.0 : (breathe ? 1.05 : 0.92))
                .opacity(reduceMotion ? 0.75 : (breathe ? 0.9 : 0.55))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// Full-screen cold-start launch: the static brand wordmark over a calm
/// zodiac-column illustration, with a timeout/retry fallback if the session check stalls.
struct SimastryLaunchView: View {
    var onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showTimeoutFallback = false

    var body: some View {
        ZStack {
            SimastryColor.pureBlack.ignoresSafeArea()

            CosmicDriftImage(animated: !reduceMotion, imageName: "LoadingZodiacColumns")
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(0.18),
                            .black.opacity(0.08),
                            .black.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

            CosmicDustLayer(animated: !reduceMotion, moteCount: 22)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                SimastryWordmark(font: .system(size: 28, weight: .bold).italic())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .shadow(color: SimastryColor.gold.opacity(0.18), radius: 14, y: 5)
                    .padding(.top, 88)

                Spacer()

                Group {
                    if showTimeoutFallback {
                        timeoutFallback
                    } else {
                        Text("Preparing your session…")
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }
                .transition(.opacity)
                .padding(.bottom, 46)
            }
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.4)) { appeared = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(8))
            withAnimation(.easeOut(duration: 0.3)) { showTimeoutFallback = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading Simastry")
    }

    private var timeoutFallback: some View {
        VStack(spacing: 10) {
            Text("This is taking longer than usual.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
            Text("Check your connection — you can keep waiting or try again.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let onRetry {
                Button(action: onRetry) {
                    Text("Try again")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .goldGlassPill(interactive: true)
                }
                .buttonStyle(SpringPressStyle())
                .padding(.top, 4)
                .accessibilityIdentifier("loading.retryButton")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Brief, non-blocking resume veil. A soft material dim with a small breathing
/// glow — distinct from the cold-start launch. Shown only when a resume refresh
/// actually lags, and dismissed the moment it finishes.
struct ResumeVeilView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            BreathingCelestialGlow(diameter: 88)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.22)) { appeared = true }
        }
        .accessibilityHidden(true)
    }
}
