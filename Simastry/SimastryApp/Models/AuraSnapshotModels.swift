import Foundation

nonisolated enum AuraSnapshotMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case tender
    case bold
    case restless
    case focused
    case romantic
    case overthinking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tender: "Tender"
        case .bold: "Bold"
        case .restless: "Restless"
        case .focused: "Focused"
        case .romantic: "Romantic"
        case .overthinking: "Overthinking"
        }
    }

    var promptValue: String { rawValue }
}

nonisolated enum AuraImageWarmth: String, Codable, Sendable {
    case cool
    case neutral
    case warm

    var title: String { rawValue.capitalized }
}

nonisolated enum AuraBrightness: String, Codable, Sendable {
    case dim
    case balanced
    case luminous

    var title: String { rawValue.capitalized }
}

nonisolated enum AuraContrast: String, Codable, Sendable {
    case soft
    case balanced
    case crisp

    var title: String { rawValue.capitalized }
}

nonisolated struct AuraSnapshotDescriptor: Codable, Equatable, Sendable {
    let auraColor: String
    let imageWarmth: AuraImageWarmth
    let brightness: AuraBrightness
    let contrast: AuraContrast
    let selectedMood: AuraSnapshotMood
    let createdAt: Date

    init(
        auraColor: String,
        imageWarmth: AuraImageWarmth,
        brightness: AuraBrightness,
        contrast: AuraContrast,
        selectedMood: AuraSnapshotMood,
        createdAt: Date = Date()
    ) {
        self.auraColor = auraColor
        self.imageWarmth = imageWarmth
        self.brightness = brightness
        self.contrast = contrast
        self.selectedMood = selectedMood
        self.createdAt = createdAt
    }

    var compactSummary: String {
        [
            "auraColor: \(auraColor)",
            "imageWarmth: \(imageWarmth.rawValue)",
            "brightness: \(brightness.rawValue)",
            "contrast: \(contrast.rawValue)",
            "selectedMood: \(selectedMood.promptValue)"
        ].joined(separator: "\n")
    }

    var displayLine: String {
        "\(auraColor.capitalized) · \(imageWarmth.title) · \(brightness.title) · \(selectedMood.title)"
    }
}

nonisolated struct AuraSnapshotResult: Codable, Equatable, Sendable {
    let todayVibe: String
    let bestMove: String
    let wearEatFocus: String
    let textingHint: String
    let predictionTuningNote: String

    init(
        todayVibe: String,
        bestMove: String,
        wearEatFocus: String,
        textingHint: String,
        predictionTuningNote: String
    ) {
        self.todayVibe = todayVibe
        self.bestMove = bestMove
        self.wearEatFocus = wearEatFocus
        self.textingHint = textingHint
        self.predictionTuningNote = predictionTuningNote
    }
}

nonisolated struct AuraSnapshot: Codable, Equatable, Sendable {
    let descriptor: AuraSnapshotDescriptor
    let result: AuraSnapshotResult
}
