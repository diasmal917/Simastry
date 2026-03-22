import SwiftUI
import AuthenticationServices
import RevenueCat

@MainActor
@Observable
class AppViewModel {
    var currentScreen: AppScreen = .loading
    var homeSetupPhase: HomeSetupPhase = .modeSelection
    var isAuthenticated: Bool = false
    var profile: UserProfile?
    var companions: [CompanionData] = []
    var selectedMode: CompanionMode = .soulmate

    var userSunSign: ZodiacSign?
    var userMoonSign: ZodiacSign?
    var userRisingSign: ZodiacSign?

    var companionSunSign: ZodiacSign?
    var companionMoonSign: ZodiacSign?
    var companionRisingSign: ZodiacSign?
    var companionName: String = ""
    var companionAppearance: AppearanceStyle = .ethereal

    var onboardingBirthday: Date?
    var onboardingBirthTime: Date?
    var onboardingBirthplace: String?

    var toastMessage: ToastMessage?
    var isDarkMode: Bool = UserDefaults.standard.object(forKey: "simastry_dark_mode") == nil ? true : UserDefaults.standard.bool(forKey: "simastry_dark_mode") {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "simastry_dark_mode")
        }
    }
    var showUpsell: Bool = false
    var selectedTab: Int = 0
    var pendingDeepLinkURL: URL?
    var guideFocusSign: ZodiacSign?

    let supabase = SupabaseService()
    let notificationService = NotificationService()
    let predictionService = PredictionService()

    var hasCompletedSigns: Bool {
        profile?.sunSign != nil && profile?.moonSign != nil && profile?.risingSign != nil
    }

    var hasCompanion: Bool {
        !companions.isEmpty
    }

    var primaryCompanion: CompanionData? {
        companions.first
    }

    var isRevenueCatAvailable: Bool {
        !Config.EXPO_PUBLIC_REVENUECAT_API_KEY.isEmpty
    }

    func checkAuthState() async {
        await notificationService.checkAuthorizationStatus()

        let authed = await supabase.isAuthenticated()
        guard authed else {
            isAuthenticated = false
            profile = nil
            companions = []
            showUpsell = false
            selectedTab = 0
            pendingDeepLinkURL = nil
            guideFocusSign = nil
            resetSetupState()
            homeSetupPhase = .modeSelection
            notificationService.clearScheduledNotifications()
            currentScreen = .landing
            return
        }

        isAuthenticated = true
        await navigateAfterAuth()
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Apple"), isError: true)
                return
            }
            do {
                try await supabase.signInWithApple(idToken: tokenString)
                isAuthenticated = true
                await navigateAfterAuth()
                showToast("Welcome back", subtitle: "You're signed in with Apple", isError: false)
            } catch {
                showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Apple"), isError: true)
            }
        case .failure:
            showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Apple"), isError: true)
        }
    }

    func signInWithGoogle() async {
        do {
            try await supabase.signInWithGoogle()
            // Don't mark authenticated here — OAuth opens a browser.
            // The real session is established when the callback URL fires
            // through handleIncomingURL → handleAuthCallback → checkAuthState.
        } catch {
            showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Google"), isError: true)
        }
    }

    func signInWithEmail(email: String, password: String) async {
        guard let credentials = normalizedCredentials(email: email, password: password) else {
            showToast("Missing details", subtitle: "Enter your email and password", isError: true)
            return
        }

        guard validateEmail(credentials.email) else {
            showToast("Invalid email", subtitle: "Enter a valid email address", isError: true)
            return
        }

        do {
            try await supabase.signInWithEmail(email: credentials.email, password: credentials.password)
            isAuthenticated = true
            await navigateAfterAuth()
            showToast("Welcome back", subtitle: "You're signed in", isError: false)
        } catch {
            showToast("Couldn't sign in", subtitle: emailSignInErrorSubtitle(for: error), isError: true)
        }
    }

    func createAccountWithEmail(email: String, password: String) async {
        guard let credentials = normalizedCredentials(email: email, password: password) else {
            showToast("Missing details", subtitle: "Enter your email and password", isError: true)
            return
        }

        guard validateEmail(credentials.email) else {
            showToast("Invalid email", subtitle: "Enter a valid email address", isError: true)
            return
        }
        if let passwordError = validatePassword(credentials.password) {
            showToast("Weak password", subtitle: passwordError, isError: true)
            return
        }

        do {
            let isAuthenticatedNow = try await supabase.signUpWithEmail(email: credentials.email, password: credentials.password)
            if isAuthenticatedNow {
                isAuthenticated = true
                await navigateAfterAuth()
                showToast("Welcome to Simastry", subtitle: "Your account is ready", isError: false)
            } else {
                showToast("Check your email", subtitle: "Confirm your email to finish creating your account", isError: false)
            }
        } catch {
            showToast("Couldn't create account", subtitle: emailSignUpErrorSubtitle(for: error), isError: true)
        }
    }

    func signOut() async {
        try? await supabase.signOut()
        notificationService.clearScheduledNotifications()
        isAuthenticated = false
        profile = nil
        companions = []
        showUpsell = false
        selectedTab = 0
        pendingDeepLinkURL = nil
        guideFocusSign = nil
        resetSetupState()
        homeSetupPhase = .modeSelection
        currentScreen = .landing
    }

    func handleIncomingURL(_ url: URL) async {
        if supabase.isAuthCallbackURL(url) {
            do {
                try await supabase.handleAuthCallback(url)
                await checkAuthState()
            } catch {
                showToast("Couldn't finish sign-in", subtitle: "Open the link again or try another sign-in method", isError: true)
            }
            return
        }

        handleDeepLink(url)
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "simastry" else { return }

        guard isAuthenticated else {
            pendingDeepLinkURL = url
            return
        }

        switch url.host {
        case "home":
            selectedTab = 0
        case "chat", "companions":
            selectedTab = 1
        case "simulate":
            selectedTab = 2
        case "guides", "astropedia":
            selectedTab = 3
        case "profile":
            selectedTab = 4
        case "upsell":
            showUpsell = true
        default:
            break
        }
    }

    func updateCompatibilityScore(for companion: CompanionData) async {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return }

        var updated = companions[index]
        let newScore = min(98, updated.compatibilityScore + 1)
        guard newScore > updated.compatibilityScore else { return }

        updated.compatibilityScore = newScore
        companions[index] = updated
        do {
            try await supabase.updateCompanion(updated)
        } catch {
            showToast("Couldn't save", subtitle: "Your changes may not be saved. Try again.", isError: true)
        }
    }

    func refreshDashboardData() async {
        await loadProfile()
        await loadCompanions()
        await checkSubscriptionStatus()
        syncHomeSetupPhase()
        await setupNotifications()
    }

    func recordCompanionInteraction(
        with companion: CompanionData,
        title: String = "Spark sent",
        subtitle: String? = nil
    ) async {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return }

        var updated = companions[index]
        let previousLevel = RelationshipLevel(rawValue: updated.relationshipLevel) ?? .stranger

        updated.conversationCount += 1
        if updated.firstConversationAt == nil {
            updated.firstConversationAt = Date()
        }

        let newLevel = RelationshipLevel.from(messageCount: updated.conversationCount)
        updated.relationshipLevel = newLevel.rawValue
        if updated.compatibilityScore < 97 {
            updated.compatibilityScore = min(97, updated.compatibilityScore + 1)
        }

        companions[index] = updated
        do {
            try await supabase.updateCompanion(updated)
        } catch {
            showToast("Couldn't save", subtitle: "Your changes may not be saved. Try again.", isError: true)
        }

        if newLevel.rawValue > previousLevel.rawValue {
            HapticManager.soulFlash()
            showToast("Bond deepened", subtitle: "\(updated.name) reached \(newLevel.name)", isError: false)
        } else {
            showToast(title, subtitle: subtitle ?? "\(updated.name) feels a little closer", isError: false)
        }

        await setupNotifications()
    }

    func checkRelationshipLevelUp(for companion: CompanionData) -> Bool {
        let currentLevel = RelationshipLevel.from(messageCount: companion.conversationCount)
        let previousLevel = RelationshipLevel(rawValue: companion.relationshipLevel) ?? .stranger
        return currentLevel.rawValue > previousLevel.rawValue
    }

    func deleteCompanion(_ companion: CompanionData) async {
        companions.removeAll { $0.id == companion.id }
        do {
            try await supabase.deleteCompanion(id: companion.id)
        } catch {
            // Re-add on failure
            companions.append(companion)
            showToast("Couldn't remove companion", subtitle: "Try again in a moment", isError: true)
        }
        if companions.isEmpty {
            homeSetupPhase = .modeSelection
        }
        await setupNotifications()
    }

    func checkSubscriptionStatus() async {
        guard isRevenueCatAvailable else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateTierFromCustomerInfo(customerInfo)
        } catch {
            // use cached tier
        }
    }

    func updateTierFromCustomerInfo(_ info: CustomerInfo) {
        var newTier = "free"
        if info.entitlements["pro"]?.isActive == true {
            newTier = "pro"
        } else if info.entitlements["plus"]?.isActive == true {
            newTier = "plus"
        }
        if var p = profile, p.tier != newTier {
            p.tier = newTier
            profile = p
            Task {
                do {
                    try await supabase.upsertProfile(p)
                } catch {
                    showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
                }
            }
        }
    }

    func restorePurchases() async {
        guard isRevenueCatAvailable else {
            showToast("Subscriptions unavailable", subtitle: "RevenueCat isn't configured yet", isError: true)
            return
        }

        do {
            let info = try await Purchases.shared.restorePurchases()
            updateTierFromCustomerInfo(info)
            showToast("Purchases restored", subtitle: "Your subscription has been restored", isError: false)
        } catch {
            showToast("Couldn't restore", subtitle: "Try again in a moment", isError: true)
        }
    }

    func applyTierOverride(_ tier: String) async {
        guard var profile else { return }
        profile.tier = tier
        self.profile = profile
        do {
            try await supabase.upsertProfile(profile)
        } catch {
            showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
        }
        await setupNotifications()
    }

    var dailyMessageLimit: Int {
        switch profile?.tier ?? "free" {
        case "plus", "pro": return .max
        default: return 10
        }
    }

    var weeklyPredictionLimit: Int {
        switch profile?.tier ?? "free" {
        case "plus", "pro": return .max
        default: return 3
        }
    }

    var companionLimit: Int {
        switch profile?.tier ?? "free" {
        case "pro": return .max
        case "plus": return 3
        default: return 1
        }
    }

    var remainingDailyMessages: Int {
        guard var p = profile else { return 10 }
        resetDailyIfNeeded(&p)
        return max(0, dailyMessageLimit - p.dailyMessagesUsed)
    }

    var remainingWeeklyPredictions: Int {
        guard var p = profile else { return 3 }
        resetWeeklyIfNeeded(&p)
        return max(0, weeklyPredictionLimit - p.weeklyPredictionsUsed)
    }

    func canSendMessage() -> Bool {
        let tier = profile?.tier ?? "free"
        if tier == "plus" || tier == "pro" { return true }
        return remainingDailyMessages > 0
    }

    func canUsePrediction() -> Bool {
        let tier = profile?.tier ?? "free"
        if tier == "plus" || tier == "pro" { return true }
        return remainingWeeklyPredictions > 0
    }

    func consumeMessage() async {
        guard var p = profile else { return }
        let tier = p.tier
        if tier == "plus" || tier == "pro" { return }
        resetDailyIfNeeded(&p)
        p.dailyMessagesUsed += 1
        profile = p
        do {
            try await supabase.upsertProfile(p)
        } catch {
            showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
        }
    }

    func consumePrediction() async {
        guard var p = profile else { return }
        let tier = p.tier
        if tier == "plus" || tier == "pro" { return }
        resetWeeklyIfNeeded(&p)
        p.weeklyPredictionsUsed += 1
        profile = p
        do {
            try await supabase.upsertProfile(p)
        } catch {
            showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
        }
    }

    func canAddCompanion() -> Bool {
        companions.count < companionLimit
    }

    private func resetDailyIfNeeded(_ p: inout UserProfile) {
        let calendar = Calendar.current
        if let resetDate = p.dailyMessagesResetDate, calendar.isDateInToday(resetDate) {
            return
        }
        p.dailyMessagesUsed = 0
        p.dailyMessagesResetDate = Date()
    }

    private func resetWeeklyIfNeeded(_ p: inout UserProfile) {
        if let resetDate = p.weeklyPredictionsResetDate,
           Date().timeIntervalSince(resetDate) < 7 * 24 * 60 * 60 {
            return
        }
        p.weeklyPredictionsUsed = 0
        p.weeklyPredictionsResetDate = Date()
    }

    func setupNotifications() async {
        guard isAuthenticated else {
            notificationService.clearScheduledNotifications()
            return
        }

        await notificationService.requestProvisionalPermission()
        await notificationService.trackEngagement()
        notificationService.clearScheduledNotifications()

        if let companion = companions.first {
            notificationService.scheduleEveningCheckIn(companionName: companion.name)
            notificationService.scheduleInactiveReEngagement(companionName: companion.name)
        }

        notificationService.scheduleSimulationReminder(companionName: primaryCompanion?.name ?? "")

        if let rising = profile?.risingSign, let tier = profile?.tier {
            notificationService.scheduleDailyTransit(risingSign: rising, tier: tier)
        }
    }

    func navigateAfterAuth() async {
        await loadProfile()
        await loadCompanions()
        await checkSubscriptionStatus()
        syncHomeSetupPhase()
        selectedTab = 0
        currentScreen = .home
        await setupNotifications()

        if let pendingDeepLinkURL {
            self.pendingDeepLinkURL = nil
            handleDeepLink(pendingDeepLinkURL)
        }
    }

    func saveUserSigns() async {
        guard let sun = userSunSign, let moon = userMoonSign, let rising = userRisingSign else { return }
        if var p = profile {
            p.sunSign = sun.rawValue
            p.moonSign = moon.rawValue
            p.risingSign = rising.rawValue
            profile = p
            do {
                try await supabase.upsertProfile(p)
            } catch {
                showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
            }
        } else if let userId = await supabase.currentUserId {
            var p = UserProfile.createDefault(id: userId)
            p.sunSign = sun.rawValue
            p.moonSign = moon.rawValue
            p.risingSign = rising.rawValue
            profile = p
            do {
                try await supabase.upsertProfile(p)
            } catch {
                showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
            }
        }
        await setupNotifications()
    }

    func createCompanion() async {
        guard let sun = companionSunSign, let moon = companionMoonSign,
              let rising = companionRisingSign, !companionName.isEmpty else { return }
        guard canAddCompanion() else {
            showToast("Companion limit reached", subtitle: "Upgrade your plan to add more companions", isError: true)
            showUpsell = true
            return
        }
        let userId = await supabase.currentUserId ?? UUID()
        let companion = CompanionData(
            id: UUID(), userId: userId,
            name: companionName, mode: selectedMode.rawValue,
            sunSign: sun.rawValue, moonSign: moon.rawValue, risingSign: rising.rawValue,
            appearanceStyle: companionAppearance.rawValue,
            conversationCount: 0, firstConversationAt: nil,
            compatibilityScore: ZodiacSign.compatibilityScore(
                userSun: userSunSign ?? .aries,
                userMoon: userMoonSign ?? .aries,
                userRising: userRisingSign ?? .aries,
                companionSun: sun,
                companionMoon: moon,
                companionRising: rising
            ),
            companionMemory: nil, relationshipLevel: 1, createdAt: Date()
        )
        companions.append(companion)
        do {
            try await supabase.insertCompanion(companion)
        } catch {
            showToast("Couldn't create companion", subtitle: "Try again in a moment", isError: true)
            companions.removeAll { $0.id == companion.id }
            return
        }
        syncHomeSetupPhase()
        await setupNotifications()
    }

    func showToast(_ title: String, subtitle: String, isError: Bool = false) {
        if isError {
            HapticManager.errorToast()
        }
        toastMessage = ToastMessage(title: title, subtitle: subtitle, isError: isError)
    }

    private func normalizedCredentials(email: String, password: String) -> (email: String, password: String)? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else { return nil }
        return (normalizedEmail, normalizedPassword)
    }

    private func validateEmail(_ email: String) -> Bool {
        let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return email.wholeMatch(of: emailRegex) != nil
    }

    private func validatePassword(_ password: String) -> String? {
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }

    private func providerErrorSubtitle(for provider: String) -> String {
        "\(provider) sign-in didn't finish. Try again or use another sign-in method."
    }

    private func emailSignInErrorSubtitle(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("email not confirmed") {
            return "Confirm your email first, then try again."
        }
        if message.contains("invalid login credentials") {
            return "Check your email and password, or switch to Create Account if you're new."
        }
        return "Check your details, or use Apple or Google if that's how you signed up."
    }

    private func emailSignUpErrorSubtitle(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("already registered") || message.contains("already been registered") {
            return "That email already has an account. Switch to Sign In instead."
        }
        if message.contains("password") {
            return "Choose a stronger password and try again."
        }
        return "Try again in a moment, or use Apple or Google instead."
    }

    private func syncHomeSetupPhase() {
        if hasCompletedSigns && hasCompanion {
            homeSetupPhase = .complete
        } else {
            homeSetupPhase = .modeSelection
        }
    }

    private func loadProfile() async {
        profile = try? await supabase.fetchProfile()
        if let p = profile {
            userSunSign = p.sunSign.flatMap { ZodiacSign(rawValue: $0) }
            userMoonSign = p.moonSign.flatMap { ZodiacSign(rawValue: $0) }
            userRisingSign = p.risingSign.flatMap { ZodiacSign(rawValue: $0) }
        } else {
            userSunSign = nil
            userMoonSign = nil
            userRisingSign = nil
        }
    }

    private func loadCompanions() async {
        companions = (try? await supabase.fetchCompanions()) ?? []
    }

    private func resetSetupState() {
        userSunSign = nil
        userMoonSign = nil
        userRisingSign = nil
        companionSunSign = nil
        companionMoonSign = nil
        companionRisingSign = nil
        companionName = ""
        companionAppearance = .ethereal
    }
}

nonisolated struct ToastMessage: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let subtitle: String
    let isError: Bool
}
