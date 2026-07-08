import SwiftUI
import AuthenticationServices
import RevenueCat
import WidgetKit

@MainActor
@Observable
class AppViewModel {
    nonisolated static let shortcutDestinationKey = "simastry_pending_shortcut_destination"

    var currentScreen: AppScreen = .loading
    var homeSetupPhase: HomeSetupPhase = .modeSelection
    var isAuthenticated: Bool = false
    #if DEBUG
    var isDebugPreviewStateActive: Bool = false
    var keepsDebugRelationshipPeopleEmpty: Bool = false
    #endif
    var profile: UserProfile?
    var companions: [CompanionData] = []
    var selectedMode: CompanionMode = .soulmate

    var userSunSign: ZodiacSign?
    var userMoonSign: ZodiacSign?
    var userRisingSign: ZodiacSign?
    var auraSnapshot: AuraSnapshot?

    // MARK: - Profile Image (Local Storage)
    // Extension point: When Supabase Storage is configured, extend
    // saveProfileImage/loadProfileImage to upload/download from cloud storage.
    var profileImage: UIImage?
    var profileImageURL: String?
    private let profileImageFileName = "profile_image.jpg"
    private let profileImageURLKey = "simastry_profile_image_url"
    private let socialLinksKey = "socialLinks"
    private let publicUsernameKey = "simastry_public_username"
    private let socialDisplayNameKey = "socialDisplayName"
    private let socialBioKey = "socialBio"
    private let communicationHintKey = "simastry_communication_hint"
    private let iceBreakersKey = "simastry_ice_breakers"
    private let isDiscoverableKey = "isDiscoverable"
    private let thirdPartyConsentKey = "thirdPartyDataConsent"
    private let auraWalletPublicAddressKey = "simastry_aura_wallet_public_address"
    private let auraWalletHoldingsKey = "simastry_aura_wallet_holdings"
    private let auraWalletUseInAuraKey = "simastry_aura_wallet_use_in_aura"
    private let auraWalletLastCheckedAtKey = "simastry_aura_wallet_last_checked_at"
    private let privateNotificationsEnabledKey = "simastry_private_notifications_enabled"
    private let conversationSuggestionsEnabledKey = "simastry_conversation_suggestions_enabled"

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
    var specialistMessages: [SpecialistMessage] = []
    var specialistConsultationResponses: [SpecialistConsultationResponse] = []
    var typingSpecialistIds: Set<String> = []
    /// Transient per-specialist send failures (never persisted, never written
    /// into the transcript) so the conversation can offer an inline retry.
    var failedSpecialistSends: [String: FailedSpecialistSend] = [:]
    var runningEveryoneConsultationIds: Set<UUID> = []
    var runningEveryoneResponseKeys: Set<String> = []
    var pendingExpertAstrologerQuestion: String?
    var pendingExpertAstrologerAutoRunEveryone: Bool = false
    var pendingExpertAstrologerSpecialistId: String?
    var expertManualAstrologyData: ExpertManualAstrologyData = ExpertManualAstrologyData.load() {
        didSet {
            expertManualAstrologyData.save()
        }
    }
    /// Cached chart-import rows (newest first) so the readiness/person UI can
    /// reflect uploaded screenshots without refetching per view.
    var expertChartImports: [ExpertChartImportRecord] = []
    #if DEBUG
    var consumedExpertAstrologerPreviewFailures: Set<String> = []
    #endif
    var discoveryMessages: [CompanionMessage] = []
    var chatThreadSummaries: [ChatThreadSummary] = []
    var chatMessagesByThreadId: [UUID: [ChatMessage]] = [:]
    var roomGuideTypingKeys: Set<String> = []
    var savedGuides: [SavedGuide] = []
    var relationshipPeople: [RelationshipPerson] = []
    var pendingInviteCodeForConfirmation: String?

    // MARK: - Social Discovery
    var isDiscoverable: Bool = UserDefaults.standard.bool(forKey: "isDiscoverable") {
        didSet {
            UserDefaults.standard.set(isDiscoverable, forKey: isDiscoverableKey)
        }
    }
    var discoveredProfiles: [SocialProfile] {
        get { profileDiscoveryStore.discoveredProfiles }
        set { profileDiscoveryStore.discoveredProfiles = newValue }
    }
    var connectedProfiles: [SocialProfile] {
        get { profileDiscoveryStore.connectedProfiles }
        set { profileDiscoveryStore.connectedProfiles = newValue }
    }
    var publicUsername: String = UserDefaults.standard.string(forKey: "simastry_public_username") ?? "" {
        didSet {
            UserDefaults.standard.set(PublicProfile.normalizedUsername(publicUsername), forKey: publicUsernameKey)
        }
    }
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
    var communicationHint: String = UserDefaults.standard.string(forKey: "simastry_communication_hint") ?? "" {
        didSet {
            UserDefaults.standard.set(communicationHint, forKey: communicationHintKey)
        }
    }
    var iceBreakers: [String] = {
        guard let data = UserDefaults.standard.data(forKey: "simastry_ice_breakers"),
              let prompts = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return prompts
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(iceBreakers) {
                UserDefaults.standard.set(data, forKey: iceBreakersKey)
            }
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

    var auraWalletHoldings: AuraWalletHoldings? = AppViewModel.loadAuraWalletHoldings() {
        didSet {
            Self.saveAuraWalletHoldings(auraWalletHoldings)
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
    var isAuraWalletRefreshing: Bool = false
    var auraWalletLookupStatus: AuraWalletLookupStatus = .idle

    /// Opt-in: notifications stay off until the user explicitly enables the
    /// daily note, so the permission prompt is always tied to that choice.
    var privateNotificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "simastry_private_notifications_enabled") {
        didSet {
            UserDefaults.standard.set(privateNotificationsEnabled, forKey: privateNotificationsEnabledKey)
        }
    }

    /// Which expert writes the daily note (Today card, morning push, widget).
    var dailyNoteSpecialistId: String = UserDefaults.standard.string(forKey: "simastry_daily_note_specialist_id") ?? "leyla-western" {
        didSet {
            UserDefaults.standard.set(dailyNoteSpecialistId, forKey: "simastry_daily_note_specialist_id")
            // Tomorrow's push should speak in the newly chosen voice.
            if isAuthenticated, privateNotificationsEnabled {
                scheduleDailyMorningNoteNotification()
            }
            publishDailyNotesForWidget()
        }
    }

    var dailyNoteSpecialist: AstrologySpecialist? {
        ExpertAstrologerRegistry.specialist(id: dailyNoteSpecialistId)
            ?? ExpertAstrologerRegistry.specialists.first
    }

    var conversationSuggestionsEnabled: Bool = UserDefaults.standard.object(forKey: "simastry_conversation_suggestions_enabled") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "simastry_conversation_suggestions_enabled") {
        didSet {
            UserDefaults.standard.set(conversationSuggestionsEnabled, forKey: conversationSuggestionsEnabledKey)
        }
    }

    var toastMessage: ToastMessage?
    var isDarkMode: Bool = UserDefaults.standard.object(forKey: "simastry_dark_mode") == nil ? true : UserDefaults.standard.bool(forKey: "simastry_dark_mode") {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "simastry_dark_mode")
        }
    }
    var showUpsell: Bool = false
    var selectedTab: AppTab = .today
    /// A prediction is awaiting its real-world outcome — drives the Predict tab
    /// follow-up dot until the user logs Landed / Unclear / Wrong / Not yet.
    var predictFollowUpPending: Bool = UserDefaults.standard.bool(forKey: "simastry_predict_followup_pending") {
        didSet {
            UserDefaults.standard.set(predictFollowUpPending, forKey: "simastry_predict_followup_pending")
        }
    }
    var aiAstrologistsRouteRequest: Int = 0
    var predictRouteRequest: Int = 0
    /// Bumped to ask HomeView to open the profile drawer.
    var profileDrawerRouteRequest: Int = 0
    /// Bumped to ask ProfileView to present the Aura sheet.
    var auraRouteRequest: Int = 0
    /// Bumped to ask ProfileView to present the consolidated share card.
    var shareCardRouteRequest: Int = 0
    /// Bumped to ask ProfileView to present the Career Read sheet.
    var careerReadRouteRequest: Int = 0
    /// Bumped whenever Method course progress changes so cards re-render.
    var methodCourseVersion: Int = 0
    /// Set to a thread's companionId to ask MessagesView to open it.
    var openThreadRequestCompanionId: UUID?
    /// Bumped to ask HomeView to push the Decode screen.
    var decodeRouteRequest: Int = 0
    /// Preselects the sign when Decode opens from a person's page.
    var decodeDraftSign: ZodiacSign?
    var pendingDeepLinkURL: URL?
    var pendingDeepLink: DeepLink?
    var guideFocusSign: ZodiacSign?
    var predictionDraft: PredictionDraft?
    var firstReadDraft: FirstReadDraft?
    var guideFeedbackEvents: [GuideFeedback] = []
    var referralInfo: ReferralInfo?
    /// Last guide/panel chat safety block. Frontend can present this inline later.
    var lastGuideSafetyMessage: String?

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
    /// Bumped to ask MessagesView to present Practice.
    var practiceRouteRequest: Int = 0
    /// What the panel remembers — People mentioned in conversation (+PanelChat).
    var panelMemoryNotes: [MemoryNote] = []

    // MARK: - People Routing
    /// Set to push a person's detail screen (debug previews, deep links).
    var peopleDetailRequestPersonId: UUID?
    /// Bumped to present the Team Read sheet.
    var teamReadRouteRequest: Int = 0

    // MARK: - Guide Work Lifecycle
    /// Bumped whenever account-scoped local state is cleared; in-flight
    /// delayed guide tasks compare their captured generation and bail if
    /// stale, so a pending reply can never resurrect wiped data.
    var localStateGeneration: Int = 0
    /// Handles for delayed guide replies/comments, cancellable on clear.
    var pendingGuideTaskHandles: [UUID: Task<Void, Never>] = [:]

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
        guard isRevenueCatAvailable else {
            showToast(
                "Prediction packs unavailable",
                subtitle: "Purchases will unlock after App Store products are configured.",
                isError: true
            )
            return
        }

        // Keep consumable packs disabled until App Store products and receipt
        // verification are fully configured.
        showToast(
            "Prediction packs unavailable",
            subtitle: "Purchases are not available in this build yet.",
            isError: true
        )
    }

    func saveAuraWalletInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = AuraWalletHoldings.parse(from: trimmed) else {
            showToast("Aura input not saved", subtitle: "Paste a public wallet address or Zodiac holdings like Aries x3.", isError: true)
            return
        }

        auraWalletPublicAddress = parsed.publicAddress
        auraWalletHoldings = parsed
        auraWalletLastCheckedAt = Date()
        useAuraWalletForAura = true
        auraWalletLookupStatus = parsed.hasZodiacCounts ? .manualCountsActive : .idle

        if parsed.hasZodiacCounts {
            showToast("Zodiacs added to Aura", subtitle: parsed.summaryLine, isError: false)
        } else {
            showToast("Wallet saved", subtitle: "Looking for official Zodiacs now.", isError: false)
        }
    }

    func saveAuraWalletPublicAddress(_ address: String) {
        saveAuraWalletInput(address)
    }

    func refreshAuraWalletHoldingsFromAddress() async {
        let address = auraWalletPublicAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return }

        isAuraWalletRefreshing = true
        auraWalletLookupStatus = .checking
        defer { isAuraWalletRefreshing = false }

        do {
            let officialHoldings = try await ZodiacsWalletService.shared.fetchHoldings(for: address, service: supabase)
            auraWalletHoldings = officialHoldings
            auraWalletLastCheckedAt = Date()
            useAuraWalletForAura = true

            if officialHoldings.hasZodiacCounts {
                auraWalletLookupStatus = .found
                showToast("Zodiacs found", subtitle: officialHoldings.summaryLine, isError: false)
            } else {
                auraWalletLookupStatus = .notFound
                showToast("No Zodiacs found", subtitle: "This address has no official Zodiacs on supported chains yet.", isError: false)
            }
        } catch {
            if auraWalletTotalZodiacs > 0 {
                auraWalletLookupStatus = .manualCountsActive
                showToast("Using pasted counts", subtitle: "Secure wallet lookup is unavailable right now.", isError: false)
            } else {
                auraWalletLookupStatus = .unavailable
                showToast("Wallet lookup unavailable", subtitle: "Paste Zodiac counts like Aries x3 if you want to tune Aura now.", isError: true)
            }
        }
    }

    func clearAuraWalletContext() {
        auraWalletPublicAddress = ""
        auraWalletHoldings = nil
        auraWalletLastCheckedAt = nil
        isAuraWalletRefreshing = false
        auraWalletLookupStatus = .idle
        showToast("Wallet removed", subtitle: "Aura will use chart signals only.", isError: false)
    }

    func reloadAuraSnapshot() {
        auraSnapshot = auraSnapshotStore.load()
    }

    @discardableResult
    func applyAuraSnapshot(image: UIImage, mood: AuraSnapshotMood) -> AuraSnapshot? {
        guard let snapshot = auraSnapshotService.makeSnapshot(
            from: image,
            mood: mood,
            userSunSign: userSunSign,
            userMoonSign: userMoonSign,
            userRisingSign: userRisingSign
        ) else {
            showToast("Snapshot not saved", subtitle: "Try a clearer photo.", isError: true)
            return nil
        }

        auraSnapshotStore.save(snapshot)
        auraSnapshot = snapshot
        showToast("Aura Snapshot ready", subtitle: snapshot.descriptor.displayLine, isError: false)
        return snapshot
    }

    func clearAuraSnapshot() {
        auraSnapshotStore.clear()
        auraSnapshot = nil
        showToast("Aura Snapshot cleared", subtitle: "Today will use chart signals only.", isError: false)
    }

    static func isSupportedPublicWalletAddress(_ address: String) -> Bool {
        AuraWalletHoldings.isSupportedPublicWalletAddress(address)
    }

    static func canParseAuraWalletInput(_ input: String) -> Bool {
        AuraWalletHoldings.canParse(input)
    }

    static func auraWalletInputSummary(_ input: String) -> String {
        AuraWalletHoldings.parse(from: input)?.summaryLine ?? ""
    }

    private static func loadAuraWalletHoldings() -> AuraWalletHoldings? {
        guard let data = UserDefaults.standard.data(forKey: "simastry_aura_wallet_holdings") else {
            return nil
        }
        return try? JSONDecoder().decode(AuraWalletHoldings.self, from: data)
    }

    private static func saveAuraWalletHoldings(_ holdings: AuraWalletHoldings?) {
        let key = "simastry_aura_wallet_holdings"
        guard let holdings else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(holdings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Safety Gates
    var isAgeVerified: Bool = UserDefaults.standard.bool(forKey: "ageVerified")
    var hasAcceptedThirdPartyConsent: Bool = UserDefaults.standard.bool(forKey: "thirdPartyDataConsent")
    var firstReadOnboardingIntent: FirstReadOnboardingIntent? = {
        UserDefaults.standard.string(forKey: "simastry_first_read_onboarding_intent")
            .flatMap(FirstReadOnboardingIntent.init(rawValue:))
    }() {
        didSet {
            if let firstReadOnboardingIntent {
                UserDefaults.standard.set(firstReadOnboardingIntent.rawValue, forKey: "simastry_first_read_onboarding_intent")
            } else {
                UserDefaults.standard.removeObject(forKey: "simastry_first_read_onboarding_intent")
            }
        }
    }

    let analytics = AnalyticsService.shared
    let supabase = SupabaseService()
    let profileDiscoveryStore: ProfileDiscoveryStore
    let todayStore: TodayStore
    let notificationService = NotificationService()
    let predictionService = PredictionService()
    let dailyDecisionService = DailyDecisionService()
    let auraSnapshotService = AuraSnapshotService()
    let auraSnapshotStore = AuraSnapshotStore()
    let predictionRateLimiter = RateLimiter(config: .init(
        maxPerMinute: AppConfig.predictionRateLimit.perMinute,
        maxPerHour: AppConfig.predictionRateLimit.perHour,
        maxPerDay: AppConfig.predictionRateLimit.perDay
    ))
    private let pendingOnboardingChartKey = "simastry_pending_onboarding_chart"
    static let firstReadOnboardingIntentDefaultsKey = "simastry_first_read_onboarding_intent"
    private let referralInfoKey = "simastry_referral_info"
    private let companionMessagesKey = "simastry_companion_messages"
    static let specialistMessagesKey = "simastry_expert_astrologer_messages"
    static let specialistConsultationResponsesKey = "simastry_expert_astrologer_consultation_responses"
    static let specialistConversationIdsKey = "simastry_expert_astrologer_conversation_ids"
    private let lastMessageGenerationKey = "simastry_last_message_generation"
    private let lastDiscoveryMessageTimestampKey = "simastry_last_discovery_message_timestamp"
    private let firstReadDraftStore = FirstReadDraftStore()
    private let guideFeedbackStore = GuideFeedbackStore()
    private let relationshipPeopleStore = RelationshipPeopleStore()

    var hasAuraWalletContext: Bool {
        !auraWalletPublicAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (auraWalletHoldings?.hasZodiacCounts ?? false)
    }

    var auraWalletShortAddress: String {
        AuraWalletHoldings.shortAddress(auraWalletPublicAddress)
    }

    var auraWalletDisplayLabel: String {
        auraWalletHoldings?.displayLabel ?? auraWalletShortAddress
    }

    var auraWalletZodiacCounts: [ZodiacSign: Int] {
        auraWalletHoldings?.zodiacCounts ?? [:]
    }

    var auraWalletTotalZodiacs: Int {
        auraWalletHoldings?.totalZodiacs ?? 0
    }

    var auraWalletSummaryLine: String {
        auraWalletHoldings?.summaryLine ?? ""
    }

    init() {
        profileDiscoveryStore = ProfileDiscoveryStore(service: supabase)
        todayStore = TodayStore()
        loadReferralInfo()
        reloadAuraSnapshot()
        loadRelationshipPeople()
        loadFirstReadDraft()
        loadGuideFeedback()
        loadExpertAstrologerState()
        loadPanelMessages()
        loadPanelMemoryNotes()
        loadMoments()

        // Server-proxied AI channel: predictions route through the
        // companion-reply edge function when Supabase is configured.
        predictionService.replyChannel = { [supabase] system, user in
            try await supabase.invokeCompanionReply(
                kind: .prediction,
                feature: .prediction,
                system: system,
                user: user
            )
        }
        predictionService.isRemoteChannelAvailable = { [supabase] in
            supabase.canInvokeCompanionReply
        }

        dailyDecisionService.replyChannel = { [supabase] system, user in
            try await supabase.invokeCompanionReply(
                kind: .chat,
                feature: .dailyDecision,
                system: system,
                user: user,
                maxTokens: 180
            )
        }
        dailyDecisionService.isRemoteChannelAvailable = { [supabase] in
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
        // Skip the legacy 3-way choice — go straight to collecting birth details,
        // then the five-expert first read.
        firstReadOnboardingIntent = .astrologer
        withAnimation(.spring(SimastrySpring.smooth)) {
            currentScreen = .birthDetails
        }
    }

    func chooseFirstReadIntent(_ intent: FirstReadOnboardingIntent) {
        firstReadOnboardingIntent = intent
        withAnimation(.spring(SimastrySpring.smooth)) {
            switch intent {
            case .predict:
                currentScreen = .firstPrediction
            case .astrologer:
                currentScreen = .birthDetails
            case .decode:
                currentScreen = .firstRead
            }
        }
    }

    func continueToBirthDetails(after intent: FirstReadOnboardingIntent? = nil) {
        if let intent {
            firstReadOnboardingIntent = intent
        }
        withAnimation(.spring(SimastrySpring.smooth)) {
            currentScreen = .birthDetails
        }
    }

    func clearFirstReadOnboardingIntent() {
        firstReadOnboardingIntent = nil
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

    func openAIAstrologists(question: String? = nil, autoRunEveryone: Bool = false, specialistId: String? = nil) {
        let trimmedQuestion = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingExpertAstrologerQuestion = (trimmedQuestion?.isEmpty ?? true) ? nil : trimmedQuestion
        pendingExpertAstrologerAutoRunEveryone = pendingExpertAstrologerQuestion != nil && autoRunEveryone
        pendingExpertAstrologerSpecialistId = specialistId
        selectedTab = .today
        homeSetupPhase = .complete
        aiAstrologistsRouteRequest += 1
    }

    func openPredict(with draft: PredictionDraft? = nil) {
        if let draft {
            predictionDraft = draft
        }
        homeSetupPhase = .complete
        // Predict is now a first-class tab; SimulateView consumes the draft on
        // appear / change, so we just select the tab.
        selectedTab = .predict
    }

    func openPractice() {
        homeSetupPhase = .complete
        selectedTab = .messages
        practiceRouteRequest += 1
    }

    func openProfileDrawer() {
        homeSetupPhase = .complete
        selectedTab = .today
        profileDrawerRouteRequest += 1
    }

    func loadRelationshipPeople() {
        #if DEBUG
        if keepsDebugRelationshipPeopleEmpty {
            relationshipPeople = []
            return
        }
        #endif
        relationshipPeople = relationshipPeopleStore.loadPeople()
    }

    func addRelationshipPerson(_ person: RelationshipPerson) {
        relationshipPeople.append(person)
        saveRelationshipPeople()
    }

    private func loadFirstReadDraft() {
        firstReadDraft = firstReadDraftStore.load()
    }

    private func loadGuideFeedback() {
        guideFeedbackEvents = guideFeedbackStore.load()
    }

    func saveFirstReadDraft(_ draft: FirstReadDraft) {
        firstReadDraft = draft
        firstReadDraftStore.save(draft)
    }

    func dismissFirstReadDraft() {
        guard var draft = firstReadDraft else { return }
        draft.dismissedAt = Date()
        saveFirstReadDraft(draft)
    }

    func clearFirstReadDraft() {
        firstReadDraft = nil
        firstReadDraftStore.clear()
    }

    func consumeFirstReadOnboardingIntentIfReady() {
        guard currentScreen == .home,
              homeSetupPhase == .complete,
              let intent = firstReadOnboardingIntent else {
            return
        }

        clearFirstReadOnboardingIntent()

        switch intent {
        case .predict:
            openPredict()
        case .astrologer:
            openAIAstrologists()
        case .decode:
            break
        }
    }

    func recordGuideFeedback(
        readId: UUID,
        aiUsageEventId: UUID? = nil,
        guideId: String?,
        surface: FeedbackSurface,
        helpfulness: HelpfulnessRating,
        reasons: [GuideFeedbackReason] = [],
        freeformNote: String? = nil
    ) {
        let existing = guideFeedbackEvents.first {
            $0.matches(readId: readId, guideId: guideId, surface: surface)
        }
        let event = GuideFeedback(
            id: existing?.id ?? UUID(),
            readId: readId,
            aiUsageEventId: aiUsageEventId ?? existing?.aiUsageEventId,
            guideId: guideId,
            surface: surface,
            helpfulness: helpfulness,
            reasons: reasons,
            freeformNote: freeformNote,
            createdAt: existing?.createdAt ?? Date(),
            syncedAt: nil
        )

        guideFeedbackEvents.removeAll {
            $0.matches(readId: readId, guideId: guideId, surface: surface)
        }
        guideFeedbackEvents.append(event)
        guideFeedbackStore.save(guideFeedbackEvents)
        syncGuideFeedbackIfPossible(event)

        analytics.track(
            surface == .firstRead ? .firstReadHelpfulnessSubmitted : .guideFeedbackSubmitted,
            params: [
                "surface": surface.rawValue,
                "guideId": guideId ?? "none",
                "helpfulness": helpfulness.rawValue,
                "reasonCount": "\(reasons.count)"
            ]
        )
    }

    func guideFeedbackPromptSummary(for guideId: String?) -> String? {
        GuideFeedbackPromptBuilder.promptSummary(from: guideFeedbackEvents, guideId: guideId)
    }

    func refreshGuideFeedbackFromRemote() async {
        guard isAuthenticated else { return }
        do {
            let remoteEvents = try await supabase.fetchGuideFeedback()
            mergeGuideFeedbackEvents(remoteEvents)
            syncPendingGuideFeedbackIfPossible()
        } catch {
            // Feedback sync is quality-improvement metadata. Local feedback
            // remains authoritative when the network is unavailable.
        }
    }

    func clearGuideFeedback() {
        guideFeedbackEvents = []
        guideFeedbackStore.clear()
    }

    private func syncGuideFeedbackIfPossible(_ event: GuideFeedback) {
        guard isAuthenticated else { return }
        Task { [weak self, event] in
            guard let self else { return }
            do {
                try await self.supabase.syncGuideFeedback(event)
                self.markGuideFeedbackSynced(event.id)
            } catch {
                // Keep the local event; a future authenticated launch can
                // merge/fetch server feedback without blocking the user.
            }
        }
    }

    private func syncPendingGuideFeedbackIfPossible() {
        guard isAuthenticated else { return }
        guideFeedbackEvents
            .filter { $0.syncedAt == nil }
            .forEach(syncGuideFeedbackIfPossible)
    }

    private func markGuideFeedbackSynced(_ eventId: UUID) {
        guard let index = guideFeedbackEvents.firstIndex(where: { $0.id == eventId }) else { return }
        guideFeedbackEvents[index].syncedAt = Date()
        guideFeedbackStore.save(guideFeedbackEvents)
    }

    private func mergeGuideFeedbackEvents(_ remoteEvents: [GuideFeedback]) {
        guard !remoteEvents.isEmpty else { return }
        var mergedById = Dictionary(uniqueKeysWithValues: guideFeedbackEvents.map { ($0.id, $0) })
        for remote in remoteEvents {
            if let local = mergedById[remote.id], local.syncedAt == nil {
                var updated = local
                updated.syncedAt = remote.syncedAt ?? Date()
                mergedById[remote.id] = updated
            } else {
                mergedById[remote.id] = remote
            }
        }
        guideFeedbackEvents = dedupedGuideFeedback(Array(mergedById.values))
        guideFeedbackStore.save(guideFeedbackEvents)
    }

    private func dedupedGuideFeedback(_ events: [GuideFeedback]) -> [GuideFeedback] {
        var bestByKey: [String: GuideFeedback] = [:]
        for event in events.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = [
                event.readId.uuidString,
                event.guideId ?? "",
                event.surface.rawValue
            ].joined(separator: "|")
            bestByKey[key] = event
        }
        return bestByKey.values.sorted { $0.createdAt < $1.createdAt }
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
        #if DEBUG
        if isDebugPreviewStateActive {
            return
        }
        #endif
        relationshipPeopleStore.savePeople(relationshipPeople)
    }

    var isRevenueCatAvailable: Bool {
        !AppConfig.revenueCatAPIKey.isEmpty
    }

    func checkAuthState() async {
        await notificationService.checkAuthorizationStatus()

        // Only a definitive sign-out may wipe account-scoped local state.
        // An unverifiable session (offline launch, expired token that can't
        // refresh yet) keeps local data and proceeds with cached state.
        let authState = await supabase.authState()
        guard authState != .signedOut else {
            isAuthenticated = false
            profile = nil
            companions = []
            showUpsell = false
            selectedTab = .today
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
        Task {
            await refreshGuideFeedbackFromRemote()
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
                Task { await refreshGuideFeedbackFromRemote() }
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
            Task { await refreshGuideFeedbackFromRemote() }
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
        clearFirstReadDraft()
        clearGuideFeedback()
        clearAccountScopedLocalState()
        SharedDefaults.clearAll()
        WidgetCenter.shared.reloadAllTimelines()
        isAuthenticated = false
        profile = nil
        companions = []
        showUpsell = false
        selectedTab = .today
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
                try await supabase.deleteGuideFeedback(for: userId.uuidString)
            } catch {
                remoteFailures.append("guide_feedback")
                CrashReporter.log(error, context: "deleteAccountGuideFeedback")
            }

            do {
                try await supabase.deleteExpertAstrologerData(for: userId.uuidString)
            } catch {
                remoteFailures.append("expert_astrologers")
                CrashReporter.log(error, context: "deleteAccountExpertAstrologers")
            }

            // Best-effort: clear uploaded chart screenshots from private storage.
            await supabase.deleteExpertChartImages(for: userId.uuidString)

            do {
                try await supabase.deleteAvatarFiles(for: userId.uuidString)
            } catch {
                remoteFailures.append("avatars")
                CrashReporter.log(error, context: "deleteAccountAvatars")
            }

            do {
                try await supabase.deleteAllCompanions(for: userId.uuidString)
            } catch {
                remoteFailures.append("companions")
                CrashReporter.log(error, context: "deleteAccountCompanions")
            }

            do {
                try await supabase.deleteUserConnections(for: userId.uuidString)
            } catch {
                remoteFailures.append("user_connections")
                CrashReporter.log(error, context: "deleteAccountUserConnections")
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

            do {
                try await supabase.deleteDiscoveryMessages(for: userId.uuidString)
            } catch {
                remoteFailures.append("discovery_messages")
                CrashReporter.log(error, context: "deleteAccountDiscoveryMessages")
            }

            do {
                try await supabase.deleteDiscoveryBlocks(for: userId.uuidString)
            } catch {
                remoteFailures.append("discovery_blocks")
                CrashReporter.log(error, context: "deleteAccountDiscoveryBlocks")
            }

            do {
                try await supabase.deleteDiscoveryReports(for: userId.uuidString)
            } catch {
                remoteFailures.append("discovery_reports")
                CrashReporter.log(error, context: "deleteAccountDiscoveryReports")
            }

            do {
                try await supabase.deleteGuidedRoomData(for: userId.uuidString)
            } catch {
                remoteFailures.append("guided_rooms")
                CrashReporter.log(error, context: "deleteAccountGuidedRooms")
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
        selectedTab = .today
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
        clearFirstReadDraft()
        clearGuideFeedback()

        // Clear UserDefaults
        let keys = ["savedGuides", "simastry_companion_messages", "simastry_profile_image_url",
                    "thirdPartyDataConsent", "isDiscoverable", "simastry_referral_info",
                    "simastry_dark_mode", "appLanguage", "ageVerified",
                    "simastry_conversation_suggestions_enabled",
                    "socialDisplayName", "socialBio", "socialLinks",
                    "positiveActionCount", "lastReviewPromptDate", "reviewPromptCount",
                    "bonusPredictions", "simastry_prediction_history"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // Delete profile image file
        deleteProfileImage()

        // Clear widget data
        SharedDefaults.clearAll()
    }

    func clearLocalDeviceData() {
        notificationService.clearScheduledNotifications()
        clearPendingOnboardingChart()
        clearFirstReadDraft()
        clearGuideFeedback()
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
            selectedTab = .today
        case "companions":
            openAIAstrologists()
        case "people":
            selectedTab = .people
        case "chat":
            selectedTab = .messages
        case "messages":
            selectedTab = .messages
        case "panel":
            openPanelChat()
        case "simulate":
            openPractice()
        case "guides":
            if AppConfig.expertAstrologersEnabled {
                openAIAstrologists()
            } else {
                guideFocusSign = nil
                selectedTab = .today
            }
        case "astropedia":
            guideFocusSign = nil
            selectedTab = .today
        case "profile":
            openProfileDrawer()
        case "upsell":
            if isRevenueCatAvailable {
                showUpsell = true
            } else {
                showToast("Beta access active", subtitle: "Purchases are unavailable in this build.", isError: false)
            }
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
            selectedTab = .people

        case .guide:
            if AppConfig.expertAstrologersEnabled {
                openAIAstrologists()
                return
            }
            guideFocusSign = nil
            selectedTab = .today

        case .guideProfile(let id):
            if AppConfig.expertAstrologersEnabled {
                let mappedSpecialistId = ExpertAstrologerRegistry
                    .specialist(forLegacyCharacterId: id)?
                    .id
                openAIAstrologists(specialistId: mappedSpecialistId)
                return
            }
            selectedTab = .today
            aiAstrologistsRouteRequest += 1
            if let guide = FactoryCompanionCatalog.all.first(where: { $0.id == id }) {
                startGuideChat(guide)
            }

        case .invite(let code):
            requestInviteCodeConfirmation(code)
            selectedTab = .today

        case .messages:
            selectedTab = .messages

        case .person(let id):
            selectedTab = .people
            peopleDetailRequestPersonId = id

        case .predict:
            openPredict()

        case .simulate:
            openPractice()

        case .home:
            selectedTab = .today
        }
    }

    func consumePendingShortcutDestination() {
        guard let destination = UserDefaults.standard.string(forKey: Self.shortcutDestinationKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.shortcutDestinationKey)

        switch destination {
        case "today":
            navigateToDeepLink(.home)
        case "predict":
            navigateToDeepLink(.predict)
        case "messages":
            navigateToDeepLink(.messages)
        case "simulate":
            navigateToDeepLink(.simulate)
        case "expertAstrologers", "nadia":
            openAIAstrologists()
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
        await loadSocialProfile()
        await loadCompanions()
        await refreshExpertAstrologerStateFromRemote()
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
        guard !AppConfig.expertAstrologersEnabled else {
            SharedDefaults.clearAll()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

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
            companionGlyph: companionSign?.compactCode ?? "SIM",
            userSunSign: userSign?.rawValue ?? "",
            userGlyph: userSign?.compactCode ?? "YOU",
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
        syncHomeSetupPhase()
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
            showToast("Subscriptions unavailable", subtitle: "Purchases are not available in this build yet.", isError: true)
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
        guard isRevenueCatAvailable else { return .max }
        switch profile?.tier ?? "free" {
        case "plus", "pro": return .max
        default: return 10
        }
    }

    var weeklyPredictionLimit: Int {
        guard isRevenueCatAvailable else { return .max }
        switch profile?.tier ?? "free" {
        case "plus", "pro": return .max
        default: return 3
        }
    }

    var companionLimit: Int {
        guard isRevenueCatAvailable else { return .max }
        switch profile?.tier ?? "free" {
        case "pro": return .max
        case "plus": return 3
        default: return 1
        }
    }

    var remainingDailyMessages: Int {
        guard isRevenueCatAvailable else { return .max }
        guard var p = profile else { return 10 }
        resetDailyIfNeeded(&p)
        return max(0, dailyMessageLimit - p.dailyMessagesUsed)
    }

    var remainingWeeklyPredictions: Int {
        guard isRevenueCatAvailable else { return .max }
        guard var p = profile else { return 3 }
        resetWeeklyIfNeeded(&p)
        return max(0, weeklyPredictionLimit - p.weeklyPredictionsUsed)
    }

    func canSendMessage() -> Bool {
        guard isRevenueCatAvailable else { return true }
        let tier = profile?.tier ?? "free"
        if tier == "plus" || tier == "pro" { return true }
        return remainingDailyMessages > 0
    }

    func canUsePrediction() -> Bool {
        guard isRevenueCatAvailable else { return true }
        let tier = profile?.tier ?? "free"
        if tier == "plus" || tier == "pro" { return true }
        return remainingWeeklyPredictions > 0
    }

    func consumeMessage() async {
        guard isRevenueCatAvailable else { return }
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
        guard isRevenueCatAvailable else { return }
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

        // Reached only after an explicit enable (or an account that already
        // enabled it), so the permission prompt is tied to a user choice.
        await notificationService.requestFullPermission()
        notificationService.clearScheduledNotifications()
        notificationService.cancelLegacyGuideAndCompanionNotifications()

        if !AppConfig.expertAstrologersEnabled {
            schedulePanelStarterNotification()
            notificationService.scheduleGuideTipNudges()
        }
        scheduleDailyMorningNoteNotification()
        publishDailyNotesForWidget()
    }

    /// Pre-composes today's and tomorrow's notes into the shared app group so
    /// the widget can render (and flip at midnight) without computing anything.
    func publishDailyNotesForWidget() {
        guard let specialist = dailyNoteSpecialist else { return }
        let calendar = Calendar.current
        let today = Date()
        let days = [today, calendar.date(byAdding: .day, value: 1, to: today) ?? today]
        let notes = days.map { day -> SharedDailyNote in
            let note = DailyExpertNoteComposer.note(
                for: specialist.id,
                on: day,
                sun: userSunSign,
                moon: userMoonSign,
                rising: userRisingSign
            )
            return SharedDailyNote(
                dateKey: SharedDailyNote.dateKey(for: day),
                expertName: specialist.characterName,
                headline: note.headline,
                move: note.move
            )
        }
        SharedDefaults.writeDailyNotes(notes)
        WidgetCenter.shared.reloadTimelines(ofKind: "SimastryDailyNote")
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

    /// Schedules the next week of morning pushes in the chosen expert's voice.
    /// Each one-shot notification is composed for its own fire date, matching
    /// the deterministic note the Today card will show that morning.
    func scheduleDailyMorningNoteNotification() {
        guard let specialist = dailyNoteSpecialist else { return }
        let calendar = Calendar.current
        let now = Date()
        let requests = NotificationService.dailyMorningNoteIdentifiers.enumerated().compactMap { index, identifier -> NotificationService.DailyMorningNoteRequest? in
            guard let day = calendar.date(byAdding: .day, value: index + 1, to: now) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = 8
            components.minute = 30
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }

            let body = DailyExpertNoteComposer.notificationBody(
                for: specialist.id,
                on: fireDate,
                sun: userSunSign,
                moon: userMoonSign,
                rising: userRisingSign
            )
            return NotificationService.DailyMorningNoteRequest(
                identifier: identifier,
                expertName: specialist.characterName,
                body: body,
                fireDate: fireDate
            )
        }
        notificationService.scheduleDailyMorningNotes(requests)
    }

    func generateDailyDecision(
        category: DailyDecisionCategory,
        transitReading: DailyTransitReading?
    ) async -> DailyDecision {
        let communicationType = CommunicationTypeProfile.make(
            sun: userSunSign,
            moon: userMoonSign,
            rising: userRisingSign
        )
        let context = DailyDecisionContext(
            userSunSign: userSunSign,
            userMoonSign: userMoonSign,
            userRisingSign: userRisingSign,
            communicationTypeTitle: communicationType?.title,
            transitHeadline: transitReading?.headline,
            transitGuidance: transitReading?.guidance,
            auraSnapshot: auraSnapshot?.descriptor
        )
        let decision = await dailyDecisionService.generateDecision(
            category: category,
            context: context
        )
        todayStore.saveDailyDecision(decision)
        return decision
    }

    func navigateAfterAuth() async {
        await loadProfile()
        if shouldPersistPendingBirthChart {
            await saveUserSigns()
        }
        await loadCompanions()
        loadSavedGuides()
        loadProfileImage()
        syncHomeSetupPhase()
        selectedTab = .today
        currentScreen = .home
        if homeSetupPhase == .complete {
            analytics.track(.onboardingCompleted)
            ReviewPromptService.shared.recordPositiveAction()
        }

        // Resolve any pending deep link from the virality funnel
        if let deepLink = pendingDeepLink {
            self.pendingDeepLink = nil
            self.pendingDeepLinkURL = nil
            navigateToDeepLink(deepLink)
        } else if let pendingDeepLinkURL {
            self.pendingDeepLinkURL = nil
            handleDeepLink(pendingDeepLinkURL)
        } else {
            consumeFirstReadOnboardingIntentIfReady()
        }

        Task { @MainActor in
            await refreshPostLaunchSurfaces()
        }
    }

    private func refreshPostLaunchSurfaces() async {
        await loadSocialProfile()
        await refreshExpertAstrologerStateFromRemote()
        await checkSubscriptionStatus()
        await refreshInbox()
        await setupNotifications()
        updateWidgetData()
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
        guard !AppConfig.expertAstrologersEnabled else {
            homeSetupPhase = .complete
            openAIAstrologists()
            return
        }

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
        consumeFirstReadOnboardingIntentIfReady()
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
        await searchPublicProfiles(query: "")
    }

    func searchPublicProfiles(query: String) async {
        guard AppConfig.socialDiscoveryEnabled else {
            discoveredProfiles = []
            return
        }

        #if DEBUG
        if isDebugPreviewStateActive {
            seedDebugSocialProfiles(now: Date())
            return
        }
        #endif

        do {
            let fallbackCurrentUserId = await supabase.currentUserId
            let currentUserId = profile?.id ?? fallbackCurrentUserId
            try await profileDiscoveryStore.search(query: query, currentUserId: currentUserId)
            discoveredProfiles = discoveredProfiles
                .sorted { compatibilityWithUser(for: $0) > compatibilityWithUser(for: $1) }
        } catch {
            CrashReporter.log(error, context: "fetchDiscoverableProfiles")
            showToast("Couldn't load discovery", subtitle: "Check your connection or try again later.", isError: true)
        }
    }

    func fetchConnectedProfiles() async {
        guard AppConfig.socialDiscoveryEnabled else {
            connectedProfiles = []
            return
        }
        #if DEBUG
        if isDebugPreviewStateActive {
            seedDebugSocialProfiles(now: Date())
            return
        }
        #endif
        do {
            try await profileDiscoveryStore.refreshConnections()
        } catch {
            CrashReporter.log(error, context: "fetchConnectedProfiles")
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

        #if DEBUG
        if isDebugPreviewStateActive {
            appendLocalDiscoveryMessage(remoteMessage, viewerId: currentProfile.id)
            showToast("Intro ready", subtitle: "Debug preview kept this discovery chat local.", isError: false)
            return true
        }
        #endif

        do {
            try await supabase.sendDiscoveryMessage(remoteMessage)
            appendLocalDiscoveryMessage(remoteMessage, viewerId: currentProfile.id)
            await consumeMessage()
            showToast("Intro sent", subtitle: "\(profile.displayName) will see it in their inbox.", isError: false)
            return true
        } catch {
            CrashReporter.log(error, context: "sendDiscoveryMessage")
            showToast(
                "Couldn't send intro",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                isError: true
            )
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
            showToast(
                "Couldn't send reply",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                isError: true
            )
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
            showToast(
                "Couldn't block profile",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                isError: true
            )
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
            showToast(
                "Couldn't send report",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                isError: true
            )
        }
    }

    func loadSocialProfile() async {
        guard AppConfig.socialDiscoveryEnabled else { return }

        #if DEBUG
        if isDebugPreviewStateActive {
            seedDebugSocialProfiles(now: Date())
            return
        }
        #endif

        do {
            if let remoteProfile = try await supabase.fetchCurrentSocialProfile() {
                publicUsername = remoteProfile.username ?? ""
                socialDisplayName = remoteProfile.displayName
                socialBio = remoteProfile.bio ?? ""
                socialLinks = remoteProfile.socialLinks ?? SocialLinks()
                communicationHint = remoteProfile.communicationHint ?? ""
                iceBreakers = remoteProfile.iceBreakers
                isDiscoverable = remoteProfile.isDiscoverable
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
        await refreshGuidedRooms(showErrors: showErrors)
        if !AppConfig.expertAstrologersEnabled {
            generateCompanionMessages()
            postPanelDailyStarterIfNeeded()
            postPanelWeeklyRecapIfNeeded()
        }
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
            try await profileDiscoveryStore.saveProfile(socialProfile)
            socialDisplayName = socialProfile.displayName
            publicUsername = socialProfile.username ?? ""
            communicationHint = socialProfile.communicationHint ?? ""
            iceBreakers = socialProfile.iceBreakers
            isDiscoverable = socialProfile.isDiscoverable

            guard showVisibilityToast else { return }
            if isVisible {
                showToast("You're visible", subtitle: "Other compatible Simastry users can now find you.", isError: false)
            } else {
                showToast("Browsing privately", subtitle: "Your discovery profile is now hidden from others.", isError: false)
            }
        } catch {
            if let onFailureRestoreVisibility {
                self.isDiscoverable = onFailureRestoreVisibility
                showToast(
                    "Couldn't update discovery",
                    subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                    isError: true
                )
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

        let normalizedUsername = PublicProfile.normalizedUsername(publicUsername)
        guard !isVisible || PublicProfile.isValidUsername(normalizedUsername) else {
            showToast("Choose a username", subtitle: "Use 3-24 lowercase letters, numbers, periods, or underscores.", isError: true)
            return nil
        }

        let trimmedHint = String(communicationHint.trimmingCharacters(in: .whitespacesAndNewlines).prefix(96))
        let cleanIceBreakers = iceBreakers
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) }
            .filter { !$0.isEmpty }
            .prefix(6)

        return SocialProfile(
            id: currentProfile.id,
            username: normalizedUsername.isEmpty ? nil : normalizedUsername,
            displayName: resolvedDisplayName,
            avatarURL: profileImageURL,
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            socialLinks: nil,
            communicationHint: trimmedHint.isEmpty ? defaultCommunicationHint(sunSign: sunSign) : trimmedHint,
            iceBreakers: cleanIceBreakers.isEmpty ? defaultIceBreakers(displayName: resolvedDisplayName, sunSign: sunSign) : Array(cleanIceBreakers),
            isDiscoverable: isVisible,
            createdAt: Date()
        )
    }

    func addUserConnection(profile: SocialProfile) async {
        guard AppConfig.socialDiscoveryEnabled else { return }
        do {
            try await profileDiscoveryStore.addConnection(profile)
            showToast("Added \(profile.displayName)", subtitle: "Their profile is saved in Messages and discovery.", isError: false)
        } catch {
            CrashReporter.log(error, context: "addUserConnection")
            showToast(
                "Couldn't add profile",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "They may no longer be discoverable."),
                isError: true
            )
        }
    }

    func removeUserConnection(profile: SocialProfile) async {
        guard AppConfig.socialDiscoveryEnabled else { return }
        do {
            try await profileDiscoveryStore.removeConnection(profile)
            showToast("Removed \(profile.displayName)", subtitle: "You can add them again from discovery.", isError: false)
        } catch {
            CrashReporter.log(error, context: "removeUserConnection")
            showToast(
                "Couldn't remove profile",
                subtitle: socialActionErrorSubtitle(for: error, fallback: "Try again in a moment."),
                isError: true
            )
        }
    }

    func publicProfile(for id: UUID) -> SocialProfile? {
        profileDiscoveryStore.publicProfile(for: id)
    }

    func communicationHint(for message: CompanionMessage) -> String {
        if message.source == .discovery, let profile = publicProfile(for: message.companionId) {
            return profile.communicationHint ?? defaultCommunicationHint(sunSign: profile.sunSign)
        }
        return guideCommunicationHint(for: message)
    }

    func iceBreakers(for message: CompanionMessage) -> [String] {
        if message.source == .discovery, let profile = publicProfile(for: message.companionId) {
            let prompts = profile.iceBreakers.filter { !$0.isEmpty }
            return prompts.isEmpty ? defaultIceBreakers(displayName: profile.displayName, sunSign: profile.sunSign) : prompts
        }
        return guideIceBreakers(for: message)
    }

    func openPrivatePredictionFromToday() {
        predictionDraft = PredictionDraft(
            category: .privateQuestion,
            targetSunSign: nil,
            targetMoonSign: nil,
            targetRisingSign: nil,
            question: FutureQuestionCategory.privateQuestion.defaultQuestion,
            conversationText: nil
        )
        openPredict()
    }

    private func defaultCommunicationHint(sunSign: String) -> String {
        guard let sign = ZodiacSign(rawValue: sunSign) else {
            return "Start warm, stay clear, and ask one real question."
        }
        return CommunicationTemplates.guides[sign]?.bestApproach
            ?? "Lead with \(sign.displayName) clarity: simple, warm, and specific."
    }

    private func defaultIceBreakers(displayName: String, sunSign: String) -> [String] {
        let sign = ZodiacSign(rawValue: sunSign)?.displayName ?? sunSign.capitalized
        return [
            "What kind of message feels easiest for you to answer?",
            "Does your \(sign) side prefer directness or a softer opening?",
            "What should I know before I read your silence the wrong way?"
        ]
    }

    private func guideCommunicationHint(for message: CompanionMessage) -> String {
        let sign = ZodiacSign(rawValue: message.companionSign.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == message.companionSign.lowercased() }
        if let sign {
            return GuideDirectoryCopy.specialty(
                for: FactoryCompanionCatalog.all.first { $0.sign == sign } ?? FactoryCompanionCatalog.featured
            )
        }
        return "Ask for timing, tone, or the sentence you should not send yet."
    }

    private func guideCalibrationRole(for message: CompanionMessage) -> GuideCalibrationRole {
        guard let guide = guideProfile(
            forThreadId: message.companionId,
            companionName: message.companionName,
            companionSign: message.companionSign
        ) else {
            return .astrologer
        }
        return GuideCalibrationStore.shared.calibration(for: guide.id).role
    }

    /// Icebreakers tailored to the guide's calibrated register — talking *with*
    /// the guide, not predicting a reply to send someone else. Astrologer is the
    /// default register for every guide.
    private func guideIceBreakers(for message: CompanionMessage) -> [String] {
        switch guideCalibrationRole(for: message) {
        case .astrologer:
            return [
                "What does my chart say about today?",
                "How do my signs shape the way I come across?",
                "Which placement should I lean into right now?",
                "Read me — what am I not seeing?"
            ]
        case .bestFriend:
            return [
                "Can I vent for a second?",
                "Honestly — am I overthinking this?",
                "What would you do if you were me?",
                "Hype me up before I reply."
            ]
        case .soulmate:
            return [
                "Help me put words to what I'm feeling.",
                "What does my heart actually want here?",
                "Sit with me on this for a minute.",
                "Why does this one matter so much to me?"
            ]
        case .mentor:
            return [
                "What's my smartest next move?",
                "How do I grow from this?",
                "Where am I getting in my own way?",
                "Give it to me straight — what should I do?"
            ]
        case .teacher:
            return [
                "Teach me something about my chart.",
                "What pattern keeps showing up for me?",
                "Break down what's happening astrologically.",
                "What's the lesson I keep missing?"
            ]
        case .coach:
            return [
                "Give me one small action for today.",
                "What goal should I focus on?",
                "Hold me accountable — what's the plan?",
                "What's the smallest step that moves me forward?"
            ]
        }
    }

    func currentDiscoveryMessageSender() -> (displayName: String, sunSign: String, moonSign: String?, risingSign: String?)? {
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
        guard !AppConfig.expertAstrologersEnabled else {
            openAIAstrologists(
                question: "What should I understand about my compatibility with \(socialProfile.displayName)?",
                autoRunEveryone: true
            )
            return
        }

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
        guard isRevenueCatAvailable else { return .max }
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
        let legacyUnread = AppConfig.expertAstrologersEnabled
            ? 0
            : companionMessages.filter { !$0.isRead && $0.direction == .incoming }.count
                + unreadPanelCount

        return discoveryMessages
            .filter { !$0.isRead && $0.direction == .incoming }
            .count
            + legacyUnread
    }

    var inboxMessages: [CompanionMessage] {
        let companionThreads: [CompanionMessage]
        if AppConfig.expertAstrologersEnabled {
            companionThreads = []
        } else {
            companionThreads = Dictionary(grouping: companionMessages, by: \.companionId)
                .compactMap { _, messages in
                    messages.max { $0.timestamp < $1.timestamp }
                }
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
    /// Live LLM replies are optional; the local method-layer composer remains the fallback.
    @discardableResult
    func sendCompanionThreadMessage(
        companionId: UUID,
        companionName: String,
        companionSign: String,
        content: String
    ) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard validateGuideMessageForSend(trimmed) else { return false }

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
            content: trimmed,
            timestamp: Date(),
            isRead: true,
            source: .companion,
            direction: .outgoing
        )
        companionMessages.insert(outgoing, at: 0)
        saveMessages()
        // Guides share one memory — 1:1 mentions inform panel follow-ups too.
        recordPanelMemoryIfNeeded(from: trimmed)

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
        scheduleCompanionReply(
            companionId: companionId,
            companionName: companionName,
            companionSign: companionSign,
            latestUserText: trimmed
        )
        return true
    }

    private func scheduleCompanionReply(
        companionId: UUID,
        companionName: String,
        companionSign: String,
        latestUserText: String
    ) {
        guard !typingCompanionIds.contains(companionId) else { return }
        typingCompanionIds.insert(companionId)

        let threadCount = companionMessages.filter { $0.companionId == companionId }.count
        let delay = Double(1_400 + (threadCount % 4) * 350)

        let generation = localStateGeneration

        scheduleGuideWork { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard let self, !Task.isCancelled, self.isCurrentGeneration(generation) else { return }

            // LLM reply when the edge channel is live; templates otherwise.
            let llmContent = await self.generateCompanionReplyViaLLM(
                companionId: companionId,
                companionName: companionName,
                companionSign: companionSign
            )
            guard !Task.isCancelled, self.isCurrentGeneration(generation) else { return }
            self.typingCompanionIds.remove(companionId)

            let reply = CompanionMessage(
                companionId: companionId,
                companionName: companionName,
                companionSign: companionSign,
                content: llmContent ?? self.composeCompanionReply(
                    signName: companionSign,
                    threadCount: threadCount,
                    mode: self.guideChatMode(for: companionId),
                    latestUserText: latestUserText,
                    user: self.llmUserContext
                ),
                timestamp: Date(),
                isRead: self.openCompanionThreadId == companionId,
                source: .companion,
                direction: .incoming
            )
            self.companionMessages.insert(reply, at: 0)
            self.saveMessages()
        }
    }

    /// Composes a companion reply from the persona's sign lens: an element-keyed opener
    /// plus one guidance beat, rotated by thread length so it doesn't repeat.
    /// The active chat mode picks the guidance register; check-in skips the
    /// opener entirely — reflective replies shouldn't start with banter.
    private func composeCompanionReply(
        signName: String,
        threadCount: Int,
        mode: GuideChatMode = .bestFriend,
        latestUserText: String = "",
        user: GuideReplyService.UserContext? = nil
    ) -> String {
        let sign = ZodiacSign(rawValue: signName.lowercased())
            ?? ZodiacSign.allCases.first { $0.displayName.lowercased() == signName.lowercased() }
            ?? .sagittarius

        if let compactReply = GuideReplyService.humanChatFallback(
            latestUserText: latestUserText,
            sign: sign,
            threadCount: threadCount,
            mode: mode,
            user: user
        ) {
            return compactReply
        }

        let element = sign.element.rawValue
        let openers = mode == .checkIn ? [] : (AstrologyTemplates.companionReplyOpeners[element] ?? [])
        let guidance: [String] = switch mode {
        case .bestFriend: AstrologyTemplates.companionReplyGuidance[element] ?? []
        case .mentor: AstrologyTemplates.mentorReplyGuidance[element] ?? []
        case .teacher: AstrologyTemplates.teacherReplyGuidance[element] ?? []
        case .checkIn: AstrologyTemplates.checkInReplyGuidance[element] ?? []
        }

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

    func uploadPublicProfileAvatar(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            showToast("Couldn't use photo", subtitle: "Try another image.", isError: true)
            return
        }

        do {
            let publicURL = try await profileDiscoveryStore.uploadAvatar(data: data)
            saveProfileImage(image)
            profileImageURL = publicURL
            UserDefaults.standard.set(publicURL, forKey: profileImageURLKey)
            updateSocialProfile()
            showToast("Photo updated", subtitle: "Your discovery profile now has a public avatar.")
        } catch {
            showToast("Couldn't upload photo", subtitle: "Check your connection and try again.", isError: true)
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
        if url.scheme == "http" || url.scheme == "https" {
            profileImageURL = savedURL
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
        // Invalidate and cancel any delayed guide replies/comments first so
        // none of them land after the wipe and re-persist cleared data.
        localStateGeneration += 1
        cancelPendingGuideWork()

        savedGuides = []
        companionMessages = []
        clearExpertAstrologerState()
        discoveryMessages = []
        panelMessages = []
        panelTypingParticipantIds = []
        panelMemoryNotes = []
        guideFeedbackEvents = []
        lastGuideSafetyMessage = nil
        moments = []
        momentTypingKeys = []
        momentsStore.deleteAll()
        discoveredProfiles = []
        connectedProfiles = []
        relationshipPeople = []
        predictionDraft = nil
        auraSnapshot = nil
        clearFirstReadOnboardingIntent()
        pendingInviteCodeForConfirmation = nil
        bonusPredictions = 0
        isDiscoverable = false
        socialDisplayName = ""
        publicUsername = ""
        socialBio = ""
        socialLinks = SocialLinks()
        communicationHint = ""
        iceBreakers = []
        referralInfo = nil
        hasAcceptedThirdPartyConsent = false
        profileImage = nil
        profileImageURL = nil
        auraWalletPublicAddress = ""
        auraWalletHoldings = nil
        auraWalletLastCheckedAt = nil
        useAuraWalletForAura = true
        privateNotificationsEnabled = true
        conversationSuggestionsEnabled = true

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: savedGuidesKey)
        defaults.removeObject(forKey: companionMessagesKey)
        defaults.removeObject(forKey: Self.panelMessagesKey)
        defaults.removeObject(forKey: Self.panelDailyStarterDayKey)
        defaults.removeObject(forKey: Self.panelMemoryNotesKey)
        defaults.removeObject(forKey: Self.panelWeeklyRecapWeekKey)
        defaults.removeObject(forKey: Self.panelWelcomeBackDayKey)
        defaults.removeObject(forKey: Self.methodCourseProgressKey)
        defaults.removeObject(forKey: SealedDraftStore.defaultsKey)
        defaults.removeObject(forKey: GuideFeedbackStore.defaultsKey)
        defaults.removeObject(forKey: Self.guideThreadIdsKey)
        defaults.removeObject(forKey: Self.practiceThreadsKey)
        openThreadRequestCompanionId = nil
        decodeDraftSign = nil
        methodCourseVersion += 1
        defaults.removeObject(forKey: socialLinksKey)
        defaults.removeObject(forKey: socialDisplayNameKey)
        defaults.removeObject(forKey: publicUsernameKey)
        defaults.removeObject(forKey: socialBioKey)
        defaults.removeObject(forKey: communicationHintKey)
        defaults.removeObject(forKey: iceBreakersKey)
        defaults.removeObject(forKey: isDiscoverableKey)
        defaults.removeObject(forKey: referralInfoKey)
        defaults.removeObject(forKey: thirdPartyConsentKey)
        defaults.removeObject(forKey: profileImageURLKey)
        defaults.removeObject(forKey: lastDiscoveryMessageTimestampKey)
        defaults.removeObject(forKey: auraWalletPublicAddressKey)
        defaults.removeObject(forKey: auraWalletHoldingsKey)
        defaults.removeObject(forKey: auraWalletUseInAuraKey)
        defaults.removeObject(forKey: auraWalletLastCheckedAtKey)
        defaults.removeObject(forKey: privateNotificationsEnabledKey)
        defaults.removeObject(forKey: conversationSuggestionsEnabledKey)
        defaults.removeObject(forKey: Self.firstReadOnboardingIntentDefaultsKey)
        defaults.removeObject(forKey: GuideGramStore.defaultsKey)
        todayStore.clearSavedPrompts()
        todayStore.clearDailyDecisions()
        auraSnapshotStore.clear()
        predictionService.clearHistory()

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

    func socialActionErrorSubtitle(for error: Error, fallback: String) -> String {
        if let supabaseError = error as? SupabaseServiceError {
            switch supabaseError {
            case .missingSession:
                return "Sign in again, then try once more."
            case .profileMismatch:
                return "This device is holding a different profile than the signed-in account."
            case .notConfigured:
                return "Social discovery is not configured for this build."
            default:
                break
            }
        }
        return fallback
    }

    private func syncHomeSetupPhase() {
        // The completed Today feed, including Nadia's guide panel, only needs
        // the user's chart. A saved companion is no longer required to enter it.
        if hasCompletedSigns {
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
            "hasPublicWallet": !auraWalletPublicAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "publicAddress": auraWalletPublicAddress,
            "zodiacCount": auraWalletTotalZodiacs,
            "zodiacCountsBySign": auraWalletHoldings?.zodiacCountsByRawValue ?? [:],
            "provider": hasAuraWalletContext ? "Manual Aura wallet input" : "",
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
        if debugPreviewScreen(from: arguments) == "landing" {
            isDebugPreviewStateActive = true
            // Deterministic pre-auth start: a seeded run in the same container
            // may have persisted age verification — the landing preview always
            // begins before the age gate.
            isAgeVerified = false
            currentScreen = .landing
            return true
        }
        if debugPreviewScreen(from: arguments) == "birthDetails" {
            isDebugPreviewStateActive = true
            isAgeVerified = true
            currentScreen = .birthDetails
            return true
        }
        if debugPreviewScreen(from: arguments) == "firstRead" {
            isDebugPreviewStateActive = true
            isAgeVerified = true
            currentScreen = .firstRead
            return true
        }
        if debugPreviewScreen(from: arguments) == "firstExpertRead" {
            isDebugPreviewStateActive = true
            isAgeVerified = true
            onboardingDisplayName = "Maya"
            onboardingBirthday = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 12))
            userSunSign = .leo
            userMoonSign = .cancer
            userRisingSign = .libra
            currentScreen = .firstExpertRead
            return true
        }

        let userId = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
        let companionId = UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID()
        let now = Date()

        isAuthenticated = true
        isDebugPreviewStateActive = true
        keepsDebugRelationshipPeopleEmpty = false
        isAgeVerified = true
        hasAcceptedThirdPartyConsent = true
        currentScreen = .home
        homeSetupPhase = .complete
        clearFirstReadDraft()
        clearGuideFeedback()
        clearExpertAstrologerState()

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

        if AppConfig.expertAstrologersEnabled {
            companions = []
            companionMessages = []
            savedGuides = []
            seedDebugExpertAstrologerState(now: now)
            if arguments.contains("-SimastryPreviewSeedChartImport") {
                seedDebugExpertChartImport(userId: userId)
            }
        } else {
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
        }
        discoveryMessages = []
        relationshipPeople = RelationshipPeopleStore.previewPeople()
        seedDebugSocialProfiles(now: now)

        // People power the Situation card on Today and the People tab —
        // seed them for every preview so those surfaces always render.
        relationshipPeople = RelationshipPeopleStore.previewPeople()

        let previewTab = debugPreviewTab(from: arguments)
        selectedTab = AppTab(normalizing: previewTab)
        predictionDraft = nil

        if previewTab == 4 {
            selectedTab = .today
            guideFocusSign = nil
        } else {
            guideFocusSign = nil
        }

        UserDefaults.standard.set("MAYA2626", forKey: Self.personalInviteCodeKey)

        if let previewWalletInput = debugPreviewValue(after: "-SimastryPreviewWallet", from: arguments),
           let parsedWallet = AuraWalletHoldings.parse(from: previewWalletInput) {
            auraWalletPublicAddress = parsedWallet.publicAddress
            auraWalletHoldings = parsedWallet
            auraWalletLastCheckedAt = now
            useAuraWalletForAura = true
        }

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
        case "firstReadHome":
            seedDebugFirstReadDraft(now: now)
        case "panelChat":
            if AppConfig.expertAstrologersEnabled {
                selectedTab = .messages
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    self.openAIAstrologists(question: "What should I reply back?", autoRunEveryone: true)
                }
            } else {
                seedDebugPanelMessages(now: now)
                selectedTab = .messages
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    self.panelChatRouteRequest += 1
                }
            }
        case "panelInbox":
            selectedTab = .messages
            if !AppConfig.expertAstrologersEnabled {
                seedDebugPanelMessages(now: now)
            }
        case "moments":
            seedDebugMoments(now: now)
            openProfileDrawer()
        case "invite":
            openProfileDrawer()
        case "profilePartial":
            profile = UserProfile.createDefault(id: userId)
            userSunSign = nil
            userMoonSign = nil
            userRisingSign = nil
            companions = []
            companionMessages = []
            relationshipPeople = []
            homeSetupPhase = .modeSelection
            selectedTab = .today
        case "aura":
            selectedTab = .today
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.auraRouteRequest += 1
            }
        case "shareCard":
            selectedTab = .today
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.shareCardRouteRequest += 1
            }
        case "careerRead":
            selectedTab = .today
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.careerReadRouteRequest += 1
            }
        case "methodCourse":
            seedDebugPanelMessages(now: now)
            UserDefaults.standard.removeObject(forKey: Self.methodCourseProgressKey)
            selectedTab = .messages
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.openMethodCourseLesson()
            }
        case "sealedDrafts":
            let draftStore = SealedDraftStore()
            draftStore.deleteAll()
            draftStore.add(SealedDraft(
                text: "I know it's late but I keep thinking about what you said and honestly",
                targetSign: .scorpio,
                releaseAt: now.addingTimeInterval(10 * 60 * 60)
            ))
            draftStore.add(SealedDraft(
                text: "Hey. I miss you. Is that crazy to say",
                targetSign: .leo,
                createdAt: now.addingTimeInterval(-20 * 60 * 60),
                releaseAt: now.addingTimeInterval(-2 * 60 * 60)
            ))
            selectedTab = .today
        case "playbook":
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            selectedTab = .people
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.peopleDetailRequestPersonId = self.relationshipPeople.first?.id
            }
        case "teamRead":
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            selectedTab = .people
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.teamReadRouteRequest += 1
            }
        case "peopleEmpty":
            relationshipPeople = []
            keepsDebugRelationshipPeopleEmpty = true
            selectedTab = .people
        case "recap":
            relationshipPeople = RelationshipPeopleStore.previewPeople()
            if AppConfig.expertAstrologersEnabled {
                selectedTab = .messages
            } else {
                seedDebugPanelMessages(now: now)
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
                selectedTab = .messages
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    self.panelChatRouteRequest += 1
                }
            }
        default:
            break
        }

        return true
    }

    /// Seeds an `uploaded` self chart import so the review/confirm flow is
    /// reachable in previews/UI tests without driving the system photo picker.
    private func seedDebugExpertChartImport(userId: UUID) {
        expertChartImports = [
            ExpertChartImportRecord(
                id: UUID(uuidString: "30000000-0000-0000-0000-000000000001") ?? UUID(),
                userId: userId,
                subjectType: ExpertChartSubject.userSelf.subjectType,
                personId: nil,
                storagePath: "\(userId.uuidString.lowercased())/self/seed.jpg",
                status: ExpertChartImportStatus.uploaded.rawValue,
                sourceLabel: "Uploaded chart screenshot"
            )
        ]
    }

    private func seedDebugExpertAstrologerState(now: Date) {
        let specialistId = "nadia-evolutionary"
        let conversationId = specialistConversationId(for: specialistId)
        specialistMessages = [
            SpecialistMessage(
                conversationId: conversationId,
                specialistId: specialistId,
                role: .user,
                content: "Why do I keep overthinking their replies?",
                timestamp: now.addingTimeInterval(-34 * 60),
                mode: .individual,
                profileContextSummary: "Maya · Sagittarius Sun · Cancer Moon · Libra Rising"
            ),
            SpecialistMessage(
                conversationId: conversationId,
                specialistId: specialistId,
                role: .specialist,
                content: "I would read this as a growth pattern around emotional safety and timing. Before you reply, separate what the message actually says from the story your nervous system starts writing around it.",
                timestamp: now.addingTimeInterval(-28 * 60),
                mode: .individual,
                profileContextSummary: "Maya · Sagittarius Sun · Cancer Moon · Libra Rising"
            )
        ]

        let multiConsultationId = UUID(uuidString: "24000000-0000-0000-0000-000000000001") ?? UUID()
        let question = "What should I reply back?"
        specialistConsultationResponses = ExpertAstrologerRegistry.specialists.enumerated().map { index, specialist in
            SpecialistConsultationResponse(
                multiConsultationId: multiConsultationId,
                specialistId: specialist.id,
                userQuestion: question,
                specialistResponse: "\(specialist.characterName) would answer from the \(specialist.publicTitle.lowercased()) lens, staying inside \(specialist.tradition) and asking for missing chart data only when it matters.",
                timestamp: now.addingTimeInterval(Double(index - 5) * 60),
                mode: .everyone,
                profileContextSummary: "Maya · Sagittarius Sun · Cancer Moon · Libra Rising"
            )
        }
        saveExpertAstrologerState()
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
                content: "Good. You said it instead of circling it. If you want to follow up, one short, warm line is enough — no essay needed.",
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

    /// Public Discovery fixtures for screenshots. These profiles mirror the
    /// production payload shape without touching Supabase.
    private func seedDebugSocialProfiles(now: Date) {
        publicUsername = "maya.sag"
        socialDisplayName = "Maya"
        socialBio = "Sag Sun, Cancer Moon. Learning to say true things cleanly."
        communicationHint = "Start direct, keep it warm, and leave room for a real answer."
        iceBreakers = [
            "What is your current read on this?",
            "Which sign do you lead with when texting?",
            "What usually makes timing feel safer for you?"
        ]
        socialLinks = SocialLinks()
        isDiscoverable = true

        let rowan = SocialProfile(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001") ?? UUID(),
            username: "rowan.aries",
            displayName: "Rowan",
            sunSign: ZodiacSign.aries.rawValue,
            moonSign: ZodiacSign.libra.rawValue,
            risingSign: ZodiacSign.leo.rawValue,
            bio: "Fast replies, big heart, trying to be less allergic to waiting.",
            communicationHint: "Be clear and quick. Rowan trusts directness more than hints.",
            iceBreakers: [
                "What makes a first message feel alive to you?",
                "Do you prefer bold honesty or slow proof?"
            ],
            isDiscoverable: true,
            createdAt: now.addingTimeInterval(-8 * 24 * 60 * 60)
        )

        let lina = SocialProfile(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002") ?? UUID(),
            username: "lina.earth",
            displayName: "Lina",
            sunSign: ZodiacSign.taurus.rawValue,
            moonSign: ZodiacSign.pisces.rawValue,
            risingSign: ZodiacSign.virgo.rawValue,
            bio: "Soft timing, practical standards, very good at noticing the edit.",
            communicationHint: "Move slowly and mean it. Specificity reads as care.",
            iceBreakers: [
                "What kind of consistency actually feels romantic?",
                "What do people misunderstand about your pace?"
            ],
            isDiscoverable: true,
            createdAt: now.addingTimeInterval(-12 * 24 * 60 * 60)
        )

        let noa = SocialProfile(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000003") ?? UUID(),
            username: "noa.air",
            displayName: "Noa",
            sunSign: ZodiacSign.gemini.rawValue,
            moonSign: ZodiacSign.aquarius.rawValue,
            risingSign: ZodiacSign.sagittarius.rawValue,
            bio: "Curious, funny, and better with a question than a speech.",
            communicationHint: "Keep it light enough to breathe, then ask the real question.",
            iceBreakers: [
                "What topic could you talk about forever?",
                "What is your favorite kind of banter?"
            ],
            isDiscoverable: true,
            createdAt: now.addingTimeInterval(-18 * 24 * 60 * 60)
        )

        discoveredProfiles = [rowan, lina, noa]
        connectedProfiles = [lina]
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
            if let thumb = MomentPhoto.thumbnail(data) {
                momentsStore.writeImage(thumb, fileName: MomentsStore.thumbFileName(for: moment.imageFileName))
            }
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
            if let thumb = MomentPhoto.thumbnail(data) {
                momentsStore.writeImage(thumb, fileName: MomentsStore.thumbFileName(for: moment.imageFileName))
            }
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

    private func seedDebugFirstReadDraft(now: Date) {
        let sign = ZodiacSign.taurus
        let element = sign.element.rawValue
        let likely = AstrologyTemplates.decodeSubtext[element]?.last
            ?? "A slow, complete reply means they thought about it."
        let notAssume = AstrologyTemplates.decodeDontReadInto[element]?.last
            ?? "No emoji doesn't mean no feeling."
        let replies = AstrologyTemplates.suggestedReplies[sign.displayName] ?? []

        saveFirstReadDraft(
            FirstReadDraft(
                messageText: "haha yeah maybe, this week is kind of crazy though",
                sign: sign,
                tone: .confident,
                likelyMeaning: likely,
                notAssume: notAssume,
                suggestedReplies: Array(replies.prefix(3)),
                bestNextMove: FirstReadBestNextMove(
                    type: .clarify,
                    summary: "Answer the actual words, then ask one clean question if the timing still feels unclear.",
                    timingNote: "One direct reply beats several careful hints."
                ),
                guideContinuationSeed: "Message read as Confident through Taurus. Best next move: ask one clean question.",
                safetyLevel: .ok,
                confidence: 74,
                createdAt: now.addingTimeInterval(-45 * 60)
            )
        )
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

    private func debugPreviewValue(after flag: String, from arguments: [String]) -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag),
              arguments.indices.contains(arguments.index(after: flagIndex)) else {
            return nil
        }
        return arguments[arguments.index(after: flagIndex)]
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
