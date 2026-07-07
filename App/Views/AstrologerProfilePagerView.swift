import SwiftUI

/// Full-screen astrologer profiles you swipe between. Horizontal swipe moves to
/// the next/previous expert; vertical scroll reads that expert's photos, bio,
/// methods, and sample questions. "Ask [name]" jumps straight into a
/// consultation with them.
struct AstrologerProfilePagerView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    private let specialists = ExpertAstrologerRegistry.specialists

    init(viewModel: AppViewModel, startSpecialistId: String?) {
        self.viewModel = viewModel
        let start = ExpertAstrologerRegistry.specialists.firstIndex { $0.id == startSpecialistId } ?? 0
        _index = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .top) {
            SimastryColor.pureBlack.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(specialists.enumerated()), id: \.element.id) { i, specialist in
                    AstrologerProfilePage(specialist: specialist) {
                        ask(specialist)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            topBar
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("astrologerProfilePager.screen")
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                ForEach(specialists.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? SimastryColor.gold : Color.white.opacity(0.3))
                        .frame(width: i == index ? 20 : 7, height: 7)
                        .animation(.spring(SimastrySpring.snappy), value: index)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                HapticManager.buttonPress()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("astrologerProfilePager.close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private func ask(_ specialist: AstrologySpecialist) {
        HapticManager.buttonPress()
        dismiss()
        viewModel.openAIAstrologists(specialistId: specialist.id)
    }
}

private struct AstrologerProfilePage: View {
    let specialist: AstrologySpecialist
    let onAsk: () -> Void

    private var profile: FactoryCompanionProfile? { specialist.archivedProfile }

    /// The portrait that leads the profile — the same photo shown on the Today
    /// carousel card, so tapping a face opens onto that same face.
    private var heroImageName: String? {
        guard let profile else { return nil }
        return profile.profileImageName
    }

    private var galleryImages: [String] {
        []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                if !galleryImages.isEmpty {
                    gallery
                }
                bioSection
                chipSection(title: "Best for", values: specialist.bestForChips)
                chipSection(title: "Methods \(specialist.characterName) uses", values: specialist.allowedTechniques)
                chipSection(title: "Methods \(specialist.characterName) avoids", values: specialist.forbiddenConcepts)
                sampleQuestions
                safetyNote
                Spacer(minLength: 40)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .lockHorizontalScroll()
        .safeAreaInset(edge: .bottom) { askBar }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let heroImageName {
                    Image(heroImageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: [SimastryColor.surfaceSunken, SimastryColor.midnight], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(height: 440)
            .frame(maxWidth: .infinity)
            .clipped()

            // Top scrim keeps the floating page dots + close control legible
            // over a bright portrait.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer(minLength: 0)
            }

            // Bottom scrim anchors the name block against the photo.
            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.95)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(specialist.tradition.uppercased())
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.goldLight)
                        .tracking(1.4)

                    Text(specialist.characterName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text(specialist.publicTitle)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.95))

                    if let headline = profile?.headline, !headline.isEmpty {
                        Text(headline)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                // Floating engraved-glass tradition emblem (kit asset) —
                // each expert's method rendered as a brass-line instrument.
                Image(specialist.emblemImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                    .accessibilityHidden(true)
            }
            .padding(20)
        }
        .frame(height: 440)
        .frame(maxWidth: .infinity)
    }

    private var gallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(galleryImages, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.7)
                        }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(specialist.expertBio)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }

    private func chipSection(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .simastryGlassPill()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private var sampleQuestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask \(specialist.characterName) things like")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(specialist.sampleQuestions, id: \.self) { question in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.gold.opacity(0.85))
                            .padding(.top, 2)
                        Text(question)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private var safetyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Credibility boundary", systemImage: "shield.lefthalf.filled")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.offWhite)
            Text(specialist.safetyNote)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.35))
        .padding(.horizontal, 20)
    }

    private var askBar: some View {
        Button(action: onAsk) {
            Label("Ask \(specialist.characterName)", systemImage: "bubble.left.and.bubble.right.fill")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(colors: [SimastryColor.goldLight, SimastryColor.gold], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .shadow(color: SimastryColor.gold.opacity(0.4), radius: 20, y: 6)
        }
        .buttonStyle(SpringPressStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("astrologerProfilePager.ask.\(specialist.id)")
    }
}
