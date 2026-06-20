import Foundation

// MARK: - Guided Rooms
// Real social rooms backed by Supabase. The user's private panel chat remains
// local and separate; rooms are for opted-in social-profile members.

extension AppViewModel {
    var availableRoomProfiles: [SocialProfile] {
        discoveredProfiles
            .filter { $0.isVisible && $0.id != profile?.id }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func roomMessages(for threadId: UUID) -> [ChatMessage] {
        chatMessagesByThreadId[threadId, default: []]
            .sorted { $0.createdAt < $1.createdAt }
    }

    func roomSummary(for threadId: UUID) -> ChatThreadSummary? {
        chatThreadSummaries.first { $0.id == threadId }
    }

    func isGuideTyping(in threadId: UUID, guideProfileId: String) -> Bool {
        roomGuideTypingKeys.contains(roomGuideTypingKey(threadId: threadId, guideProfileId: guideProfileId))
    }

    func refreshGuidedRooms(showErrors: Bool = false) async {
        guard AppConfig.socialDiscoveryEnabled else {
            chatThreadSummaries = []
            chatMessagesByThreadId = [:]
            return
        }

        do {
            let ownMemberships = try await supabase.fetchChatThreadMembershipsForCurrentUser()
            let threadIds = Array(Set(ownMemberships.map(\.threadId)))
            guard !threadIds.isEmpty else {
                chatThreadSummaries = []
                chatMessagesByThreadId = [:]
                return
            }

            let threads = try await supabase.fetchChatThreads(threadIds: threadIds)
            let members = try await supabase.fetchChatThreadMembers(threadIds: threadIds)
            let messages = try await supabase.fetchChatMessages(threadIds: threadIds)
            let blocks = try await supabase.fetchDiscoveryBlocks()
            let fallbackCurrentUserId = await supabase.currentUserId
            let currentUserId = profile?.id ?? fallbackCurrentUserId
            let blockedProfileIds = Set(blocks.compactMap { block -> UUID? in
                guard let currentUserId else { return nil }
                if block.blockerId == currentUserId { return block.blockedId }
                if block.blockedId == currentUserId { return block.blockerId }
                return nil
            })
            let membersByThread = Dictionary(grouping: members, by: \.threadId)
            let messagesByThread = Dictionary(grouping: messages, by: \.threadId)

            let visibleSummaries = threads.map { thread in
                ChatThreadSummary(
                    thread: thread,
                    members: membersByThread[thread.id, default: []],
                    latestMessage: messagesByThread[thread.id]?.max { $0.createdAt < $1.createdAt }
                )
            }
            .filter { summary in
                !summary.humanMembers.contains { member in
                    guard let humanUserId = member.humanUserId else { return false }
                    return blockedProfileIds.contains(humanUserId)
                }
            }
            .sorted { $0.thread.updatedAt > $1.thread.updatedAt }

            let visibleThreadIds = Set(visibleSummaries.map(\.id))
            chatMessagesByThreadId = messagesByThread.filter { visibleThreadIds.contains($0.key) }
            chatThreadSummaries = visibleSummaries
        } catch {
            CrashReporter.log(error, context: "refreshGuidedRooms")
            if showErrors {
                showToast("Couldn't load rooms", subtitle: "Check your connection or try again.", isError: true)
            }
        }
    }

    @discardableResult
    func createGuidedRoom(
        with selectedProfiles: [SocialProfile],
        includeGuides: Bool,
        title rawTitle: String
    ) async -> ChatThreadSummary? {
        await createGuidedRoom(
            with: selectedProfiles,
            includedGuideProfileIds: includeGuides ? Set(panelGuideEntries.map { $0.profile.id }) : [],
            title: rawTitle
        )
    }

    @discardableResult
    func createGuidedRoom(
        with selectedProfiles: [SocialProfile],
        includedGuideProfileIds: Set<String>,
        title rawTitle: String
    ) async -> ChatThreadSummary? {
        guard AppConfig.socialDiscoveryEnabled else {
            showToast("Rooms unavailable", subtitle: "Enable social discovery before creating a room.", isError: true)
            return nil
        }
        guard (1...4).contains(selectedProfiles.count) else {
            showToast("Pick 1 to 4 people", subtitle: "Guided Rooms support 2 to 5 humans including you.", isError: true)
            return nil
        }
        guard let currentProfile = profile,
              let sender = currentDiscoveryMessageSender() else {
            return nil
        }

        let now = Date()
        let threadId = UUID()
        let title = resolvedRoomTitle(rawTitle, selectedProfiles: selectedProfiles)
        let thread = ChatThread(
            id: threadId,
            title: title,
            creatorId: currentProfile.id,
            createdAt: now,
            updatedAt: now
        )

        var members: [ChatThreadMember] = [
            ChatThreadMember(
                id: UUID(),
                threadId: threadId,
                memberKind: .human,
                humanUserId: currentProfile.id,
                guideProfileId: nil,
                displayName: sender.displayName,
                sign: sender.sunSign,
                roleLabel: "You",
                isActive: true,
                lastReadAt: now,
                createdAt: now
            )
        ]

        members += selectedProfiles.map { socialProfile in
            ChatThreadMember(
                id: UUID(),
                threadId: threadId,
                memberKind: .human,
                humanUserId: socialProfile.id,
                guideProfileId: nil,
                displayName: socialProfile.displayName,
                sign: socialProfile.sunSign,
                roleLabel: nil,
                isActive: true,
                lastReadAt: nil,
                createdAt: now
            )
        }

        if !includedGuideProfileIds.isEmpty {
            members += panelGuideEntries.filter { entry in
                includedGuideProfileIds.contains(entry.profile.id)
            }.map { entry in
                ChatThreadMember(
                    id: UUID(),
                    threadId: threadId,
                    memberKind: .guide,
                    humanUserId: nil,
                    guideProfileId: entry.profile.id,
                    displayName: entry.profile.name,
                    sign: entry.sign.rawValue,
                    roleLabel: entry.role.displayName,
                    isActive: true,
                    lastReadAt: nil,
                    createdAt: now
                )
            }
        }

        let openingMessage = ChatMessage(
            id: UUID(),
            threadId: threadId,
            senderKind: .system,
            senderUserId: nil,
            senderGuideId: nil,
            senderDisplayName: "Simastry",
            senderSign: nil,
            content: "Room started as a guided conversation. Use it for reflection, repair, and clarity; it is not therapy.",
            activityKind: nil,
            activityPayload: nil,
            createdBy: currentProfile.id,
            createdAt: now
        )

        do {
            try await supabase.createChatThread(
                thread: thread,
                members: members,
                openingMessage: openingMessage
            )
            let summary = ChatThreadSummary(thread: thread, members: members, latestMessage: openingMessage)
            chatThreadSummaries.insert(summary, at: 0)
            chatMessagesByThreadId[threadId] = [openingMessage]
            showToast("Room created", subtitle: "\(title) is ready.", isError: false)
            return summary
        } catch {
            CrashReporter.log(error, context: "createGuidedRoom")
            showToast("Couldn't create room", subtitle: "Check that everyone is still available and try again.", isError: true)
            return nil
        }
    }

    @discardableResult
    func sendRoomMessage(threadId: UUID, content: String) async -> Bool {
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

        let moderation = ContentModerationService.moderateDiscoveryMessage(trimmed)
        guard moderation.isAllowed else {
            showToast("Couldn't send message", subtitle: moderation.reason ?? "Please revise it and try again.", isError: true)
            return false
        }

        guard let currentProfile = profile,
              let sender = currentDiscoveryMessageSender() else {
            return false
        }

        let message = ChatMessage(
            id: UUID(),
            threadId: threadId,
            senderKind: .human,
            senderUserId: currentProfile.id,
            senderGuideId: nil,
            senderDisplayName: sender.displayName,
            senderSign: sender.sunSign,
            content: trimmed,
            activityKind: nil,
            activityPayload: nil,
            createdBy: currentProfile.id,
            createdAt: Date()
        )

        appendRoomMessage(message)
        do {
            try await supabase.sendChatMessage(message)
            #if DEBUG
            let skipRemote = isDebugPreviewStateActive
            #else
            let skipRemote = false
            #endif
            if !skipRemote {
                await consumeMessage()
            }
            await requestRoomGuideReplyIfNeeded(threadId: threadId)
            return true
        } catch {
            removeRoomMessage(message)
            CrashReporter.log(error, context: "sendRoomMessage")
            showToast("Couldn't send message", subtitle: "Try again in a moment.", isError: true)
            return false
        }
    }

    @discardableResult
    func sendRoomActivity(threadId: UUID, kind: ChatActivityKind) async -> Bool {
        guard let summary = roomSummary(for: threadId),
              let currentProfile = profile,
              let sender = currentDiscoveryMessageSender() else {
            return false
        }

        let payload = ChatActivityFactory.payload(
            for: kind,
            room: summary,
            currentUserName: sender.displayName
        )
        let message = ChatMessage(
            id: UUID(),
            threadId: threadId,
            senderKind: .activity,
            senderUserId: nil,
            senderGuideId: nil,
            senderDisplayName: "Activity",
            senderSign: nil,
            content: "\(payload.title): \(payload.body)",
            activityKind: kind,
            activityPayload: payload,
            createdBy: currentProfile.id,
            createdAt: Date()
        )

        appendRoomMessage(message)
        do {
            try await supabase.sendChatMessage(message)
            await requestRoomGuideReplyIfNeeded(threadId: threadId)
            return true
        } catch {
            removeRoomMessage(message)
            CrashReporter.log(error, context: "sendRoomActivity")
            showToast("Couldn't add activity", subtitle: "Try again in a moment.", isError: true)
            return false
        }
    }

    func markGuidedRoomRead(threadId: UUID) async {
        do {
            try await supabase.markChatThreadRead(threadId: threadId)
        } catch {
            CrashReporter.log(error, context: "markGuidedRoomRead")
        }
    }

    func leaveGuidedRoom(threadId: UUID) async {
        do {
            try await supabase.leaveChatThread(threadId: threadId)
            chatThreadSummaries.removeAll { $0.id == threadId }
            chatMessagesByThreadId.removeValue(forKey: threadId)
            showToast("Left room", subtitle: "The room was removed from your inbox.", isError: false)
        } catch {
            CrashReporter.log(error, context: "leaveGuidedRoom")
            showToast("Couldn't leave room", subtitle: "Try again in a moment.", isError: true)
        }
    }

    func reportGuidedRoom(threadId: UUID, details: String? = nil) async {
        let fallbackReporterId = await supabase.currentUserId
        guard let reporterId = profile?.id ?? fallbackReporterId else {
            showToast("Couldn't report room", subtitle: "Sign in again and try once more.", isError: true)
            return
        }

        let report = ChatReportData(
            id: UUID(),
            threadId: threadId,
            reporterId: reporterId,
            reason: "room_safety",
            details: details,
            createdAt: Date()
        )

        do {
            try await supabase.reportChatThread(report)
            showToast("Report submitted", subtitle: "Thanks for helping keep rooms safe.", isError: false)
        } catch {
            CrashReporter.log(error, context: "reportGuidedRoom")
            showToast("Couldn't send report", subtitle: "Try again in a moment.", isError: true)
        }
    }

    func blockRoomMember(_ member: ChatThreadMember, in threadId: UUID) async {
        guard let blockedId = member.humanUserId else { return }
        do {
            try await supabase.blockDiscoveryProfile(blockedId: blockedId)
            chatThreadSummaries.removeAll { $0.id == threadId }
            chatMessagesByThreadId.removeValue(forKey: threadId)
            showToast("Blocked \(member.displayName)", subtitle: "Rooms with this person are hidden.", isError: false)
        } catch {
            CrashReporter.log(error, context: "blockRoomMember")
            showToast("Couldn't block", subtitle: "Try again in a moment.", isError: true)
        }
    }

    func loadRoomMessages(threadId: UUID, showErrors: Bool = false) async {
        guard AppConfig.socialDiscoveryEnabled else { return }
        do {
            chatMessagesByThreadId[threadId] = try await supabase.fetchChatMessages(threadId: threadId)
        } catch {
            CrashReporter.log(error, context: "loadRoomMessages")
            if showErrors {
                showToast("Couldn't refresh room", subtitle: "Try again in a moment.", isError: true)
            }
        }
    }

    private func requestRoomGuideReplyIfNeeded(threadId: UUID) async {
        guard AppConfig.llmChatEnabled,
              AppConfig.roomGuideReplyEnabled,
              let summary = roomSummary(for: threadId),
              !summary.guideMembers.isEmpty else {
            return
        }

        let messages = roomMessages(for: threadId)
        let guideIndex = messages.count % summary.guideMembers.count
        let guide = summary.guideMembers[guideIndex]
        guard let guideProfileId = guide.guideProfileId else { return }
        let typingKey = roomGuideTypingKey(threadId: threadId, guideProfileId: guideProfileId)
        guard !roomGuideTypingKeys.contains(typingKey) else { return }

        roomGuideTypingKeys.insert(typingKey)
        defer { roomGuideTypingKeys.remove(typingKey) }

        do {
            if let reply = try await supabase.invokeRoomGuideReply(
                threadId: threadId,
                guideProfileId: guideProfileId
            ) {
                appendRoomMessage(reply)
            }
        } catch {
            CrashReporter.log(error, context: "requestRoomGuideReplyIfNeeded")
        }
    }

    private func appendRoomMessage(_ message: ChatMessage) {
        var messages = roomMessages(for: message.threadId)
        messages.removeAll { $0.id == message.id }
        messages.append(message)
        chatMessagesByThreadId[message.threadId] = messages.sorted { $0.createdAt < $1.createdAt }

        if let index = chatThreadSummaries.firstIndex(where: { $0.id == message.threadId }) {
            chatThreadSummaries[index].latestMessage = message
            chatThreadSummaries[index].thread.updatedAt = message.createdAt
            chatThreadSummaries.sort { $0.thread.updatedAt > $1.thread.updatedAt }
        }
    }

    private func removeRoomMessage(_ message: ChatMessage) {
        chatMessagesByThreadId[message.threadId]?.removeAll { $0.id == message.id }
        if let index = chatThreadSummaries.firstIndex(where: { $0.id == message.threadId }) {
            chatThreadSummaries[index].latestMessage = roomMessages(for: message.threadId).last
        }
    }

    private func resolvedRoomTitle(_ rawTitle: String, selectedProfiles: [SocialProfile]) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(64))
        }
        let names = selectedProfiles.prefix(3).map(\.displayName)
        return names.isEmpty ? "Guided Room" : names.joined(separator: ", ")
    }

    private func roomGuideTypingKey(threadId: UUID, guideProfileId: String) -> String {
        "\(threadId.uuidString)-\(guideProfileId)"
    }
}
