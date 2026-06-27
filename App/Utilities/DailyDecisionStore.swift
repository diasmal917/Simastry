import Foundation

nonisolated final class DailyDecisionStore {
    static let defaultsKey = "simastry_daily_decisions"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> [DailyDecision] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let decisions = try? decoder.decode([DailyDecision].self, from: data) else {
            return []
        }
        return decisions.sorted { $0.createdAt > $1.createdAt }
    }

    func latestForToday() -> DailyDecision? {
        load().first { Calendar.current.isDateInToday($0.createdAt) }
    }

    func save(_ decision: DailyDecision) {
        var decisions = load()
        decisions.removeAll {
            $0.id == decision.id
                || ($0.category == decision.category && Calendar.current.isDate($0.createdAt, inSameDayAs: decision.createdAt))
        }
        decisions.insert(decision, at: 0)
        persist(Array(decisions.prefix(24)))
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func persist(_ decisions: [DailyDecision]) {
        guard let data = try? encoder.encode(decisions) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
