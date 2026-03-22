import SwiftUI

struct GoogleSignInButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.buttonPress()
            action()
        }) {
            HStack(spacing: 10) {
                GoogleMarkView()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.black.opacity(0.88))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white.opacity(0.96), in: .rect(cornerRadius: 999))
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.985 : 1.0)
        .animation(.spring(SimastrySpring.snappy), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

private struct GoogleMarkView: View {
    private let googleColors: [Color] = [
        Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255),
        Color(red: 52 / 255, green: 168 / 255, blue: 83 / 255),
        Color(red: 251 / 255, green: 188 / 255, blue: 5 / 255),
        Color(red: 234 / 255, green: 67 / 255, blue: 53 / 255),
    ]

    var body: some View {
        Text("G")
            .font(SimastryFont.titleSmall)
            .foregroundStyle(
                LinearGradient(
                    colors: googleColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 22, height: 22)
    }
}
