import Foundation

nonisolated struct SearchableUserProfile: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarURL: String?
    let avatarPath: String?
    let bio: String
    let sunSign: ZodiacSign?
    let moonSign: ZodiacSign?
    let risingSign: ZodiacSign?
    let communicationHint: String
    let iceBreakers: [String]

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case avatarPath = "avatar_path"
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case communicationHint = "communication_hint"
        case iceBreakers = "ice_breakers"
    }

    init(
        id: UUID,
        username: String,
        displayName: String?,
        avatarURL: String? = nil,
        avatarPath: String? = nil,
        bio: String? = nil,
        sunSign: ZodiacSign? = nil,
        moonSign: ZodiacSign? = nil,
        risingSign: ZodiacSign? = nil,
        communicationHint: String? = nil,
        iceBreakers: [String] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName?.nilIfBlank ?? "@\(username)"
        self.avatarURL = avatarURL?.nilIfBlank
        self.avatarPath = avatarPath?.nilIfBlank
        self.bio = bio?.nilIfBlank ?? "No bio yet."
        self.sunSign = sunSign
        self.moonSign = moonSign
        self.risingSign = risingSign
        self.communicationHint = communicationHint?.nilIfBlank ?? Self.defaultCommunicationHint(for: sunSign)
        self.iceBreakers = iceBreakers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let username = try container.decode(String.self, forKey: .username)
        let displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        let avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        let avatarPath = try container.decodeIfPresent(String.self, forKey: .avatarPath)
        let bio = try container.decodeIfPresent(String.self, forKey: .bio)
        let sunSign = try container.decodeIfPresent(ZodiacSign.self, forKey: .sunSign)
        let moonSign = try container.decodeIfPresent(ZodiacSign.self, forKey: .moonSign)
        let risingSign = try container.decodeIfPresent(ZodiacSign.self, forKey: .risingSign)
        let communicationHint = try container.decodeIfPresent(String.self, forKey: .communicationHint)
        let iceBreakers = try container.decodeIfPresent([String].self, forKey: .iceBreakers) ?? []

        self.init(
            id: id,
            username: username,
            displayName: displayName,
            avatarURL: avatarURL,
            avatarPath: avatarPath,
            bio: bio,
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            communicationHint: communicationHint,
            iceBreakers: iceBreakers
        )
    }

    var accentSign: ZodiacSign {
        sunSign ?? moonSign ?? risingSign ?? .libra
    }

    var placementLine: String {
        var parts: [String] = []
        if let sunSign {
            parts.append("\(sunSign.displayName) Sun")
        }
        if let moonSign {
            parts.append("\(moonSign.displayName) Moon")
        }
        if let risingSign {
            parts.append("\(risingSign.displayName) Rising")
        }
        return parts.isEmpty ? "Signs pending" : parts.joined(separator: " • ")
    }

    var searchableText: String {
        [username, displayName, bio, placementLine]
            .joined(separator: " ")
            .lowercased()
    }

    var lastActiveLine: String {
        "available in Simastry"
    }

    var suggestedIceBreakers: [String] {
        if !iceBreakers.isEmpty {
            return iceBreakers
        }
        if let sunSign {
            return ConversationPromptLibrary.guidePrompts(for: sunSign)
        }
        return ConversationPromptLibrary.genericPrompts
    }

    private static func defaultCommunicationHint(for sign: ZodiacSign?) -> String {
        guard let sign else {
            return "Start with curiosity, keep it kind, and ask one clear question."
        }
        return CommunicationTemplates.guides[sign]?.bestApproach
            ?? "Start with curiosity, keep it kind, and ask one clear question."
    }
}

nonisolated struct PublicProfileUpsert: Encodable, Sendable {
    let id: UUID
    let username: String?
    let displayName: String?
    let avatarURL: String?
    let avatarPath: String?
    let bio: String?
    let sunSign: ZodiacSign?
    let moonSign: ZodiacSign?
    let risingSign: ZodiacSign?
    let communicationHint: String?
    let iceBreakers: [String]
    let isDiscoverable: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case avatarPath = "avatar_path"
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case communicationHint = "communication_hint"
        case iceBreakers = "ice_breakers"
        case isDiscoverable = "is_discoverable"
    }
}

nonisolated struct UserConnectionRow: Codable, Sendable {
    let ownerId: UUID?
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case profileId = "profile_id"
    }
}

nonisolated struct UserConnectionInsert: Encodable, Sendable {
    let ownerId: UUID
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case profileId = "profile_id"
    }
}

nonisolated struct AvatarUploadResult: Sendable {
    let path: String
    let publicURL: String
}

nonisolated enum ConversationPromptLibrary {
    static let genericPrompts = [
        "What should I ask first?",
        "What would make this feel easy?",
        "How do I start without overthinking?"
    ]

    static func guidePrompts(for sign: ZodiacSign) -> [String] {
        switch sign {
        case .aries:
            ["How do I say this directly?", "What bold opener works here?", "What should I not overthink?"]
        case .taurus:
            ["How do I make this feel steady?", "What would reassure them?", "What is the patient move?"]
        case .gemini:
            ["What playful question opens them up?", "How do I keep this interesting?", "What tangent should I follow?"]
        case .cancer:
            ["How do I make this feel safe?", "What gentle check-in should I send?", "What emotion should I name?"]
        case .leo:
            ["How do I make them feel seen?", "What compliment stays real?", "What warm opener works?"]
        case .virgo:
            ["How do I make this clearer?", "What detail matters most?", "What practical question helps?"]
        case .libra:
            ["How do I keep this graceful?", "What question feels charming?", "How do I invite balance?"]
        case .scorpio:
            ["How do I go deeper without pushing?", "What honest opener works?", "What should I avoid hiding?"]
        case .sagittarius:
            ["How do I make this feel free?", "What adventurous question lands?", "What truth should I lead with?"]
        case .capricorn:
            ["How do I respect their time?", "What serious question still feels warm?", "How do I show consistency?"]
        case .aquarius:
            ["What unusual question will hook them?", "How do I give them space?", "What idea should I invite?"]
        case .pisces:
            ["How do I make this softer?", "What imaginative opener works?", "What feeling should I follow?"]
        }
    }
}

private extension String {
    nonisolated var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
