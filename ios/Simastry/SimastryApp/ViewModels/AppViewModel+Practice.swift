import Foundation

// MARK: - Practice Conversations
// The Simulation Room's core: rehearse a sensitive conversation with a
// persona built from someone's chart and the user's own description.
// Threads are device-local; the persona is a rehearsal, never the person.

nonisolated struct PracticeMessage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    let isUser: Bool
    let content: String
    var timestamp: Date = Date()
}

extension AppViewModel {
    static let practiceThreadsKey = "simastry_practice_threads"

    func practiceThread(for personId: UUID) -> [PracticeMessage] {
        loadPracticeThreads()[personId.uuidString] ?? []
    }

    func savePracticeThread(_ messages: [PracticeMessage], for personId: UUID) {
        var threads = loadPracticeThreads()
        // Keep rehearsals short-lived in storage: last 40 messages per person.
        threads[personId.uuidString] = Array(messages.suffix(40))
        persistPracticeThreads(threads)
    }

    func clearPracticeThread(for personId: UUID) {
        var threads = loadPracticeThreads()
        threads.removeValue(forKey: personId.uuidString)
        persistPracticeThreads(threads)
    }

    private func loadPracticeThreads() -> [String: [PracticeMessage]] {
        guard let data = UserDefaults.standard.data(forKey: Self.practiceThreadsKey) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: [PracticeMessage]].self, from: data)) ?? [:]
    }

    private func persistPracticeThreads(_ threads: [String: [PracticeMessage]]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(threads) else { return }
        UserDefaults.standard.set(data, forKey: Self.practiceThreadsKey)
    }

    /// One persona reply: live channel when available, deterministic
    /// template fallback otherwise — practice never stalls dark.
    func generatePracticeReply(
        person: RelationshipPerson,
        transcript: [GuideReplyService.TranscriptEntry],
        threadCount: Int
    ) async -> String {
        if AppConfig.llmChatEnabled, supabase.canInvokeCompanionReply {
            let situationLine = person.situationStatus.map { "\($0.title), day \(person.situationDay())" }
            let (system, user) = GuideReplyService.practicePersonaPrompt(
                personName: person.displayName,
                personSigns: person.signLine,
                relationshipType: person.relationshipType.rawValue,
                pronouns: person.pronouns,
                ageBand: person.ageBand,
                textingStyles: person.textingStyles ?? [],
                situationLine: situationLine,
                contextNotes: person.notes,
                user: GuideReplyService.UserContext(
                    name: (profile?.displayName ?? "").components(separatedBy: " ").first,
                    sun: userSunSign,
                    moon: userMoonSign,
                    rising: userRisingSign,
                    communicationType: nil
                ),
                transcript: transcript
            )
            if let reply = await GuideReplyService.withTimeout(seconds: GuideReplyService.chatReplyTimeout, operation: { [supabase] in
                try await supabase.invokeCompanionReply(kind: .chat, system: system, user: user, maxTokens: 200)
            }) {
                return reply
            }
        }
        return Self.composePracticeReply(
            sign: person.sunSign,
            textingStyles: person.textingStyles ?? [],
            threadCount: threadCount
        )
    }

    /// Template persona reply — the person's sign-voiced likely replies,
    /// shaped by their described texting style. Deterministic per turn.
    nonisolated static func composePracticeReply(
        sign: ZodiacSign,
        textingStyles: [String],
        threadCount: Int
    ) -> String {
        let replies = AstrologyTemplates.likelyReplies[sign.displayName] ?? ["Hm. Let me sit with that for a second."]
        var reply = replies[threadCount % replies.count]

        if textingStyles.contains("dry"),
           let firstSentence = reply.split(separator: ".").first,
           !firstSentence.isEmpty {
            reply = String(firstSentence) + "."
        }
        if textingStyles.contains("slow replier") && threadCount % 3 == 2 {
            reply = "(after a while) " + reply
        }
        return reply
    }
}
