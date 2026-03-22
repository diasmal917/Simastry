import SwiftUI

struct ToastOverlay: View {
    @Binding var message: ToastMessage?
    @State private var isVisible: Bool = false

    var body: some View {
        VStack {
            if let msg = message, isVisible {
                HStack(spacing: 12) {
                    Image(systemName: msg.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(msg.isError ? SimastryColor.amber : SimastryColor.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(msg.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                        Text(msg.subtitle)
                            .font(.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .simastryGlass(cornerRadius: 20)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.height < -10 {
                                dismiss()
                            }
                        }
                )
            }

            Spacer()
        }
        .onChange(of: message?.id) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.spring(SimastrySpring.bouncy)) {
                isVisible = true
            }
            Task {
                try? await Task.sleep(for: .seconds(4))
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(SimastrySpring.smooth)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            message = nil
        }
    }
}
