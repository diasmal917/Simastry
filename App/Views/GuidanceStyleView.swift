import SwiftUI

struct GuidanceStyleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuidanceStyle.storageKey) private var selection = GuidanceStyle.practical.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
                VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
                    Text("Choose how Simastry explains things")
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text("Every style starts with practical guidance. This setting only changes how much astrological context appears.")
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: SimastrySpacing.sm) {
                    ForEach(GuidanceStyle.allCases) { style in
                        guidanceStyleButton(style)
                    }
                }

                Label("You can change this any time.", systemImage: "checkmark.circle.fill")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.textSecondary)
            }
            .padding(SimastrySpacing.lg)
            .padding(.bottom, SimastrySpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("Guidance style")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("guidanceStyle.screen")
    }

    private func guidanceStyleButton(_ style: GuidanceStyle) -> some View {
        let isSelected = style.rawValue == selection

        return Button {
            HapticManager.zodiacSelection()
            withAnimation(reduceMotion ? nil : SimastryMotion.stateChange) {
                selection = style.rawValue
            }
        } label: {
            HStack(alignment: .top, spacing: SimastrySpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(isSelected ? SimastryColor.gold : SimastryColor.textTertiary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(style.title)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.textPrimary)
                    Text(style.summary)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(SimastrySpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentSurface(cornerRadius: SimastryRadius.large, accent: isSelected ? SimastryColor.gold : nil)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(style.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(style.summary)
        .accessibilityIdentifier("guidanceStyle.\(style.rawValue)")
    }
}
