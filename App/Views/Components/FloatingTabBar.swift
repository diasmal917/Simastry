import SwiftUI

/// Floating Liquid Glass navigation pill — icon-only tabs with a large selected
/// capsule, unread/follow-up dots, and full accessibility. Replaces the system
/// tab bar so Simastry reads as a single daily surface rather than a stack of
/// separate screens.
///
/// - On iOS 26 it renders real `glassEffect` inside a `GlassEffectContainer`.
/// - On iOS 18 it falls back to an `.ultraThinMaterial`-backed capsule.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    /// Unread Talk items — drives the dot on the Talk tab.
    var unreadCount: Int
    /// A prediction is awaiting an outcome — drives the dot on the Predict tab.
    var predictFollowUp: Bool

    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height: CGFloat = 56

    var body: some View {
        bar
            .padding(.horizontal, 22)
            .padding(.bottom, 6)
    }

    private var bar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.visualOrder) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .frame(height: height)
        .glassPillBackground()
        .frame(maxWidth: 420)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            guard selection != tab else { return }
            if reduceMotion {
                selection = tab
            } else {
                withAnimation(.spring(SimastrySpring.snappy)) {
                    selection = tab
                }
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SimastryColor.goldLight, SimastryColor.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: SimastryColor.gold.opacity(0.45), radius: 10, y: 3)
                        .matchedGeometryEffect(id: "selectedTab", in: indicator)
                        .padding(.vertical, 2)
                }

                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite)
                    .symbolRenderingMode(.hierarchical)
                    .frame(maxWidth: .infinity)
                    .frame(height: height - 10)
                    .overlay(alignment: .topTrailing) {
                        if let dot = dotColor(for: tab) {
                            Circle()
                                .fill(dot)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle().stroke(SimastryColor.midnight.opacity(0.6), lineWidth: 1.5)
                                )
                                .offset(x: -10, y: 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height - 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityValue(accessibilityValue(for: tab))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : "Switches to \(tab.title)")
    }

    private func dotColor(for tab: AppTab) -> Color? {
        switch tab {
        case .messages: unreadCount > 0 ? SimastryColor.sunCoral : nil
        case .predict: predictFollowUp ? SimastryColor.gold : nil
        default: nil
        }
    }

    private func accessibilityValue(for tab: AppTab) -> String {
        switch tab {
        case .messages where unreadCount > 0:
            "\(unreadCount) unread"
        case .predict where predictFollowUp:
            "Outcome to log"
        default:
            ""
        }
    }
}

private extension View {
    /// One real glass surface for the whole pill — never stacked under another
    /// glass layer, so iOS 26 renders a single clean Liquid Glass control.
    @ViewBuilder
    func glassPillBackground() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                self
                    .glassEffect(
                        .regular.tint(SimastryColor.offWhite.opacity(0.06)).interactive(),
                        in: .capsule
                    )
            }
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.06), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.30), radius: 22, y: 12)
        } else {
            self
                .background(SimastryColor.surface.opacity(0.72), in: .capsule)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                )
                .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
        }
    }
}
