import Foundation

enum SharedDefaults {
    static let suiteName = "group.com.simastry.shared"

    enum Key {
        static let companionName = "widgetCompanionName"
        static let companionSunSign = "widgetCompanionSunSign"
        static let companionGlyph = "widgetCompanionGlyph"
        static let userSunSign = "widgetUserSunSign"
        static let userGlyph = "widgetUserGlyph"
        static let compatibilityScore = "widgetCompatibilityScore"
        static let companionId = "widgetCompanionId"
    }

    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Write (called from main app)

    static func writeCompanionData(
        companionName: String,
        companionSunSign: String,
        companionGlyph: String,
        userSunSign: String,
        userGlyph: String,
        compatibilityScore: Int,
        companionId: String
    ) {
        guard let defaults = shared else { return }
        defaults.set(companionName, forKey: Key.companionName)
        defaults.set(companionSunSign, forKey: Key.companionSunSign)
        defaults.set(companionGlyph, forKey: Key.companionGlyph)
        defaults.set(userSunSign, forKey: Key.userSunSign)
        defaults.set(userGlyph, forKey: Key.userGlyph)
        defaults.set(compatibilityScore, forKey: Key.compatibilityScore)
        defaults.set(companionId, forKey: Key.companionId)
    }

    // MARK: - Read (called from widget)

    static func readCompanionName() -> String? {
        shared?.string(forKey: Key.companionName)
    }

    static func readCompanionGlyph() -> String {
        shared?.string(forKey: Key.companionGlyph) ?? "SIM"
    }

    static func readUserGlyph() -> String {
        shared?.string(forKey: Key.userGlyph) ?? "YOU"
    }

    static func readCompatibilityScore() -> Int {
        shared?.integer(forKey: Key.compatibilityScore) ?? 0
    }

    static func readCompanionId() -> String? {
        shared?.string(forKey: Key.companionId)
    }

    static func hasCompanionData() -> Bool {
        readCompanionName() != nil
    }

    // MARK: - Clear

    static func clearAll() {
        guard let defaults = shared else { return }
        for key in [Key.companionName, Key.companionSunSign, Key.companionGlyph,
                    Key.userSunSign, Key.userGlyph, Key.compatibilityScore, Key.companionId] {
            defaults.removeObject(forKey: key)
        }
    }
}
