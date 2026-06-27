import Foundation

@MainActor
@Observable
final class TodayStore {
    private let promptStore: DailyPromptStore
    private let decisionStore: DailyDecisionStore

    var savedDailyPrompts: [SavedDailyPrompt]
    var dailyDecisions: [DailyDecision]

    init(
        promptStore: DailyPromptStore = DailyPromptStore(),
        decisionStore: DailyDecisionStore = DailyDecisionStore()
    ) {
        self.promptStore = promptStore
        self.decisionStore = decisionStore
        self.savedDailyPrompts = promptStore.load()
        self.dailyDecisions = decisionStore.load()
    }

    var latestDailyDecision: DailyDecision? {
        dailyDecisions.first { Calendar.current.isDateInToday($0.createdAt) }
            ?? dailyDecisions.first
    }

    func reloadSavedPrompts() {
        savedDailyPrompts = promptStore.load()
    }

    func reloadDailyDecisions() {
        dailyDecisions = decisionStore.load()
    }

    func savePrompt(_ prompt: SavedDailyPrompt) {
        promptStore.save(prompt)
        reloadSavedPrompts()
    }

    func saveDailyDecision(_ decision: DailyDecision) {
        decisionStore.save(decision)
        reloadDailyDecisions()
    }

    func clearSavedPrompts() {
        promptStore.clear()
        savedDailyPrompts = []
    }

    func clearDailyDecisions() {
        decisionStore.clear()
        dailyDecisions = []
    }
}
