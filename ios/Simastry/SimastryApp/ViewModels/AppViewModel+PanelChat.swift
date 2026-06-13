import Foundation

// MARK: - Panel Chat
// Group thread between the user and their Sun/Moon/Rising guides. Fully
// client-side: replies come from the same template voice machine as 1:1
// companion chats, staggered so the guides feel like distinct people.

extension AppViewModel {
    static let panelMessagesKey = "simastry_panel_messages"
    static let panelDailyStarterDayKey = "simastry_panel_daily_starter_day"
    static let panelMemoryNotesKey = "simastry_panel_memory_notes"
    static let panelWeeklyRecapWeekKey = "simastry_panel_weekly_recap_week"
    static let panelWelcomeBackDayKey = "simastry_panel_welcome_back_day"
    static let methodCourseProgressKey = "simastry_method_course_progress"
    static let panelMessageLimit = 40

    // MARK: Participants

    var panelGuideEntries: [PanelMatcher.Entry] {
        PanelMatcher.panelGuides(sun: userSunSign, moon: userMoonSign, rising: userRisingSign)
    }

    var panelParticipants: [PanelParticipant] {
        let user = PanelParticipant(
            id: PanelParticipant.localUserId,
            kind: .user,
            displayName: profile?.displayName ?? "You",
            signRawValue: userSunSign?.rawValue
        )
        let guides = panelGuideEntries.map { entry in
            PanelParticipant(
                id: entry.profile.id,
                kind: .guide(profileId: entry.profile.id),
                displayName: entry.profile.name,
                signRawValue: entry.sign.rawValue
            )
        }
        return [user] + guides
    }

    var panelThread: PanelThread {
        PanelThread(
            id: PanelThread.defaultThreadId,
            title: "Your Panel",
            participants: panelParticipants
        )
    }

    func panelGuideEntry(forParticipantId id: String) -> PanelMatcher.Entry? {
        panelGuideEntries.first { $0.profile.id == id }
            // History can reference a guide who left the panel after a sign
            // change — resolve them from the catalog so old bubbles render.
            ?? FactoryCompanionCatalog.all.first { $0.id == id }.map {
                PanelMatcher.Entry(role: .sun, sign: $0.sign, profile: $0)
            }
    }

    // MARK: Derived

    var sortedPanelMessages: [PanelMessage] {
        panelMessages
    }

    var latestPanelMessage: PanelMessage? {
        panelMessages.last
    }

    var unreadPanelCount: Int {
        panelMessages.filter { !$0.isRead && $0.senderId != PanelParticipant.localUserId }.count
    }

    // MARK: Persistence

    func loadPanelMessages() {
        guard let data = UserDefaults.standard.data(forKey: Self.panelMessagesKey) else {
            panelMessages = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let messages = try? decoder.decode([PanelMessage].self, from: data) else {
            UserDefaults.standard.removeObject(forKey: Self.panelMessagesKey)
            panelMessages = []
            return
        }
        panelMessages = Self.prunedPanelMessages(messages)
    }

    func savePanelMessages() {
        panelMessages = Self.prunedPanelMessages(panelMessages)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(panelMessages) else { return }
        UserDefaults.standard.set(data, forKey: Self.panelMessagesKey)
    }

    static func prunedPanelMessages(_ messages: [PanelMessage]) -> [PanelMessage] {
        Array(messages.sorted { $0.timestamp < $1.timestamp }.suffix(panelMessageLimit))
    }

    func markPanelThreadRead() {
        var changed = false
        for index in panelMessages.indices where !panelMessages[index].isRead {
            panelMessages[index].isRead = true
            changed = true
        }
        if changed {
            savePanelMessages()
        }
    }

    // MARK: Guide Work Lifecycle

    /// Runs delayed guide work (replies, comments, welcome posts) as a
    /// tracked, cancellable task. Bodies must additionally guard with
    /// `isCurrentGeneration(_:)` before mutating state, covering tasks
    /// already past their sleep when a clear happens.
    func scheduleGuideWork(_ body: @escaping @MainActor () async -> Void) {
        let handleId = UUID()
        let task = Task { @MainActor [weak self] in
            await body()
            self?.pendingGuideTaskHandles.removeValue(forKey: handleId)
        }
        pendingGuideTaskHandles[handleId] = task
    }

    func cancelPendingGuideWork() {
        for task in pendingGuideTaskHandles.values {
            task.cancel()
        }
        pendingGuideTaskHandles.removeAll()
        panelTypingParticipantIds.removeAll()
        typingCompanionIds.removeAll()
        momentTypingKeys.removeAll()
    }

    func isCurrentGeneration(_ generation: Int) -> Bool {
        generation == localStateGeneration
    }

    // MARK: Routing

    func openPanelChat() {
        selectedTab = 2
        panelChatRouteRequest += 1
    }

    /// Opens the panel with today's read posted as the daily starter, so the
    /// conversation literally begins from the Home daily-read card.
    func openPanelChatSeededWithDailyRead(line: String, role: CelestialRole) {
        postPanelDailyStarterIfNeeded(line: line, role: role)
        openPanelChat()
    }

    // MARK: Simastry Method Course

    var methodCourseState: MethodCourseState {
        guard let data = UserDefaults.standard.data(forKey: Self.methodCourseProgressKey),
              let state = try? JSONDecoder().decode(MethodCourseState.self, from: data) else {
            return MethodCourseState()
        }
        return state
    }

    private func saveMethodCourseState(_ state: MethodCourseState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.methodCourseProgressKey)
        methodCourseVersion += 1
    }

    /// True when tapping the course card posts a NEW lesson — one new
    /// lesson per day, never past lesson seven.
    var canPostMethodLessonToday: Bool {
        let state = methodCourseState
        guard state.currentLesson != nil else { return false }
        return state.lastPostDay != Self.panelDayStamp(for: Date())
    }

    /// Posts the current lesson into the panel as a rotating guide's
    /// message, then routes to the panel. Re-taps on the same day just
    /// open the thread — the lesson is already there.
    func openMethodCourseLesson() {
        var state = methodCourseState
        let today = Self.panelDayStamp(for: Date())

        if let lesson = state.currentLesson, state.lastPostDay != today {
            let guides = panelGuideEntries
            let senderId = guides.isEmpty
                ? FactoryCompanionCatalog.featured.id
                : guides[(lesson.number - 1) % guides.count].profile.id
            panelMessages.append(
                PanelMessage(senderId: senderId, content: lesson.panelMessage, isRead: isPanelThreadOpen)
            )
            savePanelMessages()

            state.postedLessons.append(lesson.number)
            state.lastPostDay = today
            saveMethodCourseState(state)
        }

        openPanelChat()
    }

    /// Drops a Tips-card lesson into the panel thread as that guide's
    /// icebreaker, then routes to the panel — tapping a tip lands in a
    /// conversation that has already started. The catalog fallback in
    /// `panelGuideEntry` lets any of the 24 guides post, not just the
    /// user's three placement guides. Re-taps of the same tip are deduped.
    func openPanelChatWithTip(lesson: String, opener: String, guideId: String) {
        if let entry = panelGuideEntry(forParticipantId: guideId) {
            let content = "\(lesson) \(opener)"
            let alreadyPosted = panelMessages.suffix(20).contains {
                $0.senderId == entry.profile.id && $0.content == content
            }
            if !alreadyPosted {
                panelMessages.append(
                    PanelMessage(senderId: entry.profile.id, content: content, isRead: isPanelThreadOpen)
                )
                savePanelMessages()
            }
        }
        openPanelChat()
    }

    // MARK: Sending

    @discardableResult
    func sendPanelMessage(_ content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard canSendMessage() else {
            showToast(
                "Messages used up",
                subtitle: "You've used all \(dailyMessageLimit) messages today. Upgrade for unlimited messages.",
                isError: true
            )
            showUpsell = true
            return false
        }

        let outgoing = PanelMessage(
            senderId: PanelParticipant.localUserId,
            content: trimmed,
            isRead: true
        )
        panelMessages.append(outgoing)
        savePanelMessages()
        recordPanelMemoryIfNeeded(from: trimmed)

        #if DEBUG
        let skipRemote = isDebugPreviewStateActive
        #else
        let skipRemote = false
        #endif
        if !skipRemote {
            await consumeMessage()
        }

        schedulePanelReplies()
        return true
    }

    /// 1–3 guides reply with staggered typing, in rotated order, the first
    /// responder always differing from whoever spoke last.
    private func schedulePanelReplies() {
        let guides = panelGuideEntries
        guard !guides.isEmpty else { return }

        let threadCount = panelMessages.count
        let responderCount = min(1 + threadCount % 3, guides.count)

        var ordered = Array(guides[(threadCount % guides.count)...] + guides[..<(threadCount % guides.count)])
        let lastGuideSpeakerId = panelMessages
            .filter { $0.senderId != PanelParticipant.localUserId }
            .max { $0.timestamp < $1.timestamp }?
            .senderId
        if ordered.count > 1, ordered.first?.profile.id == lastGuideSpeakerId {
            ordered.append(ordered.removeFirst())
        }

        let responders = Array(ordered.prefix(responderCount))

        let generation = localStateGeneration

        for (index, entry) in responders.enumerated() {
            let participantId = entry.profile.id
            guard !panelTypingParticipantIds.contains(participantId) else { continue }

            let typingLeadIn = 900
            let landDelay = 1_300 + index * 1_500 + (threadCount % 3) * 350
            let previousGuideName = index == 0 ? nil : responders[index - 1].profile.name

            scheduleGuideWork { [weak self] in
                try? await Task.sleep(for: .milliseconds(max(landDelay - typingLeadIn, 200)))
                guard let self, !Task.isCancelled, self.isCurrentGeneration(generation) else { return }
                self.panelTypingParticipantIds.insert(participantId)

                // LLM reply when the edge channel is live; template fallback
                // keeps the human-feel typing delay and never stalls.
                var content = await self.generatePanelReplyViaLLM(
                    entry: entry,
                    previousGuideName: previousGuideName
                )
                if content == nil {
                    try? await Task.sleep(for: .milliseconds(typingLeadIn))
                    content = Self.composePanelReply(
                        profile: entry.profile,
                        role: entry.role,
                        threadCount: threadCount,
                        replyIndex: index,
                        previousGuideName: previousGuideName
                    )
                }
                guard !Task.isCancelled, self.isCurrentGeneration(generation) else { return }
                self.panelTypingParticipantIds.remove(participantId)

                let reply = PanelMessage(
                    senderId: participantId,
                    content: content ?? "",
                    isRead: self.isPanelThreadOpen
                )
                guard !reply.content.isEmpty else { return }
                self.panelMessages.append(reply)
                self.savePanelMessages()
            }
        }
    }

    /// Static and deterministic for unit testing. Reply 0 speaks from the
    /// guide's element lens; later replies sometimes react to the previous
    /// guide by name before adding their own beat.
    nonisolated static func composePanelReply(
        profile: FactoryCompanionProfile,
        role: CelestialRole,
        threadCount: Int,
        replyIndex: Int,
        previousGuideName: String?
    ) -> String {
        let element = profile.sign.element.rawValue
        let guidance = AstrologyTemplates.companionReplyGuidance[element] ?? []
        // Offset rotation per role so the guides never pick the same beat in one turn.
        let roleOffset: Int = {
            switch role {
            case .sun: 0
            case .moon: 1
            case .rising: 2
            }
        }()
        let beat = guidance.isEmpty
            ? "Say it plainly, once, and give the reply room to land."
            : guidance[(threadCount + roleOffset) % guidance.count]

        if replyIndex >= 1,
           let previousGuideName,
           (threadCount + replyIndex) % 2 == 0,
           let interBeats = AstrologyTemplates.panelInterGuideBeats[element],
           !interBeats.isEmpty {
            let inter = interBeats[(threadCount + replyIndex) % interBeats.count]
                .replacingOccurrences(of: "{name}", with: previousGuideName)
            return inter
        }

        let openers = AstrologyTemplates.companionReplyOpeners[element] ?? []
        let opener = openers.isEmpty ? "" : openers[(threadCount + roleOffset) % openers.count]
        let roleTag = (threadCount + replyIndex) % 3 == 2
            ? " — that's the \(role.displayName) read."
            : ""

        return [opener, beat]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            + roleTag
    }

    // MARK: Welcome & Daily Starter

    /// Cold start: the three guides introduce themselves, staggered, the first
    /// time the panel opens.
    func seedPanelWelcomeIfNeeded() {
        guard panelMessages.isEmpty else { return }

        let firstName = (profile?.displayName ?? "there")
            .components(separatedBy: " ").first ?? "there"
        let openers = AstrologyTemplates.panelWelcomeOpeners

        let generation = localStateGeneration

        for (index, entry) in panelGuideEntries.enumerated() {
            let template = openers[min(index, openers.count - 1)]
            let content = template
                .replacingOccurrences(of: "{name}", with: firstName)
                .replacingOccurrences(of: "{sign}", with: entry.sign.displayName)
                .replacingOccurrences(of: "{role}", with: entry.role.displayName)

            let participantId = entry.profile.id
            let typingLeadIn = 800
            let landDelay = 700 + index * 1_400

            scheduleGuideWork { [weak self] in
                try? await Task.sleep(for: .milliseconds(max(landDelay - typingLeadIn, 150)))
                guard let self, !Task.isCancelled, self.isCurrentGeneration(generation) else { return }
                self.panelTypingParticipantIds.insert(participantId)

                try? await Task.sleep(for: .milliseconds(typingLeadIn))
                guard !Task.isCancelled, self.isCurrentGeneration(generation) else { return }
                self.panelTypingParticipantIds.remove(participantId)

                // Bail if the panel got seeded some other way mid-stagger.
                guard !self.panelMessages.contains(where: { $0.content == content }) else { return }
                self.panelMessages.append(
                    PanelMessage(senderId: participantId, content: content, isRead: self.isPanelThreadOpen)
                )
                self.savePanelMessages()
            }
        }
    }

    /// One guide opens a conversation per calendar day, rotating through the
    /// Sun/Moon/Rising lenses in step with the Home daily read — and pulling
    /// in real context (memory, unrated predictions, streaks, moments) so the
    /// panel feels like it's been paying attention.
    func postPanelDailyStarterIfNeeded(line: String? = nil, role: CelestialRole? = nil) {
        // The welcome sequence owns the empty thread.
        guard !panelMessages.isEmpty else { return }

        let dayStamp = Self.panelDayStamp(for: Date())
        guard UserDefaults.standard.string(forKey: Self.panelDailyStarterDayKey) != dayStamp else { return }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let focusRole = role ?? [CelestialRole.sun, .moon, .rising][dayOfYear % 3]
        guard let entry = panelGuideEntries.first(where: { $0.role == focusRole }) ?? panelGuideEntries.first else {
            return
        }

        let starter: String
        if let line {
            let starters = AstrologyTemplates.panelDailyStarters[focusRole.rawValue] ?? []
            let followUp = starters.isEmpty ? "Want to talk it through?" : starters[dayOfYear % starters.count]
            starter = "Today's read: \(line) \(followUp)"
        } else {
            starter = Self.composePanelStarter(
                dayOfYear: dayOfYear,
                focusRole: focusRole,
                context: currentPanelStarterContext()
            )
        }

        UserDefaults.standard.set(dayStamp, forKey: Self.panelDailyStarterDayKey)
        panelMessages.append(
            PanelMessage(senderId: entry.profile.id, content: starter, isRead: isPanelThreadOpen)
        )
        savePanelMessages()
    }

    nonisolated static func panelDayStamp(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    // MARK: - Contextual Initiative

    private func currentPanelStarterContext() -> PanelStarterContext {
        let lastPrediction = predictionService.loadHistory().first
        let lastPredictionTarget = lastPrediction.flatMap { result in
            PanelMemoryMatcher.mentions(in: result.question, people: relationshipPeople).first?.displayName
        }
        let situationPerson = relationshipPeople
            .filter { $0.situationStatus != nil }
            .max { ($0.situationUpdatedAt ?? .distantPast) < ($1.situationUpdatedAt ?? .distantPast) }

        return PanelStarterContext(
            memoryPersonName: panelMemoryNotes.max { $0.createdAt < $1.createdAt }?.personName,
            lastPredictionTargetName: lastPredictionTarget,
            lastPredictionSign: lastPrediction?.targetSunSign,
            lastPredictionUnrated: lastPrediction.map { $0.outcome == nil } ?? false,
            streak: StreakManager.shared.currentStreak,
            isStreakMilestone: StreakManager.shared.streakMessage != nil,
            latestMomentCaption: moments.first?.caption,
            situationPersonName: situationPerson?.displayName,
            situationStatusRaw: situationPerson?.situationStatus?.rawValue,
            situationDay: situationPerson?.situationDay() ?? 1
        )
    }

    /// Deterministic, testable starter composer. Priority: active situation
    /// → memory of a person → unrated prediction → streak milestone →
    /// latest moment → role default.
    nonisolated static func composePanelStarter(
        dayOfYear: Int,
        focusRole: CelestialRole,
        context: PanelStarterContext
    ) -> String {
        func pick(_ lines: [String]) -> String? {
            lines.isEmpty ? nil : lines[dayOfYear % lines.count]
        }

        // The saga the user is actually tracking comes first.
        if let person = context.situationPersonName,
           let statusRaw = context.situationStatusRaw,
           let line = pick(AstrologyTemplates.panelSituationStarters[statusRaw] ?? []) {
            return line
                .replacingOccurrences(of: "{personName}", with: person)
                .replacingOccurrences(of: "{n}", with: "\(context.situationDay)")
        }

        if let person = context.memoryPersonName,
           let line = pick(AstrologyTemplates.panelMemoryStarters) {
            return line.replacingOccurrences(of: "{personName}", with: person)
        }

        if context.lastPredictionUnrated,
           let line = pick(AstrologyTemplates.panelPredictionFollowUpStarters) {
            let target = context.lastPredictionTargetName
                ?? context.lastPredictionSign.map { "your last \($0.displayName) read" }
                ?? "your last read"
            return line.replacingOccurrences(of: "{target}", with: target)
        }

        if context.isStreakMilestone, context.streak > 1,
           let line = pick(AstrologyTemplates.panelStreakStarters) {
            return line.replacingOccurrences(of: "{streak}", with: "\(context.streak)")
        }

        if let caption = context.latestMomentCaption, !caption.isEmpty,
           let line = pick(AstrologyTemplates.panelMomentStarters) {
            return line.replacingOccurrences(of: "{caption}", with: String(caption.prefix(40)))
        }

        let defaults = AstrologyTemplates.panelDailyStarters[focusRole.rawValue] ?? []
        return pick(defaults) ?? "What's today's thread — anything you're composing in your head?"
    }

    // MARK: - Panel Memory

    func loadPanelMemoryNotes() {
        guard let data = UserDefaults.standard.data(forKey: Self.panelMemoryNotesKey) else {
            panelMemoryNotes = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        panelMemoryNotes = (try? decoder.decode([MemoryNote].self, from: data)) ?? []
    }

    func savePanelMemoryNotes() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(panelMemoryNotes) else { return }
        UserDefaults.standard.set(data, forKey: Self.panelMemoryNotesKey)
    }

    /// Records which People the user just mentioned, so later starters and
    /// LLM replies can follow up like someone who was listening.
    func recordPanelMemoryIfNeeded(from text: String) {
        let mentioned = PanelMemoryMatcher.mentions(in: text, people: relationshipPeople)
        guard !mentioned.isEmpty else { return }

        for person in mentioned {
            panelMemoryNotes.append(
                MemoryNote(personName: person.displayName, personId: person.id)
            )
        }
        panelMemoryNotes = Self.pruned(panelMemoryNotes, now: Date())
        savePanelMemoryNotes()
    }

    /// Cap 20 notes; drop anything older than 30 days.
    nonisolated static func pruned(_ notes: [MemoryNote], now: Date) -> [MemoryNote] {
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let fresh = notes.filter { $0.createdAt >= cutoff }
        return Array(fresh.suffix(20))
    }

    /// When the thread has been quiet for 3+ days and the panel remembers
    /// something, a guide reaches out about it — once per day at most.
    func postPanelWelcomeBackIfNeeded(now: Date = Date()) {
        guard let latest = latestPanelMessage,
              now.timeIntervalSince(latest.timestamp) > 3 * 24 * 60 * 60,
              let note = panelMemoryNotes.max(by: { $0.createdAt < $1.createdAt }) else {
            return
        }

        let dayStamp = Self.panelDayStamp(for: now)
        guard UserDefaults.standard.string(forKey: Self.panelWelcomeBackDayKey) != dayStamp else { return }

        let lines = AstrologyTemplates.panelWelcomeBackLines
        guard !lines.isEmpty,
              let entry = panelGuideEntries.first(where: { $0.role == .moon }) ?? panelGuideEntries.first else {
            return
        }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1
        let content = lines[dayOfYear % lines.count]
            .replacingOccurrences(of: "{personName}", with: note.personName)

        UserDefaults.standard.set(dayStamp, forKey: Self.panelWelcomeBackDayKey)
        panelMessages.append(
            PanelMessage(senderId: entry.profile.id, content: content, isRead: isPanelThreadOpen)
        )
        savePanelMessages()
    }

    // MARK: - Weekly Recap

    /// Sunday ritual: the Sun-lens guide reads the week back, once per week.
    func postPanelWeeklyRecapIfNeeded(date: Date = Date()) {
        guard !panelMessages.isEmpty else { return }
        guard Calendar.current.component(.weekday, from: date) == 1 else { return }

        let stamp = WeeklyRecapComposer.weekStamp(for: date)
        guard UserDefaults.standard.string(forKey: Self.panelWeeklyRecapWeekKey) != stamp else { return }

        guard let entry = panelGuideEntries.first(where: { $0.role == .sun }) ?? panelGuideEntries.first else {
            return
        }

        let stats = WeeklyRecapComposer.stats(
            history: predictionService.loadHistory(),
            panelMessages: panelMessages,
            moments: moments,
            streak: StreakManager.shared.currentStreak,
            guideName: { [weak self] senderId in
                self?.panelGuideEntry(forParticipantId: senderId)?.profile.name
            },
            weekEnding: date
        )

        let firstName = (profile?.displayName ?? "")
            .components(separatedBy: " ").first
        let message = WeeklyRecapComposer.recapMessage(
            stats: stats,
            guideName: entry.profile.name,
            userFirstName: (firstName?.isEmpty ?? true) ? nil : firstName
        )

        UserDefaults.standard.set(stamp, forKey: Self.panelWeeklyRecapWeekKey)
        panelMessages.append(
            PanelMessage(senderId: entry.profile.id, content: message, isRead: isPanelThreadOpen)
        )
        savePanelMessages()
    }
}

/// Everything the panel can reference when it speaks first.
nonisolated struct PanelStarterContext: Equatable, Sendable {
    let memoryPersonName: String?
    let lastPredictionTargetName: String?
    let lastPredictionSign: ZodiacSign?
    let lastPredictionUnrated: Bool
    let streak: Int
    let isStreakMilestone: Bool
    let latestMomentCaption: String?
    // Active saga — outranks everything else when set.
    var situationPersonName: String? = nil
    var situationStatusRaw: String? = nil
    var situationDay: Int = 1
}
