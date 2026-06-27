import Foundation

nonisolated struct SavedDailyPrompt: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let text: String
    let guideId: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, guideId: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.guideId = guideId
        self.createdAt = createdAt
    }
}

nonisolated final class DailyPromptStore {
    static let defaultsKey = "simastry_saved_daily_prompts"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SavedDailyPrompt] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let prompts = try? JSONDecoder().decode([SavedDailyPrompt].self, from: data) else {
            return []
        }
        return prompts.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ prompt: SavedDailyPrompt) {
        var prompts = load()
        prompts.removeAll { $0.text == prompt.text }
        prompts.insert(prompt, at: 0)
        prompts = Array(prompts.prefix(12))
        guard let data = try? JSONEncoder().encode(prompts) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
