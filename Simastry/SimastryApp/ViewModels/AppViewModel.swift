import SwiftUI
import AuthenticationServices
import RevenueCat
import WidgetKit

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

    // MARK: - Profile Image (Local Storage)
    // Extension point: When Supabase Storage is configured, extend
    // saveProfileImage/loadProfileImage to upload/download from cloud storage.
    var profileImage: UIImage?
    var profileImageURL: String?
    private let profileImageFileName = "profile_image.jpg"
    private let profileImageURLKey = "simastry_profile_image_url"
    private let socialLinksKey = "socialLinks"
    private let socialDisplayNameKey = "socialDisplayName"
    private let socialBioKey = "socialBio"
    private let isDiscoverableKey = "isDiscoverable"
    private let thirdPartyConsentKey = "thirdPartyDataConsent"

    var companionSunSign: ZodiacSign?
    var companionMoonSign: ZodiacSign?
    var companionRisingSign: ZodiacSign?
    var companionName: String = ""
    var companionAppearance: AppearanceStyle = .ethereal

    var onboardingBirthday: Date?
    var onboardingBirthTime: Date?
    var onboardingBirthplace: String?

    var companionMessages: [CompanionMessage] = []
    var savedGuides: [SavedGuide] = []

    // MARK: - Social Discovery
    var isDiscoverable: Bool = UserDefaults.standard.bool(forKey: "isDiscoverable") {
        didSet {
            UserDefaults.standard.set(isDiscoverable, forKey: isDiscoverableKey)
        }
    }
    var discoveredProfiles: [SocialProfile] = []
    var socialDisplayName: String = UserDefaults.standard.string(forKey: "socialDisplayName") ?? "" {
        didSet {
            UserDefaults.standard.set(socialDisplayName, forKey: socialDisplayNameKey)
        }
    }
    var socialBio: String = UserDefaults.standard.string(forKey: "socialBio") ?? "" {
        didSet {
            UserDefaults.standard.set(socialBio, forKey: socialBioKey)
        }
    }
    var socialLinks: SocialLinks = {
        guard let data = UserDefaults.standard.data(forKey: "socialLinks"),
              let links = try? JSONDecoder().decode(SocialLinks.self, from: data) else {
            return SocialLinks()
        }
        return links
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(socialLinks) {
                UserDefaults.standard.set(data, forKey: socialLinksKey)
            }
        }
    }

    var toastMessage: ToastMessage?
    var isDarkMode: Bool = UserDefaults.standard.object(forKey: "simastry_dark_mode") == nil ? true : UserDefaults.standard.bool(forKey: "simastry_dark_mode") {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "simastry_dark_mode")
        }
    }
    var showUpsell: Bool = false
    var selectedTab: Int = 0
    var pendingDeepLinkURL: URL?
    var pendingDeepLink: DeepLink?
    var guideFocusSign: ZodiacSign?
    var referralInfo: ReferralInfo?

    // MARK: - Safety Gates
    var isAgeVerified: Bool = UserDefaults.standard.bool(forKey: "ageVerified")
    var hasAcceptedThirdPartyConsent: Bool = UserDefaults.standard.bool(forKey: "thirdPartyDataConsent")

    let analytics = AnalyticsService.shared
    let supabase = SupabaseService()
    let notificationService = NotificationService()
    let predictionService = PredictionService()
    let predictionRateLimiter = RateLimiter(config: .init(
        maxPerMinute: AppConfig.predictionRateLimit.perMinute,
        maxPerHour: AppConfig.predictionRateLimit.perHour,
        maxPerDay: AppConfig.predictionRateLimit.perDay
    ))
    private let pendingOnboardingChartKey = "simastry_pending_onboarding_chart"
    private let referralInfoKey = "simastry_referral_info"
    private let companionMessagesKey = "simastry_companion_messages"
    private let lastMessageGenerationKey = "simastry_last_message_generation"

    init() {
        loadReferralInfo()
    }

    // MARK: - Age Verification

    func verifyAge() {
        isAgeVerified = true
        UserDefaults.standard.set(true, forKey: "ageVerified")
    }

    // MARK: - Third-Party Data Consent

    func acceptThirdPartyConsent() {
        hasAcceptedThirdPartyConsent = true
        UserDefaults.standard.set(true, forKey: thirdPartyConsentKey)
    }

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
            pendingDeepLink = nil
            guideFocusSign = nil
            clearAccountScopedLocalState()
            resetSetupState()
            homeSetupPhase = .modeSelection
            notificationService.clearScheduledNotifications()
            currentScreen = .landing
            return
        }

        isAuthenticated = true
        if let userId = await supabase.currentUserId {
            CrashReporter.setUser(id: userId.uuidString)
        }
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
                analytics.track(.signInApple)
                await navigateAfterAuth()
                showToast("Welcome back", subtitle: "You're signed in with Apple", isError: false)
            } catch {
                CrashReporter.log(error, context: "signInWithApple")
                showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Apple"), isError: true)
            }
        case .failure:
            showToast("Couldn't sign in", subtitle: providerErrorSubtitle(for: "Apple"), isError: true)
        }
    }

    func signInWithGoogle() async {
        do {
            try await supabase.signInWithGoogle()
            analytics.track(.signInGoogle)
            // Don't mark authenticated here — OAuth opens a browser.
            // The real session is established when the callback URL fires
            // through handleIncomingURL → handleAuthCallback → checkAuthState.
        } catch {
            CrashReporter.log(error, context: "signInWithGoogle")
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
            analytics.track(.signInEmail)
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
                analytics.track(.signUpEmail)
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
        analytics.track(.signOut)
        do {
            try await supabase.signOut()
        } catch {
            showToast("Couldn't sign out cleanly", subtitle: "We'll still clear this device session now.", isError: true)
        }
        notificationService.clearScheduledNotifications()
        clearPendingOnboardingChart()
        clearAccountScopedLocalState()
        SharedDefaults.clearAll()
        WidgetCenter.shared.reloadAllTimelines()
        isAuthenticated = false
        profile = nil
        companions = []
        showUpsell = false
        selectedTab = 0
        pendingDeepLinkURL = nil
        pendingDeepLink = nil
        guideFocusSign = nil
        resetSetupState()
        homeSetupPhase = .modeSelection
        currentScreen = .landing
    }

    // MARK: - Account Deletion

    func deleteAccount() async {
        var remoteFailures: [String] = []

        if let userId = await supabase.currentUserId {
            do {
                try await supabase.deleteAllCompanions(for: userId.uuidString)
            } catch {
                remoteFailures.append("companions")
                CrashReporter.log(error, context: "deleteAccountCompanions")
            }

            do {
                try await supabase.deleteProfile(for: userId.uuidString)
            } catch {
                remoteFailures.append("profile")
                CrashReporter.log(error, context: "deleteAccountProfile")
            }
        }

        clearAllLocalData()

        do {
            try await supabase.signOut()
        } catch {
            remoteFailures.append("session")
            CrashReporter.log(error, context: "deleteAccountSignOut")
        }

        isAuthenticated = false
        profile = nil
        selectedTab = 0
        companions = []
        showUpsell = false
        pendingDeepLinkURL = nil
        pendingDeepLink = nil
        guideFocusSign = nil
        resetSetupState()
        homeSetupPhase = .modeSelection
        notificationService.clearScheduledNotifications()
        currentScreen = .landing

        if remoteFailures.isEmpty {
            showToast("Data cleared", subtitle: "Your local Simastry data has been removed from this device.", isError: false)
        } else {
            showToast(
                "Local data cleared",
                subtitle: "Some server cleanup may still need support follow-up. Please contact support if you want the account fully removed.",
                isError: true
            )
        }
    }

    private func clearAllLocalData() {
        clearAccountScopedLocalState()

        // Clear UserDefaults
        let keys = ["savedGuides", "simastry_companion_messages", "simastry_profile_image_url",
                    "thirdPartyDataConsent", "isDiscoverable", "simastry_referral_info",
                    "simastry_dark_mode", "appLanguage", "ageVerified",
                    "socialDisplayName", "socialBio", "socialLinks",
                    "positiveActionCount", "lastReviewPromptDate", "reviewPromptCount"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Delete profile image file
        deleteProfileImage()

        // Clear widget data
        SharedDefaults.clearAll()
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
        // Try parsing as a virality deep link (compatibility / guide)
        if let deepLink = DeepLink.from(url: url) {
            navigateToDeepLink(deepLink)
            return
        }

        // Fall back to legacy simple tab-switching links (simastry://home, etc.)
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
        case "messages":
            selectedTab = 2
        case "simulate":
            selectedTab = 3
        case "guides", "astropedia":
            selectedTab = 4
        case "profile":
            selectedTab = 5
        case "upsell":
            showUpsell = true
        default:
            break
        }
    }

    /// Navigates to a parsed `DeepLink`, or stores it as pending when
    /// the user has not yet authenticated (virality funnel).
    func navigateToDeepLink(_ deepLink: DeepLink) {
        guard isAuthenticated else {
            pendingDeepLink = deepLink
            pendingDeepLinkURL = deepLink.customSchemeURL
            return
        }

        pendingDeepLink = nil

        switch deepLink {
        case .compatibility(_, let companionSign):
            // Navigate to the Guides tab and focus on the companion sign
            if let sign = ZodiacSign(rawValue: companionSign) {
                guideFocusSign = sign
            }
            selectedTab = 4

        case .guide(let sign):
            if let zodiac = ZodiacSign(rawValue: sign) {
                guideFocusSign = zodiac
            }
            selectedTab = 4

        case .home:
            selectedTab = 0
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
        updateWidgetData()
        loadMessages()
        generateCompanionMessages()
    }

    // MARK: - Widget Data

    func updateWidgetData() {
        guard let topCompanion = companions.first else {
            // No companions — clear widget data so it shows empty state
            SharedDefaults.clearAll()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let companionSign = ZodiacSign(rawValue: topCompanion.sunSign)
        let userSign = userSunSign

        SharedDefaults.writeCompanionData(
            companionName: topCompanion.name,
            companionSunSign: topCompanion.sunSign,
            companionGlyph: companionSign?.glyph ?? "✦",
            userSunSign: userSign?.rawValue ?? "",
            userGlyph: userSign?.glyph ?? "✦",
            compatibilityScore: topCompanion.compatibilityScore,
            companionId: topCompanion.id.uuidString
        )

        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    func recordCompanionInteraction(
        with companion: CompanionData,
        title: String = "Spark sent",
        subtitle: String? = nil
    ) async -> Bool {
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited sparks.",
                isError: true
            )
            showUpsell = true
            return false
        }

        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return false }

        let original = companions[index]
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
            companions[index] = original
            showToast("Couldn't save", subtitle: "Your changes may not be saved. Try again.", isError: true)
            return false
        }

        await consumeMessage()

        if newLevel.rawValue > previousLevel.rawValue {
            HapticManager.soulFlash()
            showToast("Bond deepened", subtitle: "\(updated.name) reached \(newLevel.name)", isError: false)
        } else {
            showToast(title, subtitle: subtitle ?? "\(updated.name) feels a little closer", isError: false)
        }

        await setupNotifications()
        return true
    }

    func checkRelationshipLevelUp(for companion: CompanionData) -> Bool {
        let currentLevel = RelationshipLevel.from(messageCount: companion.conversationCount)
        let previousLevel = RelationshipLevel(rawValue: companion.relationshipLevel) ?? .stranger
        return currentLevel.rawValue > previousLevel.rawValue
    }

    func deleteCompanion(_ companion: CompanionData) async {
        analytics.track(.companionDeleted)
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
        updateWidgetData()
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
        guard var p = await trackedProfile() else { return }
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
        guard var p = await trackedProfile() else { return }
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
            notificationService.scheduleInactiveReEngagement(companionName: companion.name, userSign: profile?.sunSign ?? "")
        }

        notificationService.scheduleSimulationReminder(companionName: primaryCompanion?.name ?? "")

        if let rising = profile?.risingSign, let tier = profile?.tier {
            notificationService.scheduleDailyTransit(risingSign: rising, tier: tier)
        }
    }

    func navigateAfterAuth() async {
        await loadProfile()
        if shouldPersistPendingBirthChart {
            await saveUserSigns()
        }
        await loadCompanions()
        await checkSubscriptionStatus()
        loadSavedGuides()
        loadProfileImage()
        loadMessages()
        syncHomeSetupPhase()
        selectedTab = 0
        currentScreen = .home
        if homeSetupPhase == .complete {
            analytics.track(.onboardingCompleted)
            ReviewPromptService.shared.recordPositiveAction()
        }
        await setupNotifications()
        updateWidgetData()
        generateCompanionMessages()

        // Resolve any pending deep link from the virality funnel
        if let deepLink = pendingDeepLink {
            self.pendingDeepLink = nil
            self.pendingDeepLinkURL = nil
            navigateToDeepLink(deepLink)
        } else if let pendingDeepLinkURL {
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
                clearPendingOnboardingChart()
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
                clearPendingOnboardingChart()
            } catch {
                showToast("Couldn't save profile", subtitle: "Your changes may not be saved", isError: true)
            }
        }
        await setupNotifications()
    }

    func stageOnboardingBirthChart(_ chart: BirthChartService.BirthChart) {
        userSunSign = chart.sunSign
        userMoonSign = chart.moonSign
        userRisingSign = chart.risingSign
        persistPendingOnboardingChart()
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
            CrashReporter.log(error, context: "createCompanion")
            showToast("Couldn't create companion", subtitle: "Try again in a moment", isError: true)
            companions.removeAll { $0.id == companion.id }
            return
        }
        analytics.track(.companionCreated)
        ReviewPromptService.shared.recordPositiveAction()
        syncHomeSetupPhase()
        await setupNotifications()
        updateWidgetData()
        generateWelcomeMessage(for: companion)
    }

    // MARK: - Social Discovery

    func toggleDiscoverability() {
        guard AppConfig.socialDiscoveryEnabled else {
            isDiscoverable = false
            showToast("Discovery coming soon", subtitle: "We're still finishing the secure profile and messaging backend.", isError: false)
            return
        }
        isDiscoverable.toggle()
        if isDiscoverable {
            createSocialProfile()
        }
        // TODO: Supabase integration — when turning off, set is_visible = false in social_profiles table
        updateSocialProfile()
    }

    func fetchDiscoverableProfiles() {
        guard AppConfig.socialDiscoveryEnabled else {
            discoveredProfiles = []
            return
        }
        // TODO: Supabase integration — replace with:
        // let profiles: [SocialProfile] = try await supabase.client
        //     .from("social_profiles")
        //     .select()
        //     .eq("is_visible", value: true)
        //     .neq("id", value: currentUserId)
        //     .execute()
        //     .value
        discoveredProfiles = generateMockProfiles()
    }

    func createSocialProfile() {
        guard AppConfig.socialDiscoveryEnabled else { return }
        if socialDisplayName.isEmpty {
            socialDisplayName = profile?.displayName ?? "Stargazer"
        }
        // TODO: Supabase integration — insert into social_profiles table:
        // let socialProfile = SocialProfile(
        //     id: profile?.id ?? UUID(),
        //     displayName: socialDisplayName,
        //     sunSign: profile?.sunSign ?? "",
        //     moonSign: profile?.moonSign,
        //     risingSign: profile?.risingSign,
        //     bio: socialBio.isEmpty ? nil : socialBio,
        //     isVisible: true,
        //     createdAt: Date()
        // )
        // try await supabase.client.from("social_profiles").upsert(socialProfile).execute()
    }

    func updateSocialProfile() {
        guard AppConfig.socialDiscoveryEnabled else { return }
        // TODO: Supabase integration — update social_profiles table:
        // try await supabase.client.from("social_profiles")
        //     .update(["display_name": socialDisplayName, "bio": socialBio, "is_visible": isDiscoverable])
        //     .eq("id", value: profile?.id.uuidString ?? "")
        //     .execute()
    }

    func updateSocialLinks(_ links: SocialLinks) {
        socialLinks = links
        updateSocialProfile()
    }

    // MARK: - Discovery "Say Hi" Messaging

    func sendDiscoveryMessage(from profile: SocialProfile) {
        guard AppConfig.socialDiscoveryEnabled else {
            showToast("Discovery preview", subtitle: "Cross-user messaging isn't live yet.", isError: false)
            return
        }
        let compatibility = compatibilityWithUser(for: profile)
        let isSameSign = profile.sunSign == userSunSign?.rawValue
        let isCompat = isElementCompatible(profile)

        let category: String
        if isSameSign {
            category = "same_sign"
        } else if isCompat {
            category = "compatible"
        } else {
            category = "neutral"
        }

        let templates = AstrologyTemplates.discoveryIntroMessages[category] ?? []
        guard !templates.isEmpty else { return }

        let index = abs(profile.id.hashValue) % templates.count
        let template = templates[index]

        let content: String
        if category == "same_sign" {
            let signName = ZodiacSign(rawValue: profile.sunSign)?.displayName ?? profile.sunSign.capitalized
            content = String(format: template, signName)
        } else {
            content = String(format: template, "\(compatibility)")
        }

        let zodiacSign = ZodiacSign(rawValue: profile.sunSign)

        let message = CompanionMessage(
            companionId: profile.id,
            companionName: profile.displayName,
            companionSign: zodiacSign?.displayName ?? profile.sunSign.capitalized,
            content: content,
            timestamp: Date(),
            isRead: false
        )
        companionMessages.insert(message, at: 0)
        saveMessages()
        showToast("Message sent to your inbox!", subtitle: "\(profile.displayName) says hi", isError: false)
    }

    func addCompanionFromDiscovery(_ socialProfile: SocialProfile) async {
        guard canAddCompanion() else {
            showToast("Companion limit reached", subtitle: "Upgrade your plan to add more companions", isError: true)
            showUpsell = true
            return
        }
        guard let sunSign = ZodiacSign(rawValue: socialProfile.sunSign) else { return }
        let moonSign = socialProfile.moonSign.flatMap { ZodiacSign(rawValue: $0) } ?? .aries
        let risingSign = socialProfile.risingSign.flatMap { ZodiacSign(rawValue: $0) } ?? .aries
        companionSunSign = sunSign
        companionMoonSign = moonSign
        companionRisingSign = risingSign
        companionName = socialProfile.displayName
        selectedMode = .simulateAnyone
        await createCompanion()
    }

    func compatibilityWithUser(for socialProfile: SocialProfile) -> Int {
        guard let userSun = userSunSign,
              let userMoon = userMoonSign,
              let userRising = userRisingSign,
              let companionSun = ZodiacSign(rawValue: socialProfile.sunSign) else { return 50 }
        let companionMoon = socialProfile.moonSign.flatMap { ZodiacSign(rawValue: $0) } ?? .aries
        let companionRising = socialProfile.risingSign.flatMap { ZodiacSign(rawValue: $0) } ?? .aries
        return ZodiacSign.compatibilityScore(
            userSun: userSun, userMoon: userMoon, userRising: userRising,
            companionSun: companionSun, companionMoon: companionMoon, companionRising: companionRising
        )
    }

    func elementCompatibilityOneLiner(for socialProfile: SocialProfile) -> String {
        guard let userSun = userSunSign,
              let companionSun = ZodiacSign(rawValue: socialProfile.sunSign) else {
            return "A cosmic connection written in the stars"
        }
        return AstrologyTemplates.elementPairingText(
            element1: userSun.element.rawValue,
            element2: companionSun.element.rawValue
        )
    }

    func isElementCompatible(_ socialProfile: SocialProfile) -> Bool {
        guard let userSun = userSunSign,
              let companionSun = ZodiacSign(rawValue: socialProfile.sunSign) else { return false }
        let compatiblePairs: Set<Set<ZodiacElement>> = [
            [.fire, .air], [.earth, .water], [.fire, .fire],
            [.earth, .earth], [.air, .air], [.water, .water]
        ]
        return compatiblePairs.contains([userSun.element, companionSun.element])
    }

    private func generateMockProfiles() -> [SocialProfile] {
        let names = ["Alex", "Jordan", "Sam", "Riley", "Casey", "Morgan", "Taylor", "Quinn", "Avery", "Sage", "River", "Phoenix"]
        let signs = ZodiacSign.allCases
        return names.enumerated().map { index, name in
            SocialProfile(
                id: UUID(),
                displayName: name,
                sunSign: signs[index % signs.count].rawValue,
                moonSign: signs[(index + 4) % signs.count].rawValue,
                risingSign: signs[(index + 8) % signs.count].rawValue,
                bio: nil,
                isVisible: true,
                createdAt: Date()
            )
        }
    }

    // MARK: - Saved Guides

    private let savedGuidesKey = "savedGuides"

    var savedGuideLimit: Int {
        switch profile?.tier ?? "free" {
        case "pro": return .max
        case "plus": return 10
        default: return 3
        }
    }

    var canAddGuide: Bool {
        savedGuides.count < savedGuideLimit
    }

    func loadSavedGuides() {
        guard let data = UserDefaults.standard.data(forKey: savedGuidesKey),
              let guides = try? JSONDecoder().decode([SavedGuide].self, from: data) else {
            UserDefaults.standard.removeObject(forKey: savedGuidesKey)
            savedGuides = []
            return
        }
        savedGuides = guides
    }

    private func persistSavedGuides() {
        guard let data = try? JSONEncoder().encode(savedGuides) else { return }
        UserDefaults.standard.set(data, forKey: savedGuidesKey)
    }

    func addGuide(name: String, sunSign: ZodiacSign, category: GuideCategory, notes: String? = nil) {
        guard canAddGuide else {
            showToast("Guide limit reached", subtitle: "Upgrade your plan to save more guides", isError: true)
            showUpsell = true
            return
        }
        let guide = SavedGuide(name: name, sunSign: sunSign, category: category, notes: notes)
        savedGuides.append(guide)
        persistSavedGuides()
        analytics.track(.guideSaved)
        ReviewPromptService.shared.recordPositiveAction()
        showToast("Guide saved", subtitle: "\(name)'s communication guide is ready", isError: false)
    }

    func deleteGuide(_ guide: SavedGuide) {
        analytics.track(.guideDeleted)
        savedGuides.removeAll { $0.id == guide.id }
        persistSavedGuides()
    }

    func updateGuide(_ guide: SavedGuide) {
        guard let index = savedGuides.firstIndex(where: { $0.id == guide.id }) else { return }
        savedGuides[index] = guide
        persistSavedGuides()
    }

    // MARK: - Companion Messages (Inbox)

    var unreadMessageCount: Int {
        companionMessages.filter { !$0.isRead }.count
    }

    func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: companionMessagesKey) else {
            companionMessages = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let messages = try? decoder.decode([CompanionMessage].self, from: data) else {
            UserDefaults.standard.removeObject(forKey: companionMessagesKey)
            companionMessages = []
            return
        }
        companionMessages = messages.sorted { $0.timestamp > $1.timestamp }
    }

    func saveMessages() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(companionMessages) else { return }
        UserDefaults.standard.set(data, forKey: companionMessagesKey)
    }

    func markMessageRead(_ message: CompanionMessage) {
        guard let index = companionMessages.firstIndex(where: { $0.id == message.id }) else { return }
        companionMessages[index].isRead = true
        saveMessages()
    }

    func deleteMessage(_ message: CompanionMessage) {
        companionMessages.removeAll { $0.id == message.id }
        saveMessages()
    }

    func generateCompanionMessages() {
        let now = Date()
        let calendar = Calendar.current

        for companion in companions {
            let signKey = companion.sunSign.capitalized
            guard let templates = AstrologyTemplates.companionProactiveMessages[signKey], !templates.isEmpty else { continue }

            // Find the most recent message from this companion
            let lastMessage = companionMessages
                .filter { $0.companionId == companion.id }
                .sorted { $0.timestamp > $1.timestamp }
                .first

            if let last = lastMessage {
                // At least 6 hours gap
                let hoursSinceLast = now.timeIntervalSince(last.timestamp) / 3600
                guard hoursSinceLast >= 6 else { continue }

                // Max 1 message per companion per day
                if calendar.isDateInToday(last.timestamp) { continue }
            }

            // Pick a message using a deterministic-ish random based on day + companion id
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
            let companionHash = companion.id.hashValue
            let index = abs(dayOfYear &+ companionHash) % templates.count
            let content = templates[index]

            // Avoid sending the exact same message as last time
            if lastMessage?.content == content { continue }

            let zodiacSign = ZodiacSign(rawValue: companion.sunSign)

            let message = CompanionMessage(
                companionId: companion.id,
                companionName: companion.name,
                companionSign: zodiacSign?.displayName ?? companion.sunSign.capitalized,
                content: content,
                timestamp: now
            )
            companionMessages.insert(message, at: 0)
        }

        saveMessages()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastMessageGenerationKey)
    }

    func generateWelcomeMessage(for companion: CompanionData) {
        let signKey = companion.sunSign.capitalized
        let templates = AstrologyTemplates.companionWelcomeMessages[signKey]
            ?? AstrologyTemplates.companionGreetings[companion.sunSign]
            ?? ["hey, excited to connect with you!"]

        let index = abs(companion.id.hashValue) % templates.count
        let content = templates[index]
        let zodiacSign = ZodiacSign(rawValue: companion.sunSign)

        let message = CompanionMessage(
            companionId: companion.id,
            companionName: companion.name,
            companionSign: zodiacSign?.displayName ?? companion.sunSign.capitalized,
            content: content,
            timestamp: Date()
        )
        companionMessages.insert(message, at: 0)
        saveMessages()
    }

    // MARK: - Referral Code

    func applyReferralCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let info = ReferralInfo(referralCode: trimmed, referredBy: trimmed, referralDate: Date())
        referralInfo = info
        persistReferralInfo(info)
    }

    private func loadReferralInfo() {
        guard let data = UserDefaults.standard.data(forKey: referralInfoKey),
              let info = try? JSONDecoder().decode(ReferralInfo.self, from: data) else {
            return
        }
        referralInfo = info
    }

    private func persistReferralInfo(_ info: ReferralInfo) {
        guard let data = try? JSONEncoder().encode(info) else { return }
        UserDefaults.standard.set(data, forKey: referralInfoKey)
    }

    // MARK: - Profile Image Management

    func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let url = profileImageFileURL
        do {
            try data.write(to: url)
            profileImage = image
            profileImageURL = url.absoluteString
            UserDefaults.standard.set(url.absoluteString, forKey: profileImageURLKey)
        } catch {
            showToast("Couldn't save photo", subtitle: "Try again in a moment", isError: true)
        }
    }

    func loadProfileImage() {
        guard let savedURL = UserDefaults.standard.string(forKey: profileImageURLKey),
              let url = URL(string: savedURL) else {
            UserDefaults.standard.removeObject(forKey: profileImageURLKey)
            profileImage = nil
            profileImageURL = nil
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            // File was removed externally — clear stale reference
            UserDefaults.standard.removeObject(forKey: profileImageURLKey)
            profileImage = nil
            profileImageURL = nil
            return
        }
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            profileImage = image
            profileImageURL = savedURL
        } else {
            UserDefaults.standard.removeObject(forKey: profileImageURLKey)
            profileImage = nil
            profileImageURL = nil
        }
    }

    func deleteProfileImage() {
        let url = profileImageFileURL
        try? FileManager.default.removeItem(at: url)
        profileImage = nil
        profileImageURL = nil
        UserDefaults.standard.removeObject(forKey: profileImageURLKey)
    }

    private var profileImageFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent(profileImageFileName)
    }

    private func clearAccountScopedLocalState() {
        savedGuides = []
        companionMessages = []
        discoveredProfiles = []
        isDiscoverable = false
        socialDisplayName = ""
        socialBio = ""
        socialLinks = SocialLinks()
        referralInfo = nil
        hasAcceptedThirdPartyConsent = false
        profileImage = nil
        profileImageURL = nil

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: savedGuidesKey)
        defaults.removeObject(forKey: companionMessagesKey)
        defaults.removeObject(forKey: socialLinksKey)
        defaults.removeObject(forKey: socialDisplayNameKey)
        defaults.removeObject(forKey: socialBioKey)
        defaults.removeObject(forKey: isDiscoverableKey)
        defaults.removeObject(forKey: referralInfoKey)
        defaults.removeObject(forKey: thirdPartyConsentKey)
        defaults.removeObject(forKey: profileImageURLKey)

        deleteProfileImage()
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
        do {
            profile = try await supabase.fetchProfile()
        } catch {
            CrashReporter.log(error, context: "fetchProfile")
            profile = nil
            showToast("Couldn't load profile", subtitle: "Some saved details may be unavailable right now.", isError: true)
        }
        if let p = profile {
            userSunSign = p.sunSign.flatMap { ZodiacSign(rawValue: $0) }
            userMoonSign = p.moonSign.flatMap { ZodiacSign(rawValue: $0) }
            userRisingSign = p.risingSign.flatMap { ZodiacSign(rawValue: $0) }
            clearPendingOnboardingChart()
        } else {
            let restored = restorePendingOnboardingChart()
            if !restored {
                userSunSign = nil
                userMoonSign = nil
                userRisingSign = nil
            }
        }
    }

    private func loadCompanions() async {
        do {
            companions = try await supabase.fetchCompanions()
        } catch {
            CrashReporter.log(error, context: "fetchCompanions")
            companions = []
            showToast("Couldn't load companions", subtitle: "Your circle may be incomplete until the connection returns.", isError: true)
        }
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

    private var shouldPersistPendingBirthChart: Bool {
        guard let profile else {
            return userSunSign != nil && userMoonSign != nil && userRisingSign != nil
        }

        let isMissingPersistedChart = profile.sunSign == nil || profile.moonSign == nil || profile.risingSign == nil
        return isMissingPersistedChart
            && userSunSign != nil
            && userMoonSign != nil
            && userRisingSign != nil
    }

    private func persistPendingOnboardingChart() {
        let pending = PendingOnboardingChart(
            sunSign: userSunSign?.rawValue,
            moonSign: userMoonSign?.rawValue,
            risingSign: userRisingSign?.rawValue
        )

        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: pendingOnboardingChartKey)
    }

    @discardableResult
    private func restorePendingOnboardingChart() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: pendingOnboardingChartKey),
              let pending = try? JSONDecoder().decode(PendingOnboardingChart.self, from: data) else {
            return false
        }

        userSunSign = pending.sunSign.flatMap { ZodiacSign(rawValue: $0) }
        userMoonSign = pending.moonSign.flatMap { ZodiacSign(rawValue: $0) }
        userRisingSign = pending.risingSign.flatMap { ZodiacSign(rawValue: $0) }
        return userSunSign != nil || userMoonSign != nil || userRisingSign != nil
    }

    private func clearPendingOnboardingChart() {
        UserDefaults.standard.removeObject(forKey: pendingOnboardingChartKey)
    }

    // MARK: - GDPR Data Export

    func exportUserData() -> URL? {
        var exportData: [String: Any] = [:]

        // Profile
        if let profile = profile {
            exportData["profile"] = [
                "sunSign": profile.sunSign ?? "",
                "moonSign": profile.moonSign ?? "",
                "risingSign": profile.risingSign ?? "",
                "tier": profile.tier
            ]
        }

        // Companions (no PII from other users)
        exportData["companions"] = companions.map { companion in
            [
                "name": companion.name,
                "sunSign": companion.sunSign,
                "moonSign": companion.moonSign,
                "risingSign": companion.risingSign,
                "compatibilityScore": companion.compatibilityScore,
                "createdAt": ISO8601DateFormatter().string(from: companion.createdAt ?? Date())
            ] as [String: Any]
        }

        // Saved guides
        exportData["savedGuides"] = savedGuides.map { guide in
            [
                "name": guide.name,
                "sunSign": guide.sunSign.rawValue,
                "category": guide.category.rawValue,
                "createdAt": ISO8601DateFormatter().string(from: guide.createdAt)
            ]
        }

        // Settings
        exportData["settings"] = [
            "isDarkMode": isDarkMode,
            "language": UserDefaults.standard.string(forKey: "appLanguage") ?? "en",
            "isDiscoverable": isDiscoverable
        ]

        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // Write to temp JSON file
        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("simastry_data_export.json")
        try? jsonData.write(to: tempURL)

        return tempURL
    }

    private func trackedProfile() async -> UserProfile? {
        if let profile {
            return profile
        }

        guard let userId = await supabase.currentUserId else {
            return nil
        }

        let created = UserProfile.createDefault(id: userId)
        profile = created
        return created
    }
}

nonisolated struct ToastMessage: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let subtitle: String
    let isError: Bool
}

private struct PendingOnboardingChart: Codable {
    let sunSign: String?
    let moonSign: String?
    let risingSign: String?
}
