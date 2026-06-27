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
            // Just the zodiac icon — no outer disc/ring behind it. Selection is
            // shown by full opacity, a gentle scale-up, and the icon's own glow.
            ZodiacIconView(sign: sign, size: size, showsGlow: isSelected)
                .opacity(isSelected ? 1.0 : 0.5)
                .scaleEffect(isSelected ? 1.12 : 1.0)
                .animation(.spring(SimastrySpring.bouncy), value: isSelected)
        }
        .buttonStyle(.plain)
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
