import Foundation
import Testing
@testable import Simastry

@MainActor
struct PanelMomentsInviteTests {
    private func cleanPanelDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppViewModel.panelMessagesKey)
        defaults.removeObject(forKey: AppViewModel.panelDailyStarterDayKey)
    }

    private func cleanInviteDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppViewModel.personalInviteCodeKey)
        defaults.removeObject(forKey: "simastry_referral_info")
        defaults.removeObject(forKey: "bonusPredictions")
    }

    private func seededViewModel() -> AppViewModel {
        let viewModel = AppViewModel()
        viewModel.isDebugPreviewStateActive = true
        viewModel.userSunSign = .sagittarius
        viewModel.userMoonSign = .cancer
        viewModel.userRisingSign = .libra
        var profile = UserProfile.createDefault(id: UUID())
        profile.tier = "pro"
        viewModel.profile = profile
        return viewModel
    }

    // MARK: - PanelMatcher

    @Test func panelMatcherDedupesSharedSigns() {
        let entries = PanelMatcher.panelGuides(sun: .sagittarius, moon: .sagittarius, rising: .libra)

        #expect(entries.count == 3)
        #expect(Set(entries.map(\.profile.id)).count == 3)
        #expect(entries.map(\.role) == [.sun, .moon, .rising])
        // Both Sagittarius cast members get used instead of repeating one.
        let sagittariusIds = entries.filter { $0.sign == .sagittarius }.map(\.profile.id)
        #expect(Set(sagittariusIds).count == 2)
    }

    @Test func panelMatcherSkipsNilPlacementsAndFallsBack() {
        let partial = PanelMatcher.panelGuides(sun: .leo, moon: nil, rising: nil)
        #expect(partial.count == 1)
        #expect(partial.first?.role == .sun)
        #expect(partial.first?.sign == .leo)

        let empty = PanelMatcher.panelGuides(sun: nil, moon: nil, rising: nil)
        #expect(empty.count == 1)
        #expect(empty.first?.profile.id == FactoryCompanionCatalog.featured.id)
    }

    // MARK: - Tips

    @Test func guideTipsAllResolveToCatalogGuides() {
        #expect(!AstrologyTemplates.guideTips.isEmpty)
        let catalogIds = Set(FactoryCompanionCatalog.all.map(\.id))
        for tip in AstrologyTemplates.guideTips {
            #expect(catalogIds.contains(tip.guideId), "Unknown guide id: \(tip.guideId)")
            #expect(!tip.title.isEmpty)
            #expect(!tip.body.isEmpty)
            #expect(!tip.opener.isEmpty)
        }
    }

    @Test func dailyGuideTipsRotateDeterministically() {
        let count = AstrologyTemplates.guideTips.count
        for dayOfYear in 1...366 {
            let tips = AstrologyTemplates.dailyGuideTips(dayOfYear: dayOfYear)
            #expect(tips.count == 2)
            // Same day always yields the same pair (Today tab and the
            // evening notification must agree), and the two tips differ.
            let again = AstrologyTemplates.dailyGuideTips(dayOfYear: dayOfYear)
            #expect(tips.map(\.title) == again.map(\.title))
            if count > 1 {
                #expect(tips[0].title != tips[1].title)
            }
        }
    }

    @Test func openPanelChatWithTipPostsOnceFromThatGuideAndRoutes() {
        cleanPanelDefaults()
        let viewModel = seededViewModel()
        viewModel.panelMessages = []

        // A non-panel guide (Theo isn't in the Sag/Cancer/Libra panel) must
        // still be able to post via the catalog fallback.
        viewModel.openPanelChatWithTip(
            lesson: "Fixed signs pause to decide.",
            opener: "Want to check it against someone you know?",
            guideId: "taurus-theo"
        )

        #expect(viewModel.selectedTab == .messages)
        #expect(viewModel.panelMessages.count == 1)
        #expect(viewModel.panelMessages.first?.senderId == "taurus-theo")
        #expect(viewModel.panelMessages.first?.content.contains("Fixed signs pause") == true)

        // Tapping the same tip again must not duplicate the icebreaker.
        viewModel.openPanelChatWithTip(
            lesson: "Fixed signs pause to decide.",
            opener: "Want to check it against someone you know?",
            guideId: "taurus-theo"
        )
        #expect(viewModel.panelMessages.count == 1)

        cleanPanelDefaults()
    }

    @Test func shareCardCopyCoversAllSignsWithoutPronouns() {
        for sign in ZodiacSign.allCases {
            let copy = CommunicationTemplates.shareCardCopy[sign]
            #expect(copy != nil, "Missing share copy for \(sign.rawValue)")
            guard let copy else { continue }
            // Share cards travel without context — the sign must be the
            // subject, never "they/them".
            for line in [copy.approach, copy.avoid] {
                #expect(line.localizedCaseInsensitiveContains(sign.displayName), "\(sign.rawValue) line doesn't name the sign: \(line)")
                let lowered = " \(line.lowercased()) "
                for pronoun in [" they ", " them ", " their ", " they're "] {
                    #expect(!lowered.contains(pronoun), "\(sign.rawValue) share copy uses a pronoun: \(line)")
                }
            }
        }
    }

    // MARK: - Panel Chat

    @Test func sendPanelMessageAppendsPersistsAndDrawsAGuideReply() async throws {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = []

        let sent = await viewModel.sendPanelMessage("They left me on read. Thoughts?")
        #expect(sent)
        #expect(viewModel.panelMessages.count == 1)
        #expect(viewModel.panelMessages.last?.senderId == PanelParticipant.localUserId)

        // Round-trips through UserDefaults.
        let data = UserDefaults.standard.data(forKey: AppViewModel.panelMessagesKey)
        #expect(data != nil)
        if let data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([PanelMessage].self, from: data)
            #expect(decoded.count == 1)
        }

        // First staggered guide reply lands ~1.3s after sending; generous
        // margin because the suite's async tests share the main actor.
        try await Task.sleep(for: .milliseconds(3_200))
        #expect(viewModel.panelMessages.count >= 2)
        #expect(viewModel.panelMessages.last?.senderId != PanelParticipant.localUserId)
    }

    @Test func composePanelReplyReferencesPreviousGuideOnlyInLaterReplies() {
        guard let nadia = FactoryCompanionCatalog.all.first(where: { $0.id == "sagittarius-nadia" }),
              let mila = FactoryCompanionCatalog.all.first(where: { $0.id == "cancer-mila" }) else {
            Issue.record("Expected cast members missing from catalog")
            return
        }

        // replyIndex 0 never references another guide.
        for threadCount in 0..<12 {
            let first = AppViewModel.composePanelReply(
                profile: nadia,
                role: .sun,
                threadCount: threadCount,
                replyIndex: 0,
                previousGuideName: "Mila"
            )
            #expect(!first.contains("Mila"))
        }

        // Later replies reference the previous guide on the inter-beat turns.
        let referencing = (0..<12).map { threadCount in
            AppViewModel.composePanelReply(
                profile: mila,
                role: .moon,
                threadCount: threadCount,
                replyIndex: 1,
                previousGuideName: "Nadia"
            )
        }
        #expect(referencing.contains { $0.contains("Nadia") })
    }

    @Test func panelWelcomeSeedsExactlyOnce() async throws {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = []

        viewModel.seedPanelWelcomeIfNeeded()
        viewModel.seedPanelWelcomeIfNeeded()

        // Welcome posts stagger over ~3.5s; the content guard dedupes the double call.
        try await Task.sleep(for: .milliseconds(4_400))
        #expect(viewModel.panelMessages.count == viewModel.panelGuideEntries.count)
    }

    @Test func panelDailyStarterPostsOncePerDay() {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = [
            PanelMessage(senderId: PanelParticipant.localUserId, content: "hi", isRead: true)
        ]

        viewModel.postPanelDailyStarterIfNeeded()
        let countAfterFirst = viewModel.panelMessages.count
        #expect(countAfterFirst == 2)

        viewModel.postPanelDailyStarterIfNeeded()
        #expect(viewModel.panelMessages.count == countAfterFirst)
    }

    // MARK: - Moments

    @Test func momentsStoreRoundTripsAndDeletes() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MomentsStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = MomentsStore(directoryURL: directory)
        defer { store.deleteAll() }

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        #expect(store.writeImage(imageData, fileName: "test.jpg"))
        #expect(FileManager.default.fileExists(atPath: store.imageURL(for: "test.jpg").path))

        let moment = Moment(caption: "hello", imageFileName: "test.jpg", reactionCount: 2)
        store.save([moment])

        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.caption == "hello")
        #expect(loaded.first?.reactionCount == 2)

        store.deleteImage(fileName: "test.jpg")
        #expect(!FileManager.default.fileExists(atPath: store.imageURL(for: "test.jpg").path))

        store.deleteAll()
        #expect(store.load().isEmpty)
    }

    @Test func momentCommentsNeverClaimVision() {
        guard let guide = FactoryCompanionCatalog.all.first(where: { $0.id == "taurus-ada" }) else {
            Issue.record("Expected cast member missing from catalog")
            return
        }
        let bannedFragments = ["see", "look", "photo", "picture", "image"]

        // Without a caption, comments riff on chart/sharing only.
        for profile in FactoryCompanionCatalog.all.prefix(8) {
            for beatIndex in 0..<10 {
                let comment = AppViewModel.composeMomentComment(
                    profile: profile,
                    role: .sun,
                    caption: nil,
                    userName: "Maya",
                    userSun: .sagittarius,
                    userRising: .libra,
                    beatIndex: beatIndex
                ).lowercased()

                for fragment in bannedFragments {
                    #expect(!comment.contains(fragment), "\"\(comment)\" claims vision via \"\(fragment)\"")
                }
            }
        }

        // With a caption, echo turns quote the user's own words.
        let echoed = (0..<10).map { beatIndex in
            AppViewModel.composeMomentComment(
                profile: guide,
                role: .moon,
                caption: "said the honest thing",
                userName: "Maya",
                userSun: .sagittarius,
                userRising: .libra,
                beatIndex: beatIndex
            )
        }
        #expect(echoed.contains { $0.contains("said the honest thing") })
    }

    // MARK: - Invites

    @Test func inviteCodeGeneratorShape() {
        for _ in 0..<100 {
            let code = InviteCode.generate()
            #expect(code.count == 8)
            #expect(code.allSatisfy { InviteCode.alphabet.contains($0) })
            #expect(!code.contains("0") && !code.contains("O"))
            #expect(!code.contains("1") && !code.contains("I") && !code.contains("L"))
        }
        #expect(InviteCode.isValid("MAYA2626"))
        #expect(InviteCode.isValid("maya2626"))
        #expect(!InviteCode.isValid("ABC"))
        #expect(!InviteCode.isValid("HELLO!23"))
    }

    @Test func inviteDeepLinkParsesAndRoundTrips() {
        let custom = URL(string: "simastry://invite/maya2626")!
        #expect(DeepLink.from(url: custom) == .invite(code: "MAYA2626"))

        let link = DeepLink.invite(code: "MAYA2626")
        #expect(DeepLink.from(url: link.universalLinkURL) == .invite(code: "MAYA2626"))
        #expect(DeepLink.from(url: link.customSchemeURL) == .invite(code: "MAYA2626"))

        #expect(DeepLink.from(url: URL(string: "simastry://invite/ab")!) == nil)
        #expect(DeepLink.from(url: URL(string: "simastry://invite")!) == nil)
    }

    @Test func applyInviteCodeRecordsReferralWithoutLocalCreditGrant() {
        cleanInviteDefaults()
        defer { cleanInviteDefaults() }

        let viewModel = AppViewModel()
        viewModel.bonusPredictions = 0
        viewModel.referralInfo = nil
        UserDefaults.standard.set("ABCDEF23", forKey: AppViewModel.personalInviteCodeKey)

        // Own code is rejected with no local credit.
        viewModel.applyInviteCode("ABCDEF23")
        #expect(viewModel.bonusPredictions == 0)
        #expect(viewModel.referralInfo == nil)

        // First foreign code records referral context but does not grant
        // prediction credits locally.
        viewModel.applyInviteCode("QWERTY23")
        #expect(viewModel.bonusPredictions == 0)
        #expect(viewModel.referralInfo?.referredBy == "QWERTY23")

        // Second code never changes the saved referral.
        viewModel.applyInviteCode("ZYXWVU45")
        #expect(viewModel.bonusPredictions == 0)
        #expect(viewModel.referralInfo?.referredBy == "QWERTY23")
    }

    // MARK: - Cleanup

    @Test func clearLocalDeviceDataWipesPanelAndMoments() {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = [
            PanelMessage(senderId: PanelParticipant.localUserId, content: "hi", isRead: true)
        ]
        viewModel.savePanelMessages()
        viewModel.moments = [Moment(imageFileName: "x.jpg")]

        viewModel.clearLocalDeviceData()

        #expect(viewModel.panelMessages.isEmpty)
        #expect(viewModel.moments.isEmpty)
        #expect(UserDefaults.standard.data(forKey: AppViewModel.panelMessagesKey) == nil)
    }
}
