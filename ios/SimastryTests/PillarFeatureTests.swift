import Foundation
import Testing
@testable import Simastry

@MainActor
struct PillarFeatureTests {
    private func cleanPanelDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppViewModel.panelMessagesKey)
        defaults.removeObject(forKey: AppViewModel.panelDailyStarterDayKey)
        defaults.removeObject(forKey: AppViewModel.panelMemoryNotesKey)
        defaults.removeObject(forKey: AppViewModel.panelWeeklyRecapWeekKey)
        defaults.removeObject(forKey: AppViewModel.panelWelcomeBackDayKey)
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

    // MARK: - Playbooks

    @Test func playbookComposerCoversAllSituationSignPairs() {
        for situation in PlaybookSituation.allCases {
            for sign in ZodiacSign.allCases {
                let playbook = PlaybookComposer.playbook(
                    situation: situation,
                    personName: "Jordan",
                    sun: sign,
                    moon: nil,
                    relationshipType: .friend,
                    userSun: .sagittarius
                )
                #expect(!playbook.script.isEmpty, "\(situation) x \(sign) script empty")
                #expect(!playbook.whyItWorks.isEmpty, "\(situation) x \(sign) why empty")
                #expect(!playbook.avoid.isEmpty, "\(situation) x \(sign) avoid empty")
                #expect(!playbook.script.contains("{name}"), "unresolved slot in \(situation) x \(sign)")
            }
        }
    }

    @Test func playbookComposerIsDeterministicAndVariesByInputs() {
        func make(relationship: RelationshipType, seed: Int = 3) -> Playbook {
            PlaybookComposer.playbook(
                situation: .giveFeedback,
                personName: "Sam",
                sun: .capricorn,
                moon: .pisces,
                relationshipType: relationship,
                userSun: .leo,
                variantSeed: seed
            )
        }

        #expect(make(relationship: .teammate) == make(relationship: .teammate))

        let teammate = make(relationship: .teammate)
        let partner = make(relationship: .partner)
        #expect(teammate.whyItWorks != partner.whyItWorks)   // register note differs

        // Reuses the existing approach-reasoning copy.
        if let approach = CommunicationTemplates.approachReasoning["Capricorn"] {
            #expect(teammate.whyItWorks.contains(approach))
        }

        // Moon modifier present iff moon is known.
        let withoutMoon = PlaybookComposer.playbook(
            situation: .giveFeedback, personName: "Sam", sun: .capricorn,
            moon: nil, relationshipType: .teammate, userSun: .leo, variantSeed: 3
        )
        #expect(teammate.whyItWorks.contains("Pisces Moon"))
        #expect(!withoutMoon.whyItWorks.contains("Moon"))
    }

    // MARK: - Life Lenses

    @Test func careerTemplatesCoverAllSigns() {
        for sign in ZodiacSign.allCases {
            #expect(CareerTemplates.workStyle[sign]?.isEmpty == false, "workStyle missing for \(sign)")
            #expect(CareerTemplates.underPressure[sign]?.isEmpty == false, "underPressure missing for \(sign)")
            #expect(CareerTemplates.firstWeekRead[sign]?.isEmpty == false, "firstWeekRead missing for \(sign)")
            #expect(CareerTemplates.strengths[sign]?.count == 2, "strengths should be 2 for \(sign)")
            #expect(CareerTemplates.watchOut[sign]?.isEmpty == false, "watchOut missing for \(sign)")
        }
    }

    @Test func coupleReadCoversAllElementPairsAndResolvesSlots() {
        // Every element pair key must exist in all three pattern sets.
        for a in ZodiacElement.allCases {
            for b in ZodiacElement.allCases {
                let key = TeamReadEngine.bridgeKey(a, b)
                #expect(CoupleReadTemplates.fight[key] != nil, "fight missing for \(key)")
                #expect(CoupleReadTemplates.repair[key] != nil, "repair missing for \(key)")
                #expect(CoupleReadTemplates.moneyTalk[key] != nil, "moneyTalk missing for \(key)")
            }
        }

        // Commitment styles cover all signs and resolve the name slot.
        for sign in ZodiacSign.allCases {
            let line = CoupleReadComposer.commitmentLine(name: "Maya", sun: sign)
            #expect(line.contains("Maya"), "commitment line for \(sign) doesn't name the person")
            #expect(!line.contains("{n}"), "unresolved slot for \(sign)")
        }

        // Full composition resolves every field for every sign pairing shape.
        let read = CoupleReadComposer.read(nameA: "Maya", sunA: .sagittarius, nameB: "Leo", sunB: .leo, seed: 4)
        #expect(!read.fight.isEmpty)
        #expect(!read.repair.isEmpty)
        #expect(!read.moneyTalk.isEmpty)
        #expect(read.headline.contains("Maya") && read.headline.contains("Leo"))
        if let signal = read.signalLine {
            #expect(!signal.contains("{a}") && !signal.contains("{b}"))
        }
    }

    // MARK: - Team Read

    @Test func teamReadComposesRolesCountsAndFriction() {
        let members = [
            TeamReadMember(name: "Maya", sun: .leo, moon: nil, isUser: true),
            TeamReadMember(name: "Jordan", sun: .aquarius, moon: nil, isUser: false),
            TeamReadMember(name: "Daniel", sun: .capricorn, moon: nil, isUser: false)
        ]
        let read = TeamReadEngine.read(members: members, seed: 2)

        #expect(read.elementCounts[.fire] == 1)
        #expect(read.elementCounts[.air] == 1)
        #expect(read.elementCounts[.earth] == 1)
        #expect(read.modalityCounts["fixed"] == 2)
        #expect(read.modalityCounts["cardinal"] == 1)
        #expect(read.roles.count == 3)
        #expect(read.roles.first { $0.memberName == "Daniel" }?.title == "Initiator")

        // Leo x Aquarius is an opposition — surfaces as the friction pair.
        #expect(read.frictionPair != nil)
        #expect(read.frictionPair?.aspect == .opposition)
        #expect(read.bridge?.isEmpty == false)
        #expect(!read.play.isEmpty)

        // Deterministic.
        #expect(TeamReadEngine.read(members: members, seed: 2) == read)
    }

    @Test func teamReadHandlesBoundsAndNoAspectGroups() {
        let two = TeamReadEngine.read(members: [
            TeamReadMember(name: "A", sun: .aries, moon: nil, isUser: false),
            TeamReadMember(name: "B", sun: .taurus, moon: nil, isUser: false)
        ])
        // Aries-Taurus: adjacent signs, no whole-sign aspect.
        #expect(two.highlights.isEmpty)
        #expect(two.frictionPair == nil)
        #expect(!two.play.isEmpty)

        let five = TeamReadEngine.read(members: [
            TeamReadMember(name: "A", sun: .aries, moon: nil, isUser: false),
            TeamReadMember(name: "B", sun: .leo, moon: nil, isUser: false),
            TeamReadMember(name: "C", sun: .sagittarius, moon: nil, isUser: false),
            TeamReadMember(name: "D", sun: .gemini, moon: nil, isUser: false),
            TeamReadMember(name: "E", sun: .libra, moon: nil, isUser: false)
        ])
        #expect(five.roles.count == 5)
        #expect(five.highlights.count == 3)   // capped at top 3
    }

    // MARK: - Scorecard

    @Test func scorecardRequiresThreeRatedOutcomes() {
        func result(outcome: PredictionOutcome?) -> PredictionResult {
            PredictionResult(
                id: UUID(), mode: .whatWillTheySay, question: "", conversationText: "",
                targetSunSign: .leo, targetMoonSign: nil, targetRisingSign: nil,
                predictedMessage: "m", astrologicalBreakdown: "b", confidence: 70,
                tone: nil, privacySummary: nil, createdAt: Date(),
                isLocalComposition: true, outcome: outcome
            )
        }

        #expect(PredictionScorecard.from([]).line == nil)
        #expect(PredictionScorecard.from([result(outcome: .landed), result(outcome: .missed)]).line == nil)

        let three = PredictionScorecard.from([
            result(outcome: .landed), result(outcome: .landed),
            result(outcome: .missed), result(outcome: nil)   // unrated excluded
        ])
        #expect(three.rated == 3)
        #expect(three.landed == 2)
        #expect(three.line == "Called it 2 of 3")
        #expect(three.captionLine == "called it 2/3")
    }

    // MARK: - Weekly Recap

    @Test func weeklyRecapWindowsAndComposes() {
        let now = Date()
        let inWeek = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let outOfWeek = now.addingTimeInterval(-9 * 24 * 60 * 60)

        func prediction(at date: Date, outcome: PredictionOutcome?) -> PredictionResult {
            PredictionResult(
                id: UUID(), mode: .whatWillTheySay, question: "", conversationText: "",
                targetSunSign: .leo, targetMoonSign: nil, targetRisingSign: nil,
                predictedMessage: "m", astrologicalBreakdown: "b", confidence: 70,
                tone: nil, privacySummary: nil, createdAt: date,
                isLocalComposition: true, outcome: outcome
            )
        }

        let stats = WeeklyRecapComposer.stats(
            history: [prediction(at: inWeek, outcome: .landed), prediction(at: outOfWeek, outcome: .landed)],
            panelMessages: [
                PanelMessage(senderId: PanelParticipant.localUserId, content: "hi", timestamp: inWeek, isRead: true),
                PanelMessage(senderId: "sagittarius-nadia", content: "hey", timestamp: inWeek, isRead: true),
                PanelMessage(senderId: PanelParticipant.localUserId, content: "old", timestamp: outOfWeek, isRead: true)
            ],
            moments: [Moment(imageFileName: "x.jpg", createdAt: inWeek)],
            streak: 4,
            guideName: { $0 == "sagittarius-nadia" ? "Nadia" : nil },
            weekEnding: now
        )

        #expect(stats.predictionsMade == 1)
        #expect(stats.predictionsLanded == 1)
        #expect(stats.panelMessagesSent == 1)
        #expect(stats.momentsPosted == 1)
        #expect(stats.topGuideName == "Nadia")

        let message = WeeklyRecapComposer.recapMessage(stats: stats, guideName: "Nadia", userFirstName: "Maya")
        #expect(message.contains("Maya"))
        #expect(message.contains("1 prediction"))
        #expect(message.contains("4-day streak"))

        // Quiet week stays warm and ends usable.
        let quiet = WeeklyRecapComposer.recapMessage(
            stats: WeeklyRecapStats(predictionsMade: 0, predictionsRated: 0, predictionsLanded: 0, panelMessagesSent: 0, momentsPosted: 0, streak: 0, topGuideName: nil),
            guideName: "Nadia",
            userFirstName: nil
        )
        #expect(quiet.hasSuffix("?"))
        #expect(!quiet.lowercased().contains("fail"))

        // Week stamps: stable same-day, distinct across weeks.
        #expect(WeeklyRecapComposer.weekStamp(for: now) == WeeklyRecapComposer.weekStamp(for: now))
        #expect(WeeklyRecapComposer.weekStamp(for: now) != WeeklyRecapComposer.weekStamp(for: outOfWeek))
    }

    @Test func weeklyRecapPostsOnceOnSundayOnly() {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = [
            PanelMessage(senderId: PanelParticipant.localUserId, content: "hi", isRead: true)
        ]

        // Find a Sunday and a Monday.
        let calendar = Calendar.current
        var sunday = Date()
        while calendar.component(.weekday, from: sunday) != 1 {
            sunday = calendar.date(byAdding: .day, value: 1, to: sunday) ?? sunday
        }
        let monday = calendar.date(byAdding: .day, value: 1, to: sunday) ?? sunday

        viewModel.postPanelWeeklyRecapIfNeeded(date: monday)
        #expect(viewModel.panelMessages.count == 1)   // not Sunday → no post

        viewModel.postPanelWeeklyRecapIfNeeded(date: sunday)
        #expect(viewModel.panelMessages.count == 2)

        viewModel.postPanelWeeklyRecapIfNeeded(date: sunday)
        #expect(viewModel.panelMessages.count == 2)   // week-stamp dedupe
    }

    // MARK: - Panel Memory

    @Test func memoryMatcherWholeWordAndPruning() {
        let maya = RelationshipPerson(
            id: UUID(), name: "Maya", privateLabel: nil, relationshipType: .partner,
            birthDate: nil, birthTime: nil, birthPlace: nil,
            sunSign: .leo, moonSign: nil, risingSign: nil,
            notes: nil, imageData: nil, isChartCalculated: false, updatedAt: Date()
        )
        let al = RelationshipPerson(
            id: UUID(), name: "Al", privateLabel: nil, relationshipType: .friend,
            birthDate: nil, birthTime: nil, birthPlace: nil,
            sunSign: .libra, moonSign: nil, risingSign: nil,
            notes: nil, imageData: nil, isChartCalculated: false, updatedAt: Date()
        )
        let alex = RelationshipPerson(
            id: UUID(), name: "Alex", privateLabel: nil, relationshipType: .friend,
            birthDate: nil, birthTime: nil, birthPlace: nil,
            sunSign: .libra, moonSign: nil, risingSign: nil,
            notes: nil, imageData: nil, isChartCalculated: false, updatedAt: Date()
        )

        let people = [maya, al, alex]
        #expect(PanelMemoryMatcher.mentions(in: "how do I talk to maya about this?", people: people).map(\.name) == ["Maya"])
        // "Al" is under 3 chars — skipped entirely; "Alex" matches whole-word only.
        #expect(PanelMemoryMatcher.mentions(in: "Alex left me on read", people: people).map(\.name) == ["Alex"])
        #expect(PanelMemoryMatcher.mentions(in: "I am also always available", people: people).isEmpty)

        // Prune: cap 20 and drop >30 days.
        let now = Date()
        let old = MemoryNote(personName: "Old", personId: nil, createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60))
        let fresh = (0..<25).map { MemoryNote(personName: "P\($0)", personId: nil, createdAt: now) }
        let pruned = AppViewModel.pruned([old] + fresh, now: now)
        #expect(pruned.count == 20)
        #expect(!pruned.contains { $0.personName == "Old" })
    }

    @Test func sendPanelMessageRecordsMemory() async throws {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = []
        viewModel.relationshipPeople = RelationshipPeopleStore.previewPeople()

        _ = await viewModel.sendPanelMessage("How should I handle things with Jordan this week?")
        #expect(viewModel.panelMemoryNotes.contains { $0.personName == "Jordan" })
    }

    // MARK: - Contextual Starters

    @Test func panelStarterPriorityOrder() {
        func context(
            memory: String? = nil,
            unrated: Bool = false,
            milestone: Bool = false,
            caption: String? = nil
        ) -> PanelStarterContext {
            PanelStarterContext(
                memoryPersonName: memory,
                lastPredictionTargetName: nil,
                lastPredictionSign: .leo,
                lastPredictionUnrated: unrated,
                streak: 7,
                isStreakMilestone: milestone,
                latestMomentCaption: caption
            )
        }

        let memoryFirst = AppViewModel.composePanelStarter(
            dayOfYear: 4, focusRole: .sun,
            context: context(memory: "Jordan", unrated: true, milestone: true, caption: "good day")
        )
        #expect(memoryFirst.contains("Jordan"))

        let predictionNext = AppViewModel.composePanelStarter(
            dayOfYear: 4, focusRole: .sun,
            context: context(unrated: true, milestone: true, caption: "good day")
        )
        #expect(predictionNext.lowercased().contains("land") || predictionNext.lowercased().contains("rating"))

        let streakNext = AppViewModel.composePanelStarter(
            dayOfYear: 4, focusRole: .sun,
            context: context(milestone: true, caption: "good day")
        )
        #expect(streakNext.contains("7"))

        let momentNext = AppViewModel.composePanelStarter(
            dayOfYear: 4, focusRole: .sun,
            context: context(caption: "good day")
        )
        #expect(momentNext.contains("good day"))

        let fallback = AppViewModel.composePanelStarter(dayOfYear: 4, focusRole: .moon, context: context())
        #expect(!fallback.isEmpty)

        // Deterministic.
        #expect(
            AppViewModel.composePanelStarter(dayOfYear: 4, focusRole: .sun, context: context(memory: "Jordan"))
                == AppViewModel.composePanelStarter(dayOfYear: 4, focusRole: .sun, context: context(memory: "Jordan"))
        )
    }

    // MARK: - Voice

    @Test func personaPromptCarriesVoiceAndMemory() {
        guard let profile = FactoryCompanionCatalog.all.first(where: { $0.id == "taurus-ada" }) else {
            Issue.record("Expected cast member missing")
            return
        }

        let prompt = GuideReplyService.personaSystemPrompt(
            profile: profile,
            role: .sun,
            user: .init(name: "Maya", sun: .sagittarius, moon: nil, rising: nil, communicationType: nil),
            isPanel: true,
            memoryLines: ["asked about Jordan (2d ago)"]
        )

        #expect(prompt.contains(SimastryVoice.promptBlock))
        #expect(prompt.contains("asked about Jordan"))

        let playbook = GuideReplyService.playbookPrompt(
            situation: "Give feedback",
            personName: "Jordan",
            personSigns: "Aquarius Sun",
            relationshipType: "Teammate",
            guideProfile: profile,
            user: .init(name: "Maya", sun: .sagittarius, moon: nil, rising: nil, communicationType: nil)
        )
        #expect(playbook.system.contains(SimastryVoice.promptBlock))
        #expect(playbook.user.contains("Give feedback"))
        #expect(playbook.user.contains("Aquarius Sun"))
        #expect(playbook.user.contains("Teammate"))
    }

    // MARK: - Guide Work Cancellation

    @Test func clearDataCancelsPendingPanelReply() async throws {
        cleanPanelDefaults()
        defer { cleanPanelDefaults() }

        let viewModel = seededViewModel()
        viewModel.panelMessages = []

        _ = await viewModel.sendPanelMessage("Pending reply incoming?")
        #expect(viewModel.panelMessages.count == 1)

        // Clear while guide replies are still sleeping.
        viewModel.clearLocalDeviceData()
        #expect(viewModel.panelMessages.isEmpty)

        // Past every scheduled landing time — nothing may resurrect.
        // (In-memory state only: UserDefaults is shared across parallel
        // tests, so asserting the key here would race other panel tests.)
        try await Task.sleep(for: .milliseconds(3_500))
        #expect(viewModel.panelMessages.isEmpty)
        #expect(viewModel.panelTypingParticipantIds.isEmpty)
        #expect(viewModel.pendingGuideTaskHandles.isEmpty)
    }

    @Test func clearDataCancelsPendingCompanionReply() async throws {
        defer { UserDefaults.standard.removeObject(forKey: "simastry_companion_messages") }

        let viewModel = seededViewModel()
        viewModel.companionMessages = []

        _ = await viewModel.sendCompanionThreadMessage(
            companionId: UUID(),
            companionName: "Nadia",
            companionSign: "sagittarius",
            content: "Pending reply incoming?"
        )
        #expect(viewModel.companionMessages.count == 1)

        viewModel.clearLocalDeviceData()
        #expect(viewModel.companionMessages.isEmpty)

        try await Task.sleep(for: .milliseconds(2_500))
        #expect(viewModel.companionMessages.isEmpty)
        #expect(viewModel.typingCompanionIds.isEmpty)
    }

    @Test func companionThreadMessageRecordsSharedMemory() async {
        cleanPanelDefaults()
        defer {
            cleanPanelDefaults()
            UserDefaults.standard.removeObject(forKey: "simastry_companion_messages")
        }

        let viewModel = seededViewModel()
        viewModel.relationshipPeople = RelationshipPeopleStore.previewPeople()
        viewModel.panelMemoryNotes = []

        _ = await viewModel.sendCompanionThreadMessage(
            companionId: UUID(),
            companionName: "Nadia",
            companionSign: "sagittarius",
            content: "Nadia, how do I give Jordan feedback without it landing wrong?"
        )

        #expect(viewModel.panelMemoryNotes.contains { $0.personName == "Jordan" })
    }

    @Test func momentPromptEnforcesNoVisionRule() {
        guard let profile = FactoryCompanionCatalog.all.first(where: { $0.id == "cancer-mila" }) else {
            Issue.record("Expected cast member missing")
            return
        }
        let user = GuideReplyService.UserContext(
            name: "Maya", sun: .sagittarius, moon: .cancer, rising: .libra, communicationType: nil
        )

        let withCaption = GuideReplyService.momentCommentPrompt(
            caption: "finally said the honest thing",
            guideProfile: profile,
            role: .moon,
            user: user
        )
        #expect(withCaption.system.contains("CANNOT see the photo"))
        #expect(withCaption.system.contains(SimastryVoice.promptBlock))
        #expect(withCaption.user.contains("finally said the honest thing"))

        let withoutCaption = GuideReplyService.momentCommentPrompt(
            caption: "   ",
            guideProfile: profile,
            role: nil,
            user: user
        )
        #expect(withoutCaption.user.contains("no caption"))
    }

    @Test func voiceAuditBansDoomLanguage() {
        let bannedPhrases = [
            "they've already decided",
            "playing it small",
            "Don't lie to me",
            "yellow flag",
            "red flag"
        ]

        let templateDumps: [String] = [
            AstrologyTemplates.companionGreetings.values.flatMap { $0 }.joined(separator: "\n"),
            AstrologyTemplates.companionReplyOpeners.values.flatMap { $0 }.joined(separator: "\n"),
            AstrologyTemplates.companionReplyGuidance.values.flatMap { $0 }.joined(separator: "\n"),
            AstrologyTemplates.panelInterGuideBeats.values.flatMap { $0 }.joined(separator: "\n"),
            AstrologyTemplates.momentCommentTemplates.values.flatMap { $0 }.joined(separator: "\n"),
            AstrologyTemplates.panelMemoryStarters.joined(separator: "\n"),
            AstrologyTemplates.panelWelcomeBackLines.joined(separator: "\n"),
            PlaybookTemplates.situationAvoid.values.joined(separator: "\n"),
            TeamReadTemplates.aspectPairLines.values.flatMap { $0 }.joined(separator: "\n")
        ]

        for dump in templateDumps {
            let lowered = dump.lowercased()
            for phrase in bannedPhrases {
                #expect(!lowered.contains(phrase.lowercased()), "Found banned phrase: \(phrase)")
            }
        }
    }
}
