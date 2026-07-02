import SwiftUI

/// Onboarding payoff: the user asks one question and hears how all five experts
/// would read it, then saves it by creating an account. Pre-auth this uses the
/// local per-specialist fallback (instant, no backend); the real AI is one tap
/// away once they sign up.
struct FirstExpertReadView: View {
    @Bindable var viewModel: AppViewModel

    @State private var question: String = ""
    @State private var submitted = false
    @State private var consultationId: UUID?

    private let suggestions = ["Love", "Career", "Timing", "Family", "Life direction"]

    private var responses: [SpecialistConsultationResponse] {
        viewModel.everyoneResponses(for: consultationId)
    }

    private var allComplete: Bool {
        let specialists = ExpertAstrologerRegistry.specialists
        guard responses.count >= specialists.count, !responses.isEmpty else { return false }
        return responses.allSatisfy { $0.specialistResponse != nil || $0.errorMessage != nil }
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if submitted {
                        readingSection
                    } else {
                        askSection
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
                .padding(.top, 64)
            }
            .scrollIndicators(.hidden)
            .lockHorizontalScroll()
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("firstExpertRead.screen")
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-SimastryPreviewAutoFirstRead"), !submitted {
                question = "Love"
                submit()
            }
            #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SimastryWordmark(font: .system(.title2, weight: .bold).italic())

            Text(submitted ? "Five traditions, one question" : "Your first reading")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Text(submitted
                 ? "A preview of each expert's lens on your question. Save your chart to unlock the full, personalized readings."
                 : "Ask one thing. Hear how all five experts would read it through their own tradition.")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Ask about love, timing, a relationship, or a decision", text: $question, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(2...5)
                .padding(14)
                .background(SimastryColor.surfaceSunken.opacity(0.5), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 0.7))
                .accessibilityIdentifier("firstExpertRead.questionInput")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        HapticManager.buttonPress()
                        question = suggestion
                    } label: {
                        Text(suggestion)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .simastryGlassPill(interactive: true)
                    }
                    .buttonStyle(SpringPressStyle())
                }
            }

            goldButton(title: "Hear all five experts", systemImage: "sparkles", action: submit)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                .accessibilityIdentifier("firstExpertRead.askButton")
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.5))
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ExpertAstrologerRegistry.specialists) { specialist in
                expertCard(specialist: specialist, response: responses.first { $0.specialistId == specialist.id })
            }

            if allComplete {
                saveCTA
            }
        }
    }

    private func expertCard(specialist: AstrologySpecialist, response: SpecialistConsultationResponse?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                expertAvatar(specialist)
                VStack(alignment: .leading, spacing: 1) {
                    Text(specialist.characterName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(specialist.publicTitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.86))
                }
                Spacer(minLength: 0)
            }

            if let text = response?.specialistResponse {
                Text(text)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if response?.errorMessage != nil {
                Text("Couldn't reach \(specialist.characterName) right now.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            } else {
                HStack(spacing: 8) {
                    ProgressView().tint(SimastryColor.gold).scaleEffect(0.85)
                    Text("Reading…")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.3))
    }

    private func expertAvatar(_ specialist: AstrologySpecialist) -> some View {
        ZStack {
            if let name = specialist.profileImageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle().fill(SimastryColor.surfaceSunken.opacity(0.5)).frame(width: 40, height: 40)
                Image(systemName: specialist.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
            }
        }
        .overlay(Circle().strokeBorder(SimastryColor.gold.opacity(0.4), lineWidth: 0.8))
        .accessibilityHidden(true)
    }

    private var saveCTA: some View {
        VStack(spacing: 12) {
            Text("Create your account to save this reading and ask the experts anything.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            goldButton(title: "Save my reading", systemImage: "arrow.right") {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    viewModel.currentScreen = .signUp
                }
            }
            .accessibilityIdentifier("firstExpertRead.saveButton")
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.5))
        .padding(.top, 4)
    }

    private func goldButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [SimastryColor.goldLight, SimastryColor.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
        }
        .buttonStyle(SpringPressStyle())
    }

    private func submit() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.buttonPress()
        question = trimmed
        // Set the id first so the cards observe each expert filling in.
        let id = UUID()
        consultationId = id
        withAnimation(.spring(SimastrySpring.smooth)) { submitted = true }
        Task {
            await viewModel.startEveryoneConsultation(
                question: trimmed,
                multiConsultationId: id,
                enforceLimit: false
            )
        }
    }
}
