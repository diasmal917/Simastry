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

    var body: some View {
        Button(action: {
            HapticManager.buttonPress()
            action()
        }) {
            Text(title)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(isEnabled ? Color(red: 20/255, green: 18/255, blue: 12/255) : SimastryColor.mutedSilver)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [SimastryColor.goldDark, SimastryColor.gold, SimastryColor.goldLight],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(1)
                )
                .clipShape(Capsule())
                .shadow(color: SimastryColor.gold.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(GoldButtonStyle())
        .opacity(isEnabled ? 1.0 : 0.4)
        .disabled(!isEnabled)
    }
}

private struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(SimastrySpring.snappy), value: configuration.isPressed)
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
