import SwiftUI

struct ZodiacWheelView: View {
    let label: String
    @Binding var selectedSign: ZodiacSign
    @State private var scrolledID: ZodiacSign?

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(SimastryFont.titleMedium)
                .foregroundStyle(AstropediaColors.gold)
                .frame(width: 32)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ZodiacSign.allCases) { sign in
                        let isSelected = sign == selectedSign
                        let distance = signDistance(from: sign)

                        Button {
                            withAnimation(.spring(SimastrySpring.snappy)) {
                                selectedSign = sign
                                scrolledID = sign
                            }
                            HapticManager.zodiacSelection()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(sign.color.opacity(isSelected ? 0.35 : 0.15))
                                    .frame(width: circleSize(distance: distance), height: circleSize(distance: distance))

                                if isSelected {
                                    Circle()
                                        .stroke(AstropediaColors.gold, lineWidth: 2)
                                        .frame(width: circleSize(distance: distance) + 4, height: circleSize(distance: distance) + 4)
                                }

                                ZodiacIconView(
                                    sign: sign,
                                    size: circleSize(distance: distance) * 0.72,
                                    showsGlow: isSelected
                                )
                            }
                            .opacity(opacityForDistance(distance))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSign)
                        }
                        .buttonStyle(.plain)
                        .id(sign)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 60)
            .onAppear {
                scrolledID = selectedSign
            }
            .onChange(of: scrolledID) { _, newValue in
                if let newValue, newValue != selectedSign {
                    withAnimation(.spring(SimastrySpring.snappy)) {
                        selectedSign = newValue
                    }
                    HapticManager.zodiacSelection()
                }
            }
        }
        .frame(height: 72)
    }

    private func signDistance(from sign: ZodiacSign) -> Int {
        guard let selectedIndex = ZodiacSign.allCases.firstIndex(of: selectedSign),
              let signIndex = ZodiacSign.allCases.firstIndex(of: sign) else { return 3 }
        return abs(selectedIndex - signIndex)
    }

    private func circleSize(distance: Int) -> CGFloat {
        switch distance {
        case 0: return 56
        case 1: return 44
        default: return 36
        }
    }

    private func opacityForDistance(_ distance: Int) -> Double {
        switch distance {
        case 0: return 1.0
        case 1: return 0.6
        default: return 0.3
        }
    }
}
