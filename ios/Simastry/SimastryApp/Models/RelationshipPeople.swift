import Foundation
import UIKit

nonisolated enum RelationshipType: String, CaseIterable, Identifiable, Codable, Sendable {
    case partner = "Partner"
    case friend = "Friend"
    case family = "Family"
    case teammate = "Teammate"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .partner: "heart.fill"
        case .friend: "person.2.fill"
        case .family: "house.fill"
        case .teammate: "person.3.fill"
        case .other: "person.fill"
        }
    }
}

/// What's currently happening with this person — the ongoing saga the app
/// follows. Statuses describe communication states, never verdicts.
nonisolated enum SituationStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case newSpark
    case waitingOnReply
    case steady
    case repairing
    case coolingOff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newSpark: "New spark"
        case .waitingOnReply: "Waiting on a reply"
        case .steady: "Steady"
        case .repairing: "Repairing"
        case .coolingOff: "Cooling off"
        }
    }

    var systemImage: String {
        switch self {
        case .newSpark: "sparkles"
        case .waitingOnReply: "ellipsis.bubble.fill"
        case .steady: "checkmark.circle.fill"
        case .repairing: "bandage.fill"
        case .coolingOff: "snowflake"
        }
    }
}

nonisolated struct RelationshipPerson: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var privateLabel: String?
    var relationshipType: RelationshipType
    var birthDate: Date?
    var birthTime: Date?
    var birthPlace: String?
    var sunSign: ZodiacSign
    var moonSign: ZodiacSign?
    var risingSign: ZodiacSign?
    var notes: String?
    var imageData: Data?
    var isChartCalculated: Bool
    var updatedAt: Date
    // Optional with defaults so people saved before situations existed
    // decode unchanged and existing memberwise call sites keep compiling.
    var situationStatus: SituationStatus? = nil
    var situationUpdatedAt: Date? = nil

    var displayName: String {
        let label = privateLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? name : label
    }

    /// 1-based day count of the current situation ("Day 1" on the day it's set).
    func situationDay(now: Date = Date()) -> Int {
        guard situationStatus != nil, let start = situationUpdatedAt else { return 1 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: now)
        ).day ?? 0
        return max(1, days + 1)
    }

    var signLine: String {
        var parts = ["\(sunSign.displayName) Sun"]
        if let moonSign {
            parts.append("\(moonSign.displayName) Moon")
        }
        if let risingSign {
            parts.append("\(risingSign.displayName) Rising")
        }
        return parts.joined(separator: " • ")
    }
}

nonisolated struct RelationshipPersonReading: Sendable {
    let headline: String
    let body: String
    let emotionalTone: String
    let communicationStyle: String
    let conflictStyle: String
    let repairStyle: String
    let bestEnergy: String
    let whatToAvoid: String
    let methodSummary: String
}

enum RelationshipReadingFactory {
    static func reading(
        for person: RelationshipPerson,
        userSun: ZodiacSign?,
        userMoon: ZodiacSign?,
        userRising: ZodiacSign?
    ) -> RelationshipPersonReading {
        let guide = CommunicationTemplates.guides[person.sunSign]
        let userMoonLine = userMoon.map { "Your \($0.displayName) Moon colors how quickly tone feels safe." }
            ?? "Your Moon sign is not available yet, so emotional timing is treated lightly."
        let userRisingLine = userRising.map { "Your \($0.displayName) Rising shapes the first move you instinctively make." }
            ?? "Your Rising sign is not available yet, so first-instinct cues stay general."
        let body = "\(relationshipBody(for: person)) \(userMoonLine) \(userRisingLine)"

        return RelationshipPersonReading(
            headline: "Today with \(person.displayName)",
            body: body,
            emotionalTone: emotionalTone(for: person, userMoon: userMoon),
            communicationStyle: guide?.bestApproach ?? "Lead with a clear tone and leave room for a human response.",
            conflictStyle: guide?.avoid ?? "Avoid escalating before the real need has been named.",
            repairStyle: repairStyle(for: person),
            bestEnergy: bestEnergy(for: person),
            whatToAvoid: whatToAvoid(for: person),
            methodSummary: person.isChartCalculated
                ? "Birth date was used to calculate available chart signals; missing time/place keeps Rising lighter."
                : "This uses user-provided sign signals, so the reading stays lighter and conversational."
        )
    }

    private static func relationshipBody(for person: RelationshipPerson) -> String {
        switch person.relationshipType {
        case .partner:
            "This connection is asking for warmth without pressure. Name the feeling, then let the reply breathe."
        case .friend:
            "This friendship benefits from light honesty today. A small check-in may land better than a full explanation."
        case .family:
            "\(person.displayName) may respond best to respect before reassurance. Keep care steady and avoid correction as the first note."
        case .teammate:
            "Clarity matters more than intensity here. Name the next step without turning the moment into a bigger story."
        case .other:
            "Keep the message human and grounded. Let the conversation reveal itself before defining the whole connection."
        }
    }

    private static func emotionalTone(for person: RelationshipPerson, userMoon: ZodiacSign?) -> String {
        if let moon = person.moonSign {
            return "\(moon.displayName) Moon cues suggest emotional safety matters before speed."
        }
        if let userMoon {
            return "Your \(userMoon.displayName) Moon may set the emotional weather first."
        }
        return "Emotional tone is read from relationship context and Sun-sign rhythm."
    }

    private static func repairStyle(for person: RelationshipPerson) -> String {
        switch person.sunSign.element {
        case .fire:
            "Repair through clean honesty and a warm reset."
        case .earth:
            "Repair through consistency, specifics, and visible follow-through."
        case .air:
            "Repair through fair language and space to think."
        case .water:
            "Repair through emotional validation before problem-solving."
        }
    }

    private static func bestEnergy(for person: RelationshipPerson) -> String {
        switch person.sunSign.element {
        case .fire: "Warm honesty"
        case .earth: "Calm specificity"
        case .air: "Curious listening"
        case .water: "Emotional safety"
        }
    }

    private static func whatToAvoid(for person: RelationshipPerson) -> String {
        switch person.relationshipType {
        case .partner:
            "Testing the tone instead of naming the need."
        case .friend:
            "Over-explaining before they have asked."
        case .family:
            "Turning care into correction."
        case .teammate:
            "Reading urgency as rejection."
        case .other:
            "Trying to define the whole connection today."
        }
    }
}

final class RelationshipPeopleStore {
    private let fileName = "relationship_people.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadPeople() -> [RelationshipPerson] {
        guard let data = try? Data(contentsOf: fileURL),
              let people = try? decoder.decode([RelationshipPerson].self, from: data) else {
            return []
        }
        return people
    }

    func savePeople(_ people: [RelationshipPerson]) {
        guard let data = try? encoder.encode(people) else { return }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: [.atomic])
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func previewPeople() -> [RelationshipPerson] {
        [
            RelationshipPerson(
                id: UUID(),
                name: "Maya",
                privateLabel: nil,
                relationshipType: .partner,
                birthDate: Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 12)),
                birthTime: nil,
                birthPlace: "Miami",
                sunSign: .leo,
                moonSign: .cancer,
                risingSign: .libra,
                notes: "Warmth is present, but timing matters.",
                imageData: nil,
                isChartCalculated: false,
                updatedAt: .now.addingTimeInterval(-2 * 24 * 60 * 60),
                situationStatus: .waitingOnReply,
                situationUpdatedAt: .now.addingTimeInterval(-24 * 60 * 60)
            ),
            RelationshipPerson(
                id: UUID(),
                name: "Alex",
                privateLabel: nil,
                relationshipType: .friend,
                birthDate: nil,
                birthTime: nil,
                birthPlace: "Austin",
                sunSign: .libra,
                moonSign: nil,
                risingSign: nil,
                notes: "Ease returns when decisions are not rushed.",
                imageData: nil,
                isChartCalculated: false,
                updatedAt: .now.addingTimeInterval(-6 * 60 * 60)
            ),
            RelationshipPerson(
                id: UUID(),
                name: "Daniel",
                privateLabel: "Family",
                relationshipType: .family,
                birthDate: nil,
                birthTime: nil,
                birthPlace: nil,
                sunSign: .capricorn,
                moonSign: nil,
                risingSign: nil,
                notes: "Respect lands better than reassurance today.",
                imageData: nil,
                isChartCalculated: false,
                updatedAt: .now.addingTimeInterval(-5 * 24 * 60 * 60)
            ),
            RelationshipPerson(
                id: UUID(),
                name: "Jordan",
                privateLabel: nil,
                relationshipType: .teammate,
                birthDate: nil,
                birthTime: nil,
                birthPlace: "Boston",
                sunSign: .aquarius,
                moonSign: .aries,
                risingSign: nil,
                notes: "Leads with ideas; give the plan room to breathe.",
                imageData: nil,
                isChartCalculated: false,
                updatedAt: .now.addingTimeInterval(-26 * 60 * 60)
            )
        ]
    }

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "Simastry", directoryHint: .isDirectory)
    }

    private var fileURL: URL {
        directoryURL.appending(path: fileName)
    }
}

enum SimastryPersonPhoto {
    static func prepared(_ data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
