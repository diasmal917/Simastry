import SwiftUI

struct ZodiacBadgeView: View {
    let sign: ZodiacSign
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    init(sign: ZodiacSign, isSelected: Bool = false, size: CGFloat = 56, onTap: @escaping () -> Void = {}) {
        self.sign = sign
        self.isSelected = isSelected
        self.size = size
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            HapticManager.zodiacSelection()
            onTap()
        }) {
            ZStack {
                badgeBackground

                ZodiacIconView(sign: sign, size: size * 0.72, showsGlow: isSelected)
            }
            .opacity(isSelected ? 1.0 : 0.55)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(SimastrySpring.bouncy), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // Selection reads as a liquid-glass pane in the sign's color rather
    // than an outline — no stroke in either state.
    @ViewBuilder
    private var badgeBackground: some View {
        if isSelected {
            if #available(iOS 26.0, *) {
                Circle()
                    .fill(sign.color.opacity(0.18))
                    .frame(width: size, height: size)
                    .glassEffect(.regular.tint(sign.color.opacity(0.30)), in: .circle)
                    .shadow(color: sign.color.opacity(0.35), radius: size * 0.16)
            } else {
                Circle()
                    .fill(sign.color.opacity(0.26))
                    .frame(width: size, height: size)
                    .background(.ultraThinMaterial, in: .circle)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
                    }
                    .shadow(color: sign.color.opacity(0.35), radius: size * 0.16)
            }
        } else {
            Circle()
                .fill(sign.color.opacity(0.2))
                .frame(width: size, height: size)
        }
    }
}

struct ZodiacGridView: View {
    @Binding var selectedSign: ZodiacSign?
    var roleName: String? = nil
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ZodiacSign.allCases) { sign in
                VStack(spacing: 4) {
                    ZodiacBadgeView(sign: sign, isSelected: selectedSign == sign) {
                        selectedSign = sign
                    }
                    .accessibilityLabel("Select \(sign.displayName) as \(roleName ?? "zodiac") sign")
                    Text(sign.displayName)
                        .font(.caption2)
                        .foregroundStyle(selectedSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                }
            }
        }
        .padding(.horizontal)
    }
}
