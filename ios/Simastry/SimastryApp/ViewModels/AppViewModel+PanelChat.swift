import Foundation

// MARK: - Panel Chat
// Group thread between the user and their Sun/Moon/Rising guides. Fully
// client-side: replies come from the same template voice machine as 1:1
// companion chats, staggered so the guides feel like distinct people.

extension AppViewModel {
    static let panelMessagesKey = "simastry_panel_messages"
    static let panelDailyStarterDayKey = "simastry_panel_daily_starter_day"

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
        panelMessages.sorted { $0.timestamp < $1.timestamp }
    }

    var latestPanelMessage: PanelMessage? {
        panelMessages.max { $0.timestamp < $1.timestamp }
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
        panelMessages = messages
    }

    func savePanelMessages() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(panelMessages) else { return }
        UserDefaults.standard.set(data, forKey: Self.panelMessagesKey)
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

        for (index, entry) in responders.enumerated() {
            let participantId = entry.profile.id
            guard !panelTypingParticipantIds.contains(participantId) else { continue }

            let typingLeadIn = 900
            let landDelay = 1_300 + index * 1_500 + (threadCount % 3) * 350
            let previousGuideName = index == 0 ? nil : responders[index - 1].profile.name

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(max(landDelay - typingLeadIn, 200)))
                panelTypingParticipantIds.insert(participantId)

                try? await Task.sleep(for: .milliseconds(typingLeadIn))
                panelTypingParticipantIds.remove(participantId)

                let reply = PanelMessage(
                    senderId: participantId,
                    content: Self.composePanelReply(
                        profile: entry.profile,
                        role: entry.role,
                        threadCount: threadCount,
                        replyIndex: index,
                        previousGuideName: previousGuideName
                    ),
                    isRead: isPanelThreadOpen
                )
                panelMessages.append(reply)
                savePanelMessages()
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

        for (index, entry) in panelGuideEntries.enumerated() {
            let template = openers[min(index, openers.count - 1)]
            let content = template
                .replacingOccurrences(of: "{name}", with: firstName)
                .replacingOccurrences(of: "{sign}", with: entry.sign.displayName)
                .replacingOccurrences(of: "{role}", with: entry.role.displayName)

            let participantId = entry.profile.id
            let typingLeadIn = 800
            let landDelay = 700 + index * 1_400

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(max(landDelay - typingLeadIn, 150)))
                panelTypingParticipantIds.insert(participantId)

                try? await Task.sleep(for: .milliseconds(typingLeadIn))
                panelTypingParticipantIds.remove(participantId)

                // Bail if the panel got seeded some other way mid-stagger.
                guard !panelMessages.contains(where: { $0.content == content }) else { return }
                panelMessages.append(
                    PanelMessage(senderId: participantId, content: content, isRead: isPanelThreadOpen)
                )
                savePanelMessages()
            }
        }
    }

    /// One guide opens a conversation per calendar day, rotating through the
    /// Sun/Moon/Rising lenses in step with the Home daily read.
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
            let starters = AstrologyTemplates.panelDailyStarters[focusRole.rawValue] ?? []
            guard !starters.isEmpty else { return }
            starter = starters[dayOfYear % starters.count]
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
}
