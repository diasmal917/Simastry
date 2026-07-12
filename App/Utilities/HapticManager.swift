import UIKit

struct HapticManager {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func zodiacSelection() {
        selection()
    }

    static func signConfirmed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func createSoul() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func soulFlash() {
        success()
    }

    static func themeToggle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func tabChange() {
        selection()
    }

    static func errorToast() {
        error()
    }

    static func buttonPress() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
