import SwiftUI

struct GoldButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            HapticManager.buttonPress()
            action()
        }) {
            Text(title)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(isEnabled ? .white : SimastryColor.mutedSilver)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .goldGlassPill()
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.4)
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(SimastrySpring.snappy), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.buttonPress()
            action()
        }) {
            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .buttonStyle(.plain)
    }
}
