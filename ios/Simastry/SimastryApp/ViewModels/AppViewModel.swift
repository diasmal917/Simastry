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
    #if DEBUG
    var isDebugPreviewStateActive: Bool = false
    #endif
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
    private let auraWalletPublicAddressKey = "simastry_aura_wallet_public_address"
    private let auraWalletUseInAuraKey = "simastry_aura_wallet_use_in_aura"
    private let auraWalletLastCheckedAtKey = "simastry_aura_wallet_last_checked_at"
    private let privateNotificationsEnabledKey = "simastry_private_notifications_enabled"

    var companionSunSign: ZodiacSign?
    var companionMoonSign: ZodiacSign?
    var companionRisingSign: ZodiacSign?
    var companionName: String = ""
    var companionAppearance: AppearanceStyle = .ethereal

    var onboardingBirthday: Date?
    var onboardingBirthTime: Date?
    var onboardingBirthplace: String?
    var onboardingDisplayName: String? = UserDefaults.standard.string(forKey: "simastry_onboarding_display_name") {
        didSet {
            let trimmed = onboardingDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: "simastry_onboarding_display_name")
            } else {
                UserDefaults.standard.removeObject(forKey: "simastry_onboarding_display_name")
            }
        }
    }

    var companionMessages: [CompanionMessage] = []
    var discoveryMessages: [CompanionMessage] = []
    var savedGuides: [SavedGuide] = []
    var relationshipPeople: [RelationshipPerson] = []

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

    var auraWalletPublicAddress: String = UserDefaults.standard.string(forKey: "simastry_aura_wallet_public_address") ?? "" {
        didSet {
            UserDefaults.standard.set(auraWalletPublicAddress, forKey: auraWalletPublicAddressKey)
        }
    }

    var useAuraWalletForAura: Bool = UserDefaults.standard.object(forKey: "simastry_aura_wallet_use_in_aura") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "simastry_aura_wallet_use_in_aura") {
        didSet {
            UserDefaults.standard.set(useAuraWalletForAura, forKey: auraWalletUseInAuraKey)
        }
    }

    var auraWalletLastCheckedAt: Date? = {
        let timestamp = UserDefaults.standard.double(forKey: "simastry_aura_wallet_last_checked_at")
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }() {
        didSet {
            if let auraWalletLastCheckedAt {
                UserDefaults.standard.set(auraWalletLastCheckedAt.timeIntervalSince1970, forKey: auraWalletLastCheckedAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: auraWalletLastCheckedAtKey)
            }
        }
    }

    var privateNotificationsEnabled: Bool = UserDefaults.standard.object(forKey: "simastry_private_notifications_enabled") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "simastry_private_notifications_enabled") {
        didSet {
            UserDefaults.standard.set(privateNotificationsEnabled, forKey: privateNotificationsEnabledKey)
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
    var aiAstrologistsRouteRequest: Int = 0
    var predictRouteRequest: Int = 0
    var pendingDeepLinkURL: URL?
    var pendingDeepLink: DeepLink?
    var guideFocusSign: ZodiacSign?
    var predictionDraft: PredictionDraft?
    var referralInfo: ReferralInfo?

    // MARK: - Companion DM State
    /// Companion threads currently "typing" a reply (drives the typing indicator).
    var typingCompanionIds: Set<UUID> = []
    /// The companion thread the user is looking at, so replies arrive pre-read.
    var openCompanionThreadId: UUID?

    // MARK: - Panel Chat State
    /// Group thread with the user's Sun/Moon/Rising guides. Messages persist
    /// locally; participants rebuild from the current chart (see +PanelChat).
    var panelMessages: [PanelMessage] = []
    /// Guide participant ids currently "typing" in the panel thread.
    var panelTypingParticipantIds: Set<String> = []
    /// True while the panel chat is on screen, so replies arrive pre-read.
    var isPanelThreadOpen: Bool = false
    /// Bumped to ask MessagesView to present the panel chat.
    var panelChatRouteRequest: Int = 0
    /// What the panel remembers — People mentioned in conversation (+PanelChat).
    var panelMemoryNotes: [MemoryNote] = []

    // MARK: - People Routing
    /// Set to push a person's detail screen (debug previews, deep links).
    var peopleDetailRequestPersonId: UUID?
    /// Bumped to present the Team Read sheet.
    var teamReadRouteRequest: Int = 0

    // MARK: - Moments State
    /// Private on-device photo posts; guides engage via templates (+Moments).
    var moments: [Moment] = []
    /// "{momentId}:{profileId}" keys for guides currently "typing" a comment.
    var momentTypingKeys: Set<String> = []
    let momentsStore = MomentsStore()

    // MARK: - Legacy Consumable Top-Ups
    var bonusPredictions: Int = UserDefaults.standard.integer(forKey: "bonusPredictions") {
        didSet { UserDefaults.standard.set(bonusPredictions, forKey: "bonusPredictions") }
    }

    var hasBonusPredictions: Bool { bonusPredictions > 0 }

    func addBonusPredictions(_ count: Int) {
        bonusPredictions += count
    }

    func purchasePredictionPack(_ pack: PredictionPack) async {
        // For now, simulate the purchase locally
        // TODO: Wire to RevenueCat consumable IAP when products are configured
        addBonusPredictions(pack.count)
        showToast("Added \(pack.count) predictions!", subtitle: "Use them anytime", isError: false)
        analytics.track(.subscriptionStarted, key: "pack", value: pack.rawValue)
    }

    func saveAuraWalletPublicAddress(_ address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSupportedPublicWalletAddress(trimmed) else {
            showToast("Wallet not saved", subtitle: "Paste a Solana or EVM public wallet address.", isError: true)
            return
        }
        auraWalletPublicAddress = trimmed
        auraWalletLastCheckedAt = Date()
        showToast("Wallet saved", subtitle: "Your Aura can reflect this wallet's Zodiacs.", isError: false)
    }

    func clearAuraWalletContext() {
        auraWalletPublicAddress = ""
        auraWalletLastCheckedAt = nil
        showToast("Wallet removed", subtitle: "Aura will use chart signals only.", isError: false)
    }

    static func isSupportedPublicWalletAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if trimmed.hasPrefix("0x"), trimmed.count == 42 {
            let hexPart = String(trimmed.dropFirst(2))
            return hexPart.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
        }

        let base58Characters = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return (32...60).contains(trimmed.count)
            && trimmed.unicodeScalars.allSatisfy { base58Characters.contains($0) }
    }

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
    private let lastDiscoveryMessageTimestampKey = "simastry_last_discovery_message_timestamp"
    private let relationshipPeopleStore = RelationshipPeopleStore()

    var hasAuraWalletContext: Bool {
        !auraWalletPublicAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var auraWalletShortAddress: String {
        let trimmed = auraWalletPublicAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return trimmed }
        return "\(trimmed.prefix(6))...\(trimmed.suffix(4))"
    }

    init() {
        loadReferralInfo()
        loadRelationshipPeople()
        loadPanelMessages()
        loadPanelMemoryNotes()
        loadMoments()

        // Server-proxied AI channel: predictions route through the
        // companion-reply edge function when Supabase is configured.
        predictionService.replyChannel = { [supabase] system, user in
            try await supabase.invokeCompanionReply(kind: .prediction, system: system, user: user)
        }
        predictionService.isRemoteChannelAvailable = { [supabase] in
            supabase.canInvokeCompanionReply
        }
    }

    // MARK: - Age Verification

    func verifyAge() {
        isAgeVerified = true
        UserDefaults.standard.set(true, forKey: "ageVerified")
    }

    func completeAgeVerification() {
        verifyAge()
        currentScreen = .birthDetails
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

    func openAIAstrologists() {
        selectedTab = 0
        homeSetupPhase = .complete
        aiAstrologistsRouteRequest += 1
    }

    func openPredict(with draft: PredictionDraft? = nil) {
        if let draft {
            predictionDraft = draft
        }
        selectedTab = 0
        homeSetupPhase = .complete
        predictRouteRequest += 1
    }

    func loadRelationshipPeople() {
        relationshipPeople = relationshipPeopleStore.loadPeople()
    }

    func addRelationshipPerson(_ person: RelationshipPerson) {
        relationshipPeople.append(person)
        saveRelationshipPeople()
    }

    func updateRelationshipPerson(_ person: RelationshipPerson) {
        guard let index = relationshipPeople.firstIndex(where: { $0.id == person.id }) else { return }
        var updated = person
        updated.updatedAt = .now
        relationshipPeople[index] = updated
        saveRelationshipPeople()
    }

    func deleteRelationshipPerson(_ person: RelationshipPerson) {
        relationshipPeople.removeAll { $0.id == person.id }
        saveRelationshipPeople()
    }

    func relationshipReading(for person: RelationshipPerson) -> RelationshipPersonReading {
        RelationshipReadingFactory.reading(
            for: person,
            userSun: userSunSign,
            userMoon: userMoonSign,
            userRising: userRisingSign
        )
    }

    private func saveRelationshipPeople() {
        relationshipPeopleStore.savePeople(relationshipPeople)
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
            predictionDraft = nil
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
        predictionDraft = nil
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

            do {
                try await supabase.deleteSocialProfile(for: userId.uuidString)
            } catch {
                remoteFailures.append("social_profile")
                CrashReporter.log(error, context: "deleteAccountSocialProfile")
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
        predictionDraft = nil
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
                    "positiveActionCount", "lastReviewPromptDate", "reviewPromptCount",
                    "bonusPredictions"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Delete profile image file
        deleteProfileImage()

        // Clear widget data
        SharedDefaults.clearAll()
    }

    func clearLocalDeviceData() {
        notificationService.clearScheduledNotifications()
        clearPendingOnboardingChart()
        clearAccountScopedLocalState()
        SharedDefaults.clearAll()
        WidgetCenter.shared.reloadAllTimelines()
        showToast(
            "Local data cleared",
            subtitle: "Your account was not deleted. Only this device's local Simastry data was removed.",
            isError: false
        )
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
        case "companions":
            openAIAstrologists()
        case "people":
            selectedTab = 1
        case "chat":
            selectedTab = 2
        case "messages":
            selectedTab = 2
        case "panel":
            openPanelChat()
        case "simulate":
            openPredict()
        case "guides", "astropedia":
            guideFocusSign = nil
            selectedTab = 0
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
        case .compatibility:
            guideFocusSign = nil
            selectedTab = 1

        case .guide:
            guideFocusSign = nil
            selectedTab = 0

        case .invite(let code):
            applyInviteCode(code)
            selectedTab = 0

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
        await loadSocialProfile()
        await loadCompanions()
        await checkSubscriptionStatus()
        syncHomeSetupPhase()
        await setupNotifications()
        updateWidgetData()
        await refreshInbox()
    }

    func refreshRealtimeSurfaces() async {
        guard isAuthenticated else { return }
        await notificationService.checkAuthorizationStatus()
        await refreshInbox(showErrors: false)
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

        #if DEBUG
        if isDebugPreviewStateActive {
            if newLevel.rawValue > previousLevel.rawValue {
                showToast("Bond deepened", subtitle: "\(updated.name) reached \(newLevel.name)", isError: false)
            } else {
                showToast(title, subtitle: subtitle ?? "\(updated.name) feels a little closer", isError: false)
            }
            return true
        }
        #endif

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

    func startPrediction(for companion: CompanionData, question: String? = nil, conversationText: String? = nil) {
        guard let sun = zodiacSign(from: companion.sunSign) else {
            showToast("Missing sign", subtitle: "Add a Sun sign before opening message guidance.", isError: true)
            return
        }

        let draft = PredictionDraft(
            targetName: companion.name,
            targetSunSign: sun,
            targetMoonSign: zodiacSign(from: companion.moonSign),
            targetRisingSign: zodiacSign(from: companion.risingSign),
            question: question ?? "What will \(companion.name) say next?",
            conversationText: conversationText
        )
        openPredict(with: draft)
    }

    func startPrediction(for sign: ZodiacSign, question: String? = nil, conversationText: String? = nil) {
        let draft = PredictionDraft(
            targetSunSign: sign,
            question: question ?? "What would a \(sign.displayName) say next?",
            conversationText: conversationText
        )
        openPredict(with: draft)
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

        guard privateNotificationsEnabled else {
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
            // Tomorrow morning's notification carries tomorrow's computed sky.
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let reading = TransitEngine.dailyReading(
                sun: userSunSign,
                moon: userMoonSign,
                rising: userRisingSign,
                on: tomorrow
            )
            notificationService.scheduleDailyTransit(
                risingSign: rising,
                tier: tier,
                readingBody: reading.map { "\($0.headline) — \($0.guidance)" }
            )
        }

        schedulePanelStarterNotification()
        scheduleDailyBriefNotification()
    }

    /// Daily nudge that a guide opened the panel's conversation starter.
    /// Privacy-safe: names the guide and focus lens, never message content.
    private func schedulePanelStarterNotification() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        // Tomorrow's focus role, matching the daily-starter rotation.
        let focusRole = [CelestialRole.sun, .moon, .rising][(dayOfYear + 1) % 3]
        guard let entry = panelGuideEntries.first(where: { $0.role == focusRole }) ?? panelGuideEntries.first else {
            return
        }
        notificationService.schedulePanelStarter(
            guideName: entry.profile.name,
            focusName: focusRole.displayName
        )
    }

    /// Mirrors Home's rotating daily brief. The notification fires the next
    /// morning, so it carries tomorrow's focus (Home uses dayOfYear % 3).
    func scheduleDailyBriefNotification() {
        guard let type = CommunicationTypeProfile.make(
            sun: userSunSign,
            moon: userMoonSign,
            rising: userRisingSign
        ) else { return }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let (focusName, line): (String, String) = switch (dayOfYear + 1) % 3 {
        case 0: ("Sun", type.sunSignal)
        case 1: ("Moon", type.moonSignal)
        default: ("Rising", type.risingSignal)
        }

        notificationService.scheduleDailyBrief(focusName: focusName, body: line)
    }

    func navigateAfterAuth() async {
        await loadProfile()
        await loadSocialProfile()
        if shouldPersistPendingBirthChart {
            await saveUserSigns()
        }
        await loadCompanions()
        await checkSubscriptionStatus()
        loadSavedGuides()
        loadProfileImage()
        await refreshInbox()
        syncHomeSetupPhase()
        selectedTab = 0
        currentScreen = .home
        if homeSetupPhase == .complete {
            analytics.track(.onboardingCompleted)
            ReviewPromptService.shared.recordPositiveAction()
        }
        await setupNotifications()
        updateWidgetData()

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
            applyOnboardingDisplayNameIfNeeded(to: &p)
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
            applyOnboardingDisplayNameIfNeeded(to: &p)
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

    /// First name collected during onboarding wins only when the profile has
    /// no name yet — never overwrites a name the user set elsewhere.
    private func applyOnboardingDisplayNameIfNeeded(to profile: inout UserProfile) {
        guard let name = onboardingDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return }
        let existing = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if existing.isEmpty {
            profile.displayName = name
        }
        onboardingDisplayName = nil
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
            showToast("Discovery unavailable", subtitle: "Enable social discovery in your environment before using this feature.", isError: false)
            return
        }
        guard hasCompletedSigns else {
            isDiscoverable = false
            showToast("Finish your signs", subtitle: "Complete your birth chart before joining discovery.", isError: true)
            return
        }

        let previousValue = isDiscoverable
        let nextValue = !previousValue
        isDiscoverable = nextValue

        Task {
            await persistSocialProfile(
                isVisible: nextValue,
                onFailureRestoreVisibility: previousValue,
                showVisibilityToast: true
            )
        }
    }

    func fetchDiscoverableProfiles() async {
        guard AppConfig.socialDiscoveryEnabled else {
            discoveredProfiles = []
            return
        }

        do {
            let profiles = try await supabase.fetchVisibleSocialProfiles()
            let blocks = try await supabase.fetchDiscoveryBlocks()
            let fallbackCurrentUserId = await supabase.currentUserId
            let currentUserId = profile?.id ?? fallbackCurrentUserId

            let blockedProfileIds = Set(blocks.compactMap { block -> UUID? in
                guard let currentUserId else { return nil }
                if block.blockerId == currentUserId { return block.blockedId }
                if block.blockedId == currentUserId { return block.blockerId }
                return nil
            })

            discoveredProfiles = profiles
                .filter { socialProfile in
                    socialProfile.isVisible &&
                    socialProfile.id != currentUserId &&
                    !blockedProfileIds.contains(socialProfile.id)
                }
                .sorted { compatibilityWithUser(for: $0) > compatibilityWithUser(for: $1) }
        } catch {
            CrashReporter.log(error, context: "fetchDiscoverableProfiles")
            discoveredProfiles = []
            showToast("Couldn't load discovery", subtitle: "Check your connection or try again later.", isError: true)
        }
    }

    func createSocialProfile() {
        guard AppConfig.socialDiscoveryEnabled else { return }
        if socialDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            socialDisplayName = profile?.displayName ?? "Stargazer"
        }

        Task {
            await persistSocialProfile(
                isVisible: true,
                onFailureRestoreVisibility: false,
                showVisibilityToast: false
            )
        }
    }

    func updateSocialProfile() {
        guard AppConfig.socialDiscoveryEnabled else { return }
        Task {
            await persistSocialProfile(
                isVisible: isDiscoverable,
                onFailureRestoreVisibility: nil,
                showVisibilityToast: false
            )
        }
    }

    func updateSocialLinks(_ links: SocialLinks) {
        socialLinks = links
        updateSocialProfile()
    }

    // MARK: - Discovery "Say Hi" Messaging

    @discardableResult
    func sendDiscoveryMessage(from profile: SocialProfile) async -> Bool {
        guard AppConfig.socialDiscoveryEnabled else {
            showToast("Discovery unavailable", subtitle: "Enable social discovery in your environment before using this feature.", isError: false)
            return false
        }
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited sparks.",
                isError: true
            )
            showUpsell = true
            return false
        }
        guard let currentProfile = self.profile else {
            showToast("Couldn't send intro", subtitle: "Sign in again and try once more.", isError: true)
            return false
        }
        guard let senderPayload = currentDiscoveryMessageSender() else {
            return false
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
        guard !templates.isEmpty else { return false }

        let index = abs(profile.id.hashValue) % templates.count
        let template = templates[index]

        let content: String
        if category == "same_sign" {
            let signName = ZodiacSign(rawValue: profile.sunSign)?.displayName ?? profile.sunSign.capitalized
            content = String(format: template, signName)
        } else {
            content = String(format: template, "\(compatibility)")
        }

        let remoteMessage = DiscoveryMessageData(
            id: UUID(),
            senderId: currentProfile.id,
            recipientId: profile.id,
            senderDisplayName: senderPayload.displayName,
            senderSunSign: senderPayload.sunSign,
            senderMoonSign: senderPayload.moonSign,
            senderRisingSign: senderPayload.risingSign,
            recipientDisplayName: profile.displayName,
            recipientSunSign: profile.sunSign,
            recipientMoonSign: profile.moonSign,
            recipientRisingSign: profile.risingSign,
            content: content,
            isRead: false,
            createdAt: Date()
        )

        do {
            try await supabase.sendDiscoveryMessage(remoteMessage)
            appendLocalDiscoveryMessage(remoteMessage, viewerId: currentProfile.id)
            await consumeMessage()
            showToast("Intro sent", subtitle: "\(profile.displayName) will see it in their inbox.", isError: false)
            return true
        } catch {
            CrashReporter.log(error, context: "sendDiscoveryMessage")
            showToast("Couldn't send intro", subtitle: "Try again in a moment.", isError: true)
            return false
        }
    }

    @discardableResult
    func sendDiscoveryReply(
        to companionId: UUID,
        companionName: String,
        companionSign: String,
        content: String
    ) async -> Bool {
        guard AppConfig.socialDiscoveryEnabled else {
            showToast("Discovery unavailable", subtitle: "Enable social discovery in your environment before using this feature.", isError: false)
            return false
        }
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited sparks.",
                isError: true
            )
            showUpsell = true
            return false
        }
        guard let currentProfile = self.profile else {
            showToast("Couldn't send reply", subtitle: "Sign in again and try once more.", isError: true)
            return false
        }
        guard let senderPayload = currentDiscoveryMessageSender() else {
            return false
        }

        let moderation = ContentModerationService.moderateDiscoveryMessage(content)
        guard moderation.isAllowed else {
            showToast("Couldn't send reply", subtitle: moderation.reason ?? "Please revise your message and try again.", isError: true)
            return false
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipientSunSign = ZodiacSign.allCases.first { $0.displayName == companionSign }?.rawValue ?? companionSign.lowercased()

        let remoteMessage = DiscoveryMessageData(
            id: UUID(),
            senderId: currentProfile.id,
            recipientId: companionId,
            senderDisplayName: senderPayload.displayName,
            senderSunSign: senderPayload.sunSign,
            senderMoonSign: senderPayload.moonSign,
            senderRisingSign: senderPayload.risingSign,
            recipientDisplayName: companionName,
            recipientSunSign: recipientSunSign,
            recipientMoonSign: nil,
            recipientRisingSign: nil,
            content: trimmedContent,
            isRead: false,
            createdAt: Date()
        )

        do {
            try await supabase.sendDiscoveryMessage(remoteMessage)
            appendLocalDiscoveryMessage(remoteMessage, viewerId: currentProfile.id)
            await consumeMessage()
            return true
        } catch {
            CrashReporter.log(error, context: "sendDiscoveryReply")
            showToast("Couldn't send reply", subtitle: "Try again in a moment.", isError: true)
            return false
        }
    }

    func blockDiscoveryProfile(_ socialProfile: SocialProfile) async {
        guard AppConfig.socialDiscoveryEnabled else { return }

        do {
            try await supabase.blockDiscoveryProfile(blockedId: socialProfile.id)
            discoveredProfiles.removeAll { $0.id == socialProfile.id }
            showToast("Profile hidden", subtitle: "\(socialProfile.displayName) won't appear in discovery anymore.", isError: false)
        } catch {
            CrashReporter.log(error, context: "blockDiscoveryProfile")
            showToast("Couldn't block profile", subtitle: "Try again in a moment.", isError: true)
        }
    }

    func reportDiscoveryProfile(
        _ socialProfile: SocialProfile,
        reason: DiscoveryReportReason,
        details: String? = nil
    ) async {
        guard AppConfig.socialDiscoveryEnabled else { return }
        let fallbackCurrentUserId = await supabase.currentUserId
        let currentUserId = profile?.id ?? fallbackCurrentUserId
        guard let currentUserId else {
            showToast("Couldn't send report", subtitle: "Sign in again and try once more.", isError: true)
            return
        }

        let report = DiscoveryReportData(
            id: UUID(),
            reporterId: currentUserId,
            reportedId: socialProfile.id,
            reason: reason.rawValue,
            details: details,
            createdAt: Date()
        )

        do {
            try await supabase.reportDiscoveryProfile(report)
            showToast("Report submitted", subtitle: "Thanks for helping keep discovery safe.", isError: false)
        } catch {
            CrashReporter.log(error, context: "reportDiscoveryProfile")
            showToast("Couldn't send report", subtitle: "Try again in a moment.", isError: true)
        }
    }

    func loadSocialProfile() async {
        guard AppConfig.socialDiscoveryEnabled else { return }

        do {
            if let remoteProfile = try await supabase.fetchCurrentSocialProfile() {
                socialDisplayName = remoteProfile.displayName
                socialBio = remoteProfile.bio ?? ""
                socialLinks = remoteProfile.socialLinks ?? SocialLinks()
                isDiscoverable = remoteProfile.isVisible
            } else if socialDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                socialDisplayName = profile?.displayName ?? ""
            }
        } catch {
            CrashReporter.log(error, context: "loadSocialProfile")
        }
    }

    func refreshInbox(showErrors: Bool = false) async {
        #if DEBUG
        guard !isDebugPreviewStateActive else {
            return
        }
        #endif

        loadMessages()
        await loadDiscoveryInboxMessages(showErrors: showErrors)
        generateCompanionMessages()
        postPanelDailyStarterIfNeeded()
        postPanelWeeklyRecapIfNeeded()
    }

    private func loadDiscoveryInboxMessages(showErrors: Bool) async {
        guard AppConfig.socialDiscoveryEnabled else {
            mergeDiscoveryInboxMessages([])
            return
        }

        let previousDiscoveryTimestamp = UserDefaults.standard.object(forKey: lastDiscoveryMessageTimestampKey) as? Date
        let fallbackCurrentUserId = await supabase.currentUserId
        let currentUserId = profile?.id ?? fallbackCurrentUserId
        guard let currentUserId else {
            mergeDiscoveryInboxMessages([])
            return
        }

        do {
            let remoteMessages = try await supabase.fetchDiscoveryMessages()
                .map { $0.inboxMessage(for: currentUserId) }
                .sorted { $0.timestamp < $1.timestamp }

            mergeDiscoveryInboxMessages(remoteMessages)

            let newlyArrivedMessages = remoteMessages.filter { message in
                message.direction == .incoming &&
                !message.isRead &&
                (previousDiscoveryTimestamp.map { message.timestamp > $0 } ?? false)
            }
            if let newestArrival = newlyArrivedMessages.max(by: { $0.timestamp < $1.timestamp }) {
                notificationService.scheduleDiscoveryMessageAlert(
                    senderName: newestArrival.companionName,
                    preview: newestArrival.content
                )
            }

            if let newestTimestamp = remoteMessages.map(\.timestamp).max() {
                UserDefaults.standard.set(newestTimestamp, forKey: lastDiscoveryMessageTimestampKey)
            }
        } catch {
            CrashReporter.log(error, context: "loadDiscoveryInboxMessages")
            mergeDiscoveryInboxMessages([])
            if showErrors {
                showToast("Couldn't refresh inbox", subtitle: "Try again in a moment.", isError: true)
            }
        }
    }

    private func mergeDiscoveryInboxMessages(_ remoteMessages: [CompanionMessage]) {
        discoveryMessages = remoteMessages
    }

    func discoveryConversation(with companionId: UUID) -> [CompanionMessage] {
        discoveryMessages
            .filter { $0.companionId == companionId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func appendLocalDiscoveryMessage(_ message: DiscoveryMessageData, viewerId: UUID) {
        let inboxMessage = message.inboxMessage(for: viewerId)
        discoveryMessages.removeAll { $0.id == inboxMessage.id }
        discoveryMessages.append(inboxMessage)
        discoveryMessages.sort { $0.timestamp < $1.timestamp }
    }

    private func persistSocialProfile(
        isVisible: Bool,
        onFailureRestoreVisibility: Bool?,
        showVisibilityToast: Bool
    ) async {
        guard AppConfig.socialDiscoveryEnabled else { return }
        guard let socialProfile = buildCurrentSocialProfile(isVisible: isVisible) else {
            if let onFailureRestoreVisibility {
                self.isDiscoverable = onFailureRestoreVisibility
            }
            return
        }

        do {
            try await supabase.upsertSocialProfile(socialProfile)
            socialDisplayName = socialProfile.displayName
            isDiscoverable = socialProfile.isVisible

            guard showVisibilityToast else { return }
            if isVisible {
                showToast("You're visible", subtitle: "Other compatible Simastry users can now find you.", isError: false)
            } else {
                showToast("Browsing privately", subtitle: "Your discovery profile is now hidden from others.", isError: false)
            }
        } catch {
            if let onFailureRestoreVisibility {
                self.isDiscoverable = onFailureRestoreVisibility
                showToast("Couldn't update discovery", subtitle: "Try again in a moment.", isError: true)
            }
            CrashReporter.log(error, context: "persistSocialProfile")
        }
    }

    private func buildCurrentSocialProfile(isVisible: Bool) -> SocialProfile? {
        guard let currentProfile = profile else {
            showToast("Couldn't update discovery", subtitle: "Sign in again and try once more.", isError: true)
            return nil
        }

        guard let sunSign = currentProfile.sunSign,
              let moonSign = currentProfile.moonSign,
              let risingSign = currentProfile.risingSign else {
            showToast("Finish your signs", subtitle: "Complete your birth chart before joining discovery.", isError: true)
            return nil
        }

        let trimmedDisplayName = socialDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = trimmedDisplayName.isEmpty
            ? (currentProfile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Stargazer")
            : trimmedDisplayName

        guard !resolvedDisplayName.isEmpty, resolvedDisplayName.count <= 32 else {
            showToast("Invalid display name", subtitle: "Use a name between 1 and 32 characters.", isError: true)
            return nil
        }

        let trimmedBio = String(socialBio.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150))
        if !trimmedBio.isEmpty {
            let moderation = ContentModerationService.moderatePublicProfileText(trimmedBio)
            guard moderation.isAllowed else {
                showToast("Couldn't update profile", subtitle: moderation.reason ?? "Please revise your bio and try again.", isError: true)
                return nil
            }
        }

        return SocialProfile(
            id: currentProfile.id,
            displayName: resolvedDisplayName,
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            socialLinks: socialLinks.isEmpty ? nil : socialLinks,
            isVisible: isVisible,
            createdAt: Date()
        )
    }

    private func currentDiscoveryMessageSender() -> (displayName: String, sunSign: String, moonSign: String?, risingSign: String?)? {
        guard let currentProfile = profile,
              let sunSign = currentProfile.sunSign else {
            showToast("Couldn't send intro", subtitle: "Finish your profile signs first.", isError: true)
            return nil
        }

        let displayName = socialDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = displayName.isEmpty
            ? (currentProfile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Stargazer")
            : displayName

        guard !resolvedDisplayName.isEmpty else {
            showToast("Add a display name", subtitle: "Set a discovery display name before sending an intro.", isError: true)
            return nil
        }

        return (
            displayName: resolvedDisplayName,
            sunSign: sunSign,
            moonSign: currentProfile.moonSign,
            risingSign: currentProfile.risingSign
        )
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
            return "A connection lens based on available chart signals"
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
        (companionMessages + discoveryMessages)
            .filter { !$0.isRead && $0.direction == .incoming }
            .count
            + unreadPanelCount
    }

    var inboxMessages: [CompanionMessage] {
        let companionThreads = Dictionary(grouping: companionMessages, by: \.companionId)
            .compactMap { _, messages in
                messages.max { $0.timestamp < $1.timestamp }
            }

        let discoveryThreads = Dictionary(grouping: discoveryMessages, by: \.companionId)
            .compactMap { _, messages in
                messages.max { $0.timestamp < $1.timestamp }
            }

        return (companionThreads + discoveryThreads)
            .sorted { $0.timestamp > $1.timestamp }
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
        // Preserve stored direction so outgoing replies survive relaunch; legacy
        // messages without the field decode as companion/incoming.
        companionMessages = messages
            .map { message in
                var normalized = message
                normalized.source = .companion
                return normalized
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Full companion thread, oldest first, for the DM view.
    func companionConversation(with companionId: UUID) -> [CompanionMessage] {
        companionMessages
            .filter { $0.companionId == companionId }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Marks every incoming message in a companion thread as read.
    func markCompanionThreadRead(_ companionId: UUID) {
        var changed = false
        for index in companionMessages.indices where companionMessages[index].companionId == companionId {
            if companionMessages[index].direction == .incoming && !companionMessages[index].isRead {
                companionMessages[index].isRead = true
                changed = true
            }
        }
        if changed { saveMessages() }
    }

    /// Sends a user message into a companion thread and schedules a sign-lens reply.
    /// The reply is composed on device from the method layer — no remote AI.
    @discardableResult
    func sendCompanionThreadMessage(
        companionId: UUID,
        companionName: String,
        companionSign: String,
        content: String
    ) async -> Bool {
        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited messages.",
                isError: true
            )
            showUpsell = true
            return false
        }

        let outgoing = CompanionMessage(
            companionId: companionId,
            companionName: companionName,
            companionSign: companionSign,
            content: content,
            timestamp: Date(),
            isRead: true,
            source: .companion,
            direction: .outgoing
        )
        companionMessages.insert(outgoing, at: 0)
        saveMessages()
        // Guides share one memory — 1:1 mentions inform panel follow-ups too.
        recordPanelMemoryIfNeeded(from: content)

        // Keep relationship metrics in sync when a companion record exists.
        if let index = companions.firstIndex(where: { $0.id == companionId }) {
            var updated = companions[index]
            let previousLevel = updated.relationshipLevel
            updated.conversationCount += 1
            if updated.firstConversationAt == nil {
                updated.firstConversationAt = Date()
            }
            let newLevel = RelationshipLevel.from(messageCount: updated.conversationCount)
            updated.relationshipLevel = newLevel.rawValue
            if updated.compatibilityScore < 97 {
                updated.compatibilityScore += 1
            }
            companions[index] = updated

            // Surface the bond deepening — progression should feel like an event.
            if newLevel.rawValue > previousLevel {
                HapticManager.soulFlash()
                showToast(
                    "Bond deepened",
                    subtitle: "\(updated.name) and you reached \(newLevel.name).",
                    isError: false
                )
            }

            #if DEBUG
            let skipRemote = isDebugPreviewStateActive
            #else
            let skipRemote = false
            #endif
            if !skipRemote {
                try? await supabase.updateCompanion(updated)
            }
        }

        await consumeMessage()
        scheduleCompanionReply(companionId: companionId, companionName: companionName, companionSign: companionSign)
        return true
    }

    private func scheduleCompanionReply(companionId: UUID, companionName: String, companionSign: String) {
        guard !typingCompanionIds.contains(companionId) else { return }
        typingCompanionIds.insert(companionId)

        let threadCount = companionMessages.filter { $0.companionId == companionId }.count
        let delay = Double(1_400 + (threadCount % 4) * 350)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))

            // LLM reply when the edge channel is live; templates otherwise.
            let llmContent = await generateCompanionReplyViaLLM(
                companionId: companionId,
                companionName: companionName,
                companionSign: companionSign
            )
            typingCompanionIds.remove(companionId)

            let reply = CompanionMessage(
                companionId: companionId,
                companionName: companionName,
                companionSign: companionSign,
                content: llmContent ?? composeCompanionReply(signName: companionSign, threadCount: threadCount),
                timestamp: Date(),
                isRead: openCompanionThreadId == companionId,
                source: .companion,
                direction: .incoming
            )
            companionMessages.insert(reply, at: 0)
            saveMessages()
        }
    }

    /// Composes a companion reply from the persona's sign lens: an element-keyed opener
    /// plus one guidance beat, rotated by thread length so it doesn't repeat.
    private func composeCompanionReply(signName: String, threadCount: Int) -> String {
        let sign = ZodiacSign(rawValue: signName.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == signName.lowercased() }
            ?? .sagittarius

        let openers = AstrologyTemplates.companionReplyOpeners[sign.element.rawValue] ?? []
        let guidance = AstrologyTemplates.companionReplyGuidance[sign.element.rawValue] ?? []

        let opener = openers.isEmpty ? "" : openers[threadCount % openers.count]
        let beat = guidance.isEmpty
            ? "Say it plainly, once, and give the reply room to land."
            : guidance[(threadCount / max(openers.count, 1) + threadCount) % guidance.count]

        return [opener, beat]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func saveMessages() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(companionMessages) else { return }
        UserDefaults.standard.set(data, forKey: companionMessagesKey)
    }

    func markMessageRead(_ message: CompanionMessage) {
        if message.source == .companion {
            markCompanionThreadRead(message.companionId)
        } else {
            for index in discoveryMessages.indices where discoveryMessages[index].companionId == message.companionId {
                if discoveryMessages[index].direction == .incoming {
                    discoveryMessages[index].isRead = true
                }
            }
            Task {
                do {
                    try await supabase.markDiscoveryConversationRead(with: message.companionId)
                } catch {
                    CrashReporter.log(error, context: "markDiscoveryMessageRead")
                }
            }
        }
    }

    func deleteMessage(_ message: CompanionMessage) {
        if message.source == .companion {
            // Inbox rows represent whole threads now — remove the conversation.
            companionMessages.removeAll { $0.companionId == message.companionId }
            saveMessages()
        } else {
            discoveryMessages.removeAll { $0.companionId == message.companionId }
            Task {
                do {
                    try await supabase.deleteDiscoveryConversation(with: message.companionId)
                } catch {
                    CrashReporter.log(error, context: "deleteDiscoveryMessage")
                    showToast("Couldn't delete conversation", subtitle: "It may reappear after your next refresh.", isError: true)
                }
            }
        }
    }

    func generateCompanionMessages() {
        let now = Date()
        let calendar = Calendar.current

        for companion in companions {
            let signKey = companion.sunSign.capitalized
            guard let templates = AstrologyTemplates.companionProactiveMessages[signKey], !templates.isEmpty else { continue }

            // Find the most recent message from this companion
            let lastMessage = companionMessages
                .filter { $0.source == .companion && $0.companionId == companion.id }
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
        discoveryMessages = []
        panelMessages = []
        panelTypingParticipantIds = []
        panelMemoryNotes = []
        moments = []
        momentTypingKeys = []
        momentsStore.deleteAll()
        discoveredProfiles = []
        relationshipPeople = []
        predictionDraft = nil
        bonusPredictions = 0
        isDiscoverable = false
        socialDisplayName = ""
        socialBio = ""
        socialLinks = SocialLinks()
        referralInfo = nil
        hasAcceptedThirdPartyConsent = false
        profileImage = nil
        profileImageURL = nil
        auraWalletPublicAddress = ""
        auraWalletLastCheckedAt = nil
        useAuraWalletForAura = true
        privateNotificationsEnabled = true

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: savedGuidesKey)
        defaults.removeObject(forKey: companionMessagesKey)
        defaults.removeObject(forKey: Self.panelMessagesKey)
        defaults.removeObject(forKey: Self.panelDailyStarterDayKey)
        defaults.removeObject(forKey: Self.panelMemoryNotesKey)
        defaults.removeObject(forKey: Self.panelWeeklyRecapWeekKey)
        defaults.removeObject(forKey: Self.panelWelcomeBackDayKey)
        defaults.removeObject(forKey: socialLinksKey)
        defaults.removeObject(forKey: socialDisplayNameKey)
        defaults.removeObject(forKey: socialBioKey)
        defaults.removeObject(forKey: isDiscoverableKey)
        defaults.removeObject(forKey: referralInfoKey)
        defaults.removeObject(forKey: thirdPartyConsentKey)
        defaults.removeObject(forKey: profileImageURLKey)
        defaults.removeObject(forKey: lastDiscoveryMessageTimestampKey)
        defaults.removeObject(forKey: auraWalletPublicAddressKey)
        defaults.removeObject(forKey: auraWalletUseInAuraKey)
        defaults.removeObject(forKey: auraWalletLastCheckedAtKey)
        defaults.removeObject(forKey: privateNotificationsEnabledKey)
        defaults.removeObject(forKey: AIAstrologistsView.gramCommentsDefaultsKey)

        relationshipPeopleStore.deleteAll()
        deleteProfileImage()
    }

    private func zodiacSign(from value: String) -> ZodiacSign? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ZodiacSign(rawValue: normalized)
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == normalized }
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
            "isDiscoverable": isDiscoverable,
            "privateNotificationsEnabled": privateNotificationsEnabled,
            "useAuraWalletForAura": useAuraWalletForAura
        ]

        exportData["auraWalletContext"] = [
            "hasPublicWallet": hasAuraWalletContext,
            "publicAddress": auraWalletPublicAddress,
            "provider": hasAuraWalletContext ? "Manual public wallet" : "",
            "readOnlyPurpose": "Aura calculation",
            "lastCheckedAt": auraWalletLastCheckedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
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

#if DEBUG
extension AppViewModel {
    @discardableResult
    func applyDebugPreviewStateIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        guard arguments.contains("-SimastryPreviewSeeded") else {
            return false
        }

        // Pre-auth screens render without the seeded session.
        if debugPreviewScreen(from: arguments) == "birthDetails" {
            isDebugPreviewStateActive = true
            isAgeVerified = true
            currentScreen = .birthDetails
            return true
        }

        let userId = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
        let companionId = UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID()
        let now = Date()

        isAuthenticated = true
        isDebugPreviewStateActive = true
        isAgeVerified = true
        hasAcceptedThirdPartyConsent = true
        currentScreen = .home
        homeSetupPhase = .complete

        profile = UserProfile(
            id: userId,
            displayName: "Maya",
            sunSign: ZodiacSign.sagittarius.rawValue,
            moonSign: ZodiacSign.cancer.rawValue,
            risingSign: ZodiacSign.libra.rawValue,
            theme: "dark",
            tier: "pro",
            dailyMessagesUsed: 1,
            dailyMessagesResetDate: now,
            weeklyPredictionsUsed: 1,
            weeklyPredictionsResetDate: now,
            createdAt: now.addingTimeInterval(-14 * 24 * 60 * 60)
        )

        userSunSign = .sagittarius
        userMoonSign = .cancer
        userRisingSign = .libra

        let companion = CompanionData(
            id: companionId,
            userId: userId,
            name: "Nadia",
            mode: CompanionMode.soulmate.rawValue,
            sunSign: ZodiacSign.sagittarius.rawValue,
            moonSign: ZodiacSign.cancer.rawValue,
            risingSign: ZodiacSign.libra.rawValue,
            appearanceStyle: AppearanceStyle.warm.rawValue,
            conversationCount: 42,
            firstConversationAt: now.addingTimeInterval(-9 * 24 * 60 * 60),
            compatibilityScore: 91,
            companionMemory: "Nadia helps Maya separate direct Sagittarius timing from Cancer Moon sensitivity before replying.",
            relationshipLevel: RelationshipLevel.familiar.rawValue,
            createdAt: now.addingTimeInterval(-12 * 24 * 60 * 60)
        )
        companions = [companion]

        companionMessages = [
            CompanionMessage(
                companionId: companionId,
                companionName: "Nadia",
                companionSign: ZodiacSign.sagittarius.displayName,
                content: "I am reading this through Sagittarius directness, but your Cancer Moon may be making the silence feel more personal than it is. Separate the tone from the fear before you answer.",
                timestamp: now.addingTimeInterval(-18 * 60),
                isRead: false
            ),
            CompanionMessage(
                companionId: companionId,
                companionName: "Nadia",
                companionSign: ZodiacSign.sagittarius.displayName,
                content: "The clean reply is short, honest, and not over-explained. Give them room to meet you.",
                timestamp: now.addingTimeInterval(-2 * 60 * 60),
                isRead: true
            )
        ]
        discoveryMessages = []
        relationshipPeople = RelationshipPeopleStore.previewPeople()

        savedGuides = [
            SavedGuide(
                name: "Nadia",
                sunSign: .sagittarius,
                category: .romantic,
                createdAt: now.addingTimeInterval(-5 * 24 * 60 * 60),
                notes: "Use directness, space, and timing. Avoid emotional cornering."
            ),
            SavedGuide(
                name: "Work Libra",
                sunSign: .libra,
                category: .work,
                createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60),
                notes: "Name both sides, then ask for a clear decision."
            )
        ]

        selectedTab = debugPreviewTab(from: arguments)
        if selectedTab == 3 {
            selectedTab = 0
        }
        predictionDraft = nil

        if selectedTab == 4 {
            selectedTab = 0
            guideFocusSign = nil
        } else {
            guideFocusSign = nil
        }

        UserDefaults.standard.set("MAYA2626", forKey: Self.personalInviteCodeKey)

        switch debugPreviewScreen(from: arguments) {
        case "onboardingInsight":
            homeSetupPhase = .onboardingInsight
        case "modeSelection":
            homeSetupPhase = .modeSelection
        case "companionSetup":
            homeSetupPhase = .companionSetup
        case "astrologists":
            // Home must be mounted before the route-request observer fires.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.openAIAstrologists()
            }
        case "predict":
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.openPredict()
            }
        case "panelChat":
            seedDebugPanelMessages(now: now)
            selectedTab = 2
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.panelChatRouteRequest += 1
            }
        case "panelInbox":
            seedDebugPanelMessages(now: now)
            selectedTab = 2
        case "moments":
            seedDebugMoments(now: now)
            selectedTab = 5
        case "invite":
            selectedTab = 5
        case "playbook":
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            selectedTab = 1
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.peopleDetailRequestPersonId = self.relationshipPeople.first?.id
            }
        case "teamRead":
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            selectedTab = 1
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.teamReadRouteRequest += 1
            }
        case "recap":
            seedDebugPanelMessages(now: now)
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            let recapStats = WeeklyRecapStats(
                predictionsMade: 4,
                predictionsRated: 3,
                predictionsLanded: 2,
                panelMessagesSent: 6,
                momentsPosted: 2,
                streak: 5,
                topGuideName: "Nadia"
            )
            panelMessages.append(
                PanelMessage(
                    senderId: "sagittarius-nadia",
                    content: WeeklyRecapComposer.recapMessage(stats: recapStats, guideName: "Nadia", userFirstName: "Maya"),
                    timestamp: now.addingTimeInterval(-5 * 60),
                    isRead: false
                )
            )
            selectedTab = 2
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.panelChatRouteRequest += 1
            }
        default:
            break
        }

        return true
    }

    /// Deterministic panel thread for screenshots: the Maya chart's guides
    /// (Nadia · Sun, Mila · Moon, Isolde · Rising) plus one user turn.
    private func seedDebugPanelMessages(now: Date) {
        panelMessages = [
            PanelMessage(
                senderId: "sagittarius-nadia",
                content: "Hey Maya — I read with your Sagittarius Sun. When a message has you circling, bring it here.",
                timestamp: now.addingTimeInterval(-50 * 60),
                isRead: true
            ),
            PanelMessage(
                senderId: "cancer-mila",
                content: "I hold your Cancer Moon lens — how it actually feels before you answer. Nothing you say here needs to be polished.",
                timestamp: now.addingTimeInterval(-49 * 60),
                isRead: true
            ),
            PanelMessage(
                senderId: "libra-isolde",
                content: "And I read your Libra Rising — the tone you open with. The three of us see the same thread differently on purpose. Ask us anything.",
                timestamp: now.addingTimeInterval(-48 * 60),
                isRead: true
            ),
            PanelMessage(
                senderId: PanelParticipant.localUserId,
                content: "They left me on read since yesterday. Do I follow up or wait?",
                timestamp: now.addingTimeInterval(-31 * 60),
                isRead: true
            ),
            PanelMessage(
                senderId: "sagittarius-nadia",
                content: "Good. You said it instead of circling it. If you're asking whether to reach out — that's already your answer. Keep it short.",
                timestamp: now.addingTimeInterval(-30 * 60),
                isRead: true
            ),
            PanelMessage(
                senderId: "cancer-mila",
                content: "Nadia is right about the timing, but feel it once before you send it.",
                timestamp: now.addingTimeInterval(-29 * 60),
                isRead: false
            )
        ]
    }

    /// Two generated moments with guide comments for screenshots.
    private func seedDebugMoments(now: Date) {
        func solidImageData(_ color: UIColor) -> Data? {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900))
            let image = renderer.image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))
            }
            return image.jpegData(compressionQuality: 0.8)
        }

        var seeded: [Moment] = []

        if let data = solidImageData(UIColor(red: 0.42, green: 0.33, blue: 0.62, alpha: 1)) {
            var moment = Moment(
                caption: "Finally said the honest thing",
                imageFileName: "preview-moment-1.jpg",
                createdAt: now.addingTimeInterval(-3 * 60 * 60),
                reactionCount: 4
            )
            momentsStore.writeImage(data, fileName: moment.imageFileName)
            moment.comments = [
                MomentComment(
                    authorKind: .guide(profileId: "sagittarius-nadia"),
                    authorName: "Nadia",
                    content: "\u{201C}Finally said the honest thing\u{201D} — that's the whole read, honestly.",
                    timestamp: now.addingTimeInterval(-175 * 60)
                ),
                MomentComment(
                    authorKind: .guide(profileId: "libra-isolde"),
                    authorName: "Isolde",
                    content: "Your Libra Rising chose the tone here — light, but not careless.",
                    timestamp: now.addingTimeInterval(-170 * 60)
                )
            ]
            seeded.append(moment)
        }

        if let data = solidImageData(UIColor(red: 0.86, green: 0.62, blue: 0.36, alpha: 1)) {
            var moment = Moment(
                caption: nil,
                imageFileName: "preview-moment-2.jpg",
                createdAt: now.addingTimeInterval(-26 * 60 * 60),
                reactionCount: 2
            )
            momentsStore.writeImage(data, fileName: moment.imageFileName)
            moment.comments = [
                MomentComment(
                    authorKind: .guide(profileId: "cancer-mila"),
                    authorName: "Mila",
                    content: "Something about this one feels settled. Hold onto that.",
                    timestamp: now.addingTimeInterval(-25 * 60 * 60)
                )
            ]
            seeded.append(moment)
        }

        moments = seeded
    }

    private func debugPreviewScreen(from arguments: [String]) -> String? {
        guard let flagIndex = arguments.firstIndex(of: "-SimastryPreviewScreen"),
              arguments.indices.contains(arguments.index(after: flagIndex)) else {
            return nil
        }

        return arguments[arguments.index(after: flagIndex)]
    }

    private func debugPreviewTab(from arguments: [String]) -> Int {
        guard let tabFlagIndex = arguments.firstIndex(of: "-SimastryPreviewTab"),
              arguments.indices.contains(arguments.index(after: tabFlagIndex)),
              let tab = Int(arguments[arguments.index(after: tabFlagIndex)]) else {
            return 0
        }

        return min(max(tab, 0), 5)
    }
}
#endif

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

// MARK: - Prediction Pack (Consumable IAP)

enum PredictionPack: String, CaseIterable {
    case small = "simastry_predictions_5"
    case medium = "simastry_predictions_15"
    case large = "simastry_predictions_50"

    var count: Int {
        switch self {
        case .small: return 5
        case .medium: return 15
        case .large: return 50
        }
    }

    var price: String {
        switch self {
        case .small: return "$0.99"
        case .medium: return "$1.99"
        case .large: return "$4.99"
        }
    }

    var savings: String? {
        switch self {
        case .small: return nil
        case .medium: return "Save 33%"
        case .large: return "Best Value"
        }
    }
}
