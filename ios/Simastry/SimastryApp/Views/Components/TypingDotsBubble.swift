import SwiftUI
import Combine

/// Chat "is typing" bubble with an animated three-dot wave, generic over the
/// sender avatar so 1:1 threads and the panel chat share one implementation.
struct TypingDotsBubble<Avatar: View>: View {
    let avatar: Avatar
    @State private var phase: Int = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    init(@ViewBuilder avatar: () -> Avatar) {
        self.avatar = avatar()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            avatar

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(SimastryColor.mutedSilver)
                        .frame(width: 7, height: 7)
                        .opacity(phase == index ? 0.95 : 0.35)
                        .scaleEffect(phase == index ? 1.12 : 1.0)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(SimastryColor.surface.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 0.7)
                    }
            }

            Spacer(minLength: 54)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("Typing a reply")
    }
}
