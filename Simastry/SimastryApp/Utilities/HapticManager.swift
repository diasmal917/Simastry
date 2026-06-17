import UIKit

struct HapticManager {
    static func zodiacSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func signConfirmed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func createSoul() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func soulFlash() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func themeToggle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func tabChange() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func errorToast() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func buttonPress() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
