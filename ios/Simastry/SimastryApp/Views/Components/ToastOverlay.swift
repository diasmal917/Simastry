import SwiftUI

struct ToastOverlay: View {
    @Binding var message: ToastMessage?
    @State private var isVisible: Bool = false
    @State private var dismissTask: Task<Void, Never>?

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
            dismissTask?.cancel()
            guard let newValue else { return }
            withAnimation(.spring(SimastrySpring.bouncy)) {
                isVisible = true
            }
            dismissTask = Task {
                do {
                    try await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled, message?.id == newValue else { return }
                    dismiss(expectedId: newValue)
                } catch { }
            }
        }
    }

    private func dismiss(expectedId: UUID? = nil) {
        dismissTask?.cancel()
        guard expectedId == nil || message?.id == expectedId else { return }
        withAnimation(.spring(SimastrySpring.smooth)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard expectedId == nil || message?.id == expectedId else { return }
            message = nil
        }
    }
}
