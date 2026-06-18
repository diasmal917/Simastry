import SwiftUI

/// A reusable coach mark / feature tip overlay.
/// Glass card with a gold accent border, SF Symbol icon, title, message, and dismiss button.
/// Appears with a subtle scale+fade animation and auto-dismisses via FeatureTipManager.
struct FeatureTipView: View {
    let icon: String
    let title: String
    let message: String
    let tip: FeatureTipManager.Tip

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isVisible {
                tipCard
            }
        }
        .onAppear {
            guard FeatureTipManager.shared.shouldShow(tip) else { return }
            let animDelay = reduceMotion ? 0.1 : 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + animDelay) {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth)) {
                        isVisible = true
                    }
                }
            }
        }
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 36, height: 36)
                .background(SimastryColor.gold.opacity(0.14), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(message)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                Button {
                    dismissTip()
                } label: {
                    Text("Got it")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.gold)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: SimastryRadius.medium)
                .fill(Color.white.opacity(0.04))
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: SimastryRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: SimastryRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [
                            SimastryColor.goldLight.opacity(0.30),
                            SimastryColor.gold.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .transition(
            reduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Dismiss") {
            dismissTip()
        }
    }

    private func dismissTip() {
        if reduceMotion {
            isVisible = false
            FeatureTipManager.shared.dismiss(tip)
        } else {
            withAnimation(.spring(SimastrySpring.snappy)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                FeatureTipManager.shared.dismiss(tip)
            }
        }
    }
}

// MARK: - View Modifier for Overlay Tips

/// A view modifier that conditionally overlays a FeatureTipView below the content.
struct FeatureTipOverlay: ViewModifier {
    let icon: String
    let title: String
    let message: String
    let tip: FeatureTipManager.Tip
    let alignment: Alignment
    let delay: Double

    @State private var shouldShow: Bool = false
    @State private var isVisible: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if shouldShow {
                    FeatureTipInlineView(
                        icon: icon,
                        title: title,
                        message: message,
                        tip: tip,
                        isVisible: $isVisible,
                        onDismissed: {
                            shouldShow = false
                        }
                    )
                    .padding(.top, alignment == .bottom ? 8 : 0)
                    .padding(.bottom, alignment == .top ? 8 : 0)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.92, anchor: alignment == .bottom ? .top : .bottom))
                    )
                }
            }
            .onAppear {
                guard FeatureTipManager.shared.shouldShow(tip) else { return }
                shouldShow = true
                let animDelay = reduceMotion ? 0.1 : delay
                DispatchQueue.main.asyncAfter(deadline: .now() + animDelay) {
                    if reduceMotion {
                        isVisible = true
                    } else {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            isVisible = true
                        }
                    }
                }
            }
    }
}

/// Internal view used by the overlay modifier -- keeps dismiss state local.
private struct FeatureTipInlineView: View {
    let icon: String
    let title: String
    let message: String
    let tip: FeatureTipManager.Tip
    @Binding var isVisible: Bool
    let onDismissed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 36, height: 36)
                    .background(SimastryColor.gold.opacity(0.14), in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(message)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    Button {
                        dismissTip()
                    } label: {
                        Text("Got it")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.gold)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: SimastryRadius.medium)
                    .fill(Color.white.opacity(0.04))
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: SimastryRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: SimastryRadius.medium)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SimastryColor.goldLight.opacity(0.30),
                                SimastryColor.gold.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")
            .accessibilityAddTraits(.isStaticText)
            .accessibilityAction(named: "Dismiss") {
                dismissTip()
            }
        }
    }

    private func dismissTip() {
        FeatureTipManager.shared.dismiss(tip)
        if reduceMotion {
            isVisible = false
            onDismissed()
        } else {
            withAnimation(.spring(SimastrySpring.snappy)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onDismissed()
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a one-time feature tip overlay to this view.
    func featureTip(
        icon: String,
        title: String,
        body message: String,
        tip: FeatureTipManager.Tip,
        alignment: Alignment = .bottom,
        delay: Double = 0.6
    ) -> some View {
        modifier(
            FeatureTipOverlay(
                icon: icon,
                title: title,
                message: message,
                tip: tip,
                alignment: alignment,
                delay: delay
            )
        )
    }
}
