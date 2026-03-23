import SwiftUI

struct CommunicationGuideView: View {
    let sign: ZodiacSign

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared: Bool = false

    var body: some View {
        if let guide = CommunicationTemplates.guides[sign] {
            VStack(alignment: .leading, spacing: 16) {
                animatedSection(index: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(sign.glyph)
                            .font(SimastryFont.displayMedium)
                            .foregroundStyle(sign.color)
                            .frame(width: 48, height: 48)
                            .background(sign.color.opacity(0.14), in: .rect(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(guide.title)
                                .font(SimastryFont.titleMedium)
                                .foregroundStyle(SimastryColor.offWhite)

                            Text("Communication reference")
                                .font(SimastryFont.caption)
                                .foregroundStyle(SimastryColor.mutedSilver)
                        }
                    }
                }

                animatedSection(index: 1) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Best Approach")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.gold.opacity(0.8))
                            .tracking(1.8)

                        Text(guide.bestApproach)
                            .font(SimastryFont.bodyLarge)
                            .italic()
                            .foregroundStyle(SimastryColor.gold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .goldGlassRect(cornerRadius: 22)
                }

                animatedSection(index: 2) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Tips")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .tracking(1.8)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(guide.tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: index.isMultiple(of: 2) ? "sparkles" : "star.fill")
                                        .font(SimastryFont.labelSmall)
                                        .foregroundStyle(SimastryColor.gold)
                                        .frame(width: 18, height: 18)
                                        .padding(.top, 2)

                                    Text(tip)
                                        .font(SimastryFont.bodyMedium)
                                        .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .simastryGlass(cornerRadius: 22)
                }

                animatedSection(index: 3) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(SimastryColor.sunCoral)

                            Text("What to Avoid")
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(SimastryColor.sunCoral)
                                .tracking(1.4)
                        }

                        Text(guide.avoid)
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .tintedGlass(SimastryColor.sunCoral.opacity(0.16), cornerRadius: 22)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true
            }
        }
    }

    private var entranceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(SimastrySpring.smooth)
    }

    private func animatedSection<Content: View>(index: Double, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .animation(entranceAnimation.delay(reduceMotion ? 0 : index * 0.08), value: hasAppeared)
    }
}
