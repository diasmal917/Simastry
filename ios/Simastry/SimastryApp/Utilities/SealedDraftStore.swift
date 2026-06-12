import Foundation

// MARK: - Sealed Drafts
// The 1am protocol: a message she's not sure she should send gets sealed
// until morning instead of sent into the night. Drafts live only in this
// device's UserDefaults — the text never leaves the phone.

nonisolated struct SealedDraft: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var text: String
    var targetSign: ZodiacSign?
    var personName: String?
    var createdAt: Date = Date()
    var releaseAt: Date

    func isReleased(now: Date = Date()) -> Bool {
        now >= releaseAt
    }
}

nonisolated final class SealedDraftStore {
    static let defaultsKey = "simastry_sealed_drafts"

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [SealedDraft] {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let drafts = try? decoder.decode([SealedDraft].self, from: data) else {
            return []
        }
        return drafts.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ draft: SealedDraft) {
        persist([draft] + load().filter { $0.id != draft.id })
    }

    func delete(id: UUID) {
        persist(load().filter { $0.id != id })
    }

    func deleteAll() {
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    func held(now: Date = Date()) -> [SealedDraft] {
        load().filter { !$0.isReleased(now: now) }
    }

    func released(now: Date = Date()) -> [SealedDraft] {
        load().filter { $0.isReleased(now: now) }
    }

    private func persist(_ drafts: [SealedDraft]) {
        // Cap at 5 — this is a vault for tonight, not an archive.
        guard let data = try? encoder.encode(Array(drafts.prefix(5))) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    /// The next 8:30am strictly after `date` — tonight's draft unseals
    /// tomorrow morning; a daytime draft unseals the next morning.
    static func nextMorningRelease(after date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 8
        components.minute = 30
        let todayMorning = calendar.date(from: components) ?? date
        if todayMorning > date {
            return todayMorning
        }
        return calendar.date(byAdding: .day, value: 1, to: todayMorning) ?? todayMorning
    }

    /// Late-night window where the seal action leads.
    static func isLateNight(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 21 || hour < 5
    }
}
