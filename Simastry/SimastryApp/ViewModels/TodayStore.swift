import Foundation

@MainActor
@Observable
final class TodayStore {
    private let promptStore: DailyPromptStore

    var savedDailyPrompts: [SavedDailyPrompt]

    init(promptStore: DailyPromptStore = DailyPromptStore()) {
        self.promptStore = promptStore
        self.savedDailyPrompts = promptStore.load()
    }

    func reloadSavedPrompts() {
        savedDailyPrompts = promptStore.load()
    }

    func savePrompt(_ prompt: SavedDailyPrompt) {
        promptStore.save(prompt)
        reloadSavedPrompts()
    }

    func clearSavedPrompts() {
        promptStore.clear()
        savedDailyPrompts = []
    }
}
