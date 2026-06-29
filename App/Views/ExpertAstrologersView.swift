import SwiftUI

struct ExpertAstrologersView: View {
    @Bindable var viewModel: AppViewModel

    private let initialQuestion: String?
    private let autoRunEveryone: Bool

    @State private var question: String = ""
    @State private var submittedQuestion: String?
    @State private var selectedConsultationId: UUID?
    @State private var isRunningEveryone: Bool = false
    @State private var selectedSpecialistRoute: SpecialistRoute?
    @State private var showingInfoForSpecialist: AstrologySpecialist?
    @State private var didApplyInitialQuestion: Bool = false
    @State private var contextSelection: ExpertContextSelection = .me
    @State private var selectedConversationContext: UserAstrologyContext?

    private let suggestedQuestions = ["Love", "Relationships", "Career", "Family", "Timing", "Life Direction"]

    private var selectedPerson: RelationshipPerson? {
        guard case .person(let id) = contextSelection else { return nil }
        return viewModel.relationshipPeople.first { $0.id == id }
    }

    private var selectedAstrologyContext: UserAstrologyContext {
        switch contextSelection {
        case .me:
            return viewModel.currentAstrologyContext()
        case .general:
            return UserAstrologyContext(
                userName: nil,
                sunSign: nil,
                moonSign: nil,
                risingSign: nil,
                birthDateAvailable: false,
                birthTimeAvailable: false,
                birthPlaceAvailable: false,
                partnerName: nil,
                partnerSunSign: nil,
                partnerMoonSign: nil,
                partnerRisingSign: nil,
                partnerBirthDateAvailable: false,
                partnerBirthTimeAvailable: false,
                partnerBirthPlaceAvailable: false
            )
        case .person:
            return viewModel.currentAstrologyContext(partner: selectedPerson)
        }
    }

    private var contextHelperText: String {
        switch contextSelection {
        case .me:
            return "Uses only your saved chart context."
        case .general:
            return "No saved birth or People context will be attached."
        case .person:
            if let selectedPerson {
                return "Uses your chart plus \(selectedPerson.displayName)'s saved People context."
            }
            return "Choose a saved person before asking about them."
        }
    }

    init(viewModel: AppViewModel, initialQuestion: String? = nil, autoRunEveryone: Bool = false) {
        self.viewModel = viewModel
        self.initialQuestion = initialQuestion
        self.autoRunEveryone = autoRunEveryone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                contextSelector
                questionComposer

                if let submittedQuestion {
                    specialistSelection(question: submittedQuestion)
                }

                Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
        // `.background` (not a full-bleed ZStack layer) so the header insets below
        // the nav bar instead of clipping under it.
        .background { CelestialBackground() }
        .navigationTitle("Expert Astrologers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedSpecialistRoute) { route in
            if let specialist = ExpertAstrologerRegistry.specialist(id: route.id) {
                SpecialistConversationView(
                    viewModel: viewModel,
                    specialist: specialist,
                    initialQuestion: submittedQuestion,
                    context: selectedConversationContext ?? selectedAstrologyContext
                )
            }
        }
        .sheet(item: $showingInfoForSpecialist) { specialist in
            SpecialistInfoSheet(specialist: specialist)
        }
        .onAppear {
            AnalyticsService.shared.track(.expertAstrologersViewed)
            applyInitialQuestionIfNeeded()
        }
        .accessibilityIdentifier("expertAstrologers.screen")
    }

    private var header: some View {
        // Title lives in the nav bar ("Expert Astrologers"); the in-content header
        // leads with the value proposition so the two don't duplicate.
        VStack(alignment: .leading, spacing: 8) {
            Text("Consult one expert — or hear perspectives from all five.")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text("Ask once. Hear five traditions. Choose the insight that resonates.")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.gold.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var questionComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would you like guidance on today?")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            TextField("Ask about love, timing, a relationship, or life direction", text: $question, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(3...5)
                .padding(14)
                .background(SimastryColor.surfaceSunken.opacity(0.42), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.7)
                )
                .accessibilityIdentifier("expertAstrologers.questionInput")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(suggestedQuestions, id: \.self) { chip in
                    Button {
                        HapticManager.buttonPress()
                        question = chip
                        submitQuestion(chip)
                    } label: {
                        Text(chip)
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .simastryGlassPill(interactive: true)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityIdentifier("expertAstrologers.chip.\(chip.replacingOccurrences(of: " ", with: ""))")
                }
            }

            Button {
                HapticManager.buttonPress()
                submitQuestion(question)
            } label: {
                Label("Continue", systemImage: "sparkles")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            .accessibilityIdentifier("expertAstrologers.submitQuestionButton")
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.6))
    }

    private var contextSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Reading context")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.deepMuted)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    contextChip(.me, title: "About me", systemImage: "person.crop.circle")
                    contextChip(.general, title: "General", systemImage: "sparkles")
                    ForEach(viewModel.relationshipPeople) { person in
                        contextChip(.person(person.id), title: person.displayName, systemImage: "person.text.rectangle")
                    }
                }
                .padding(.vertical, 1)
            }

            Text(contextHelperText)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .surfaceCard(cornerRadius: 18)
    }

    private func contextChip(
        _ selection: ExpertContextSelection,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            contextSelection = selection
        } label: {
            Label(title, systemImage: systemImage)
                .font(SimastryFont.labelMedium)
                .foregroundStyle(contextSelection == selection ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    contextSelection == selection
                        ? AnyShapeStyle(SimastryGradient.gold)
                        : AnyShapeStyle(.white.opacity(0.06)),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(.white.opacity(contextSelection == selection ? 0.20 : 0.10), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("expertAstrologers.context.\(selection.accessibilityId)")
    }

    private func specialistSelection(question: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who would you like to hear from?")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Button {
                runEveryone(question: question)
            } label: {
                EveryoneHeroCard(isRunning: isRunningEveryone)
            }
            .buttonStyle(SpringPressStyle())
            .disabled(isRunningEveryone)
            .accessibilityIdentifier("expertAstrologers.everyoneButton")

            everyoneResponses

            ForEach(ExpertAstrologerRegistry.specialists) { specialist in
                SpecialistSelectionRow(
                    specialist: specialist,
                    onOpen: {
                        HapticManager.buttonPress()
                        openSpecialist(specialist, question: question)
                    },
                    onInfo: {
                        showingInfoForSpecialist = specialist
                    }
                )
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private var everyoneResponses: some View {
        let responses = viewModel.everyoneResponses(for: selectedConsultationId)
        if !responses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Everyone")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                ForEach(responses) { response in
                    EveryoneResponseCard(
                        response: response,
                        specialist: ExpertAstrologerRegistry.specialist(id: response.specialistId),
                        isLoading: viewModel.typingSpecialistIds.contains(response.specialistId),
                        onRetry: {
                            retryEveryoneResponse(response)
                        }
                    )
                }
            }
        }
    }

    private func submitQuestion(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submittedQuestion = trimmed
        selectedConsultationId = nil
        let context = selectedAstrologyContext
        AnalyticsService.shared.track(
            .guidanceQuestionSubmitted,
            params: [
                "questionCategory": questionCategory(for: trimmed),
                "mode": "pending",
                "hasBirthData": context.analyticsParams["hasBirthData"] ?? "false",
                "hasPartnerData": context.analyticsParams["hasPartnerData"] ?? "false"
            ]
        )
    }

    private func applyInitialQuestionIfNeeded() {
        guard !didApplyInitialQuestion else { return }
        didApplyInitialQuestion = true
        let pendingQuestion = viewModel.pendingExpertAstrologerQuestion
        let pendingAutoRunEveryone = viewModel.pendingExpertAstrologerAutoRunEveryone
        let pendingSpecialistId = viewModel.pendingExpertAstrologerSpecialistId
        viewModel.pendingExpertAstrologerQuestion = nil
        viewModel.pendingExpertAstrologerAutoRunEveryone = false
        viewModel.pendingExpertAstrologerSpecialistId = nil
        let seed = (initialQuestion ?? pendingQuestion)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seed, !seed.isEmpty {
            question = seed
            submitQuestion(seed)
            if autoRunEveryone || pendingAutoRunEveryone {
                runEveryone(question: seed)
            }
        }
        if let pendingSpecialistId,
           ExpertAstrologerRegistry.specialist(id: pendingSpecialistId) != nil {
            selectedSpecialistRoute = SpecialistRoute(id: pendingSpecialistId)
        }
    }

    private func runEveryone(question: String) {
        guard !isRunningEveryone else { return }
        isRunningEveryone = true
        let consultationId = UUID()
        let context = selectedAstrologyContext
        selectedConsultationId = consultationId
        Task {
            let id = await viewModel.startEveryoneConsultation(
                question: question,
                multiConsultationId: consultationId,
                context: context
            )
            selectedConsultationId = id
            isRunningEveryone = false
        }
    }

    private func retryEveryoneResponse(_ response: SpecialistConsultationResponse) {
        guard !viewModel.typingSpecialistIds.contains(response.specialistId) else { return }
        Task {
            await viewModel.retryEveryoneResponse(response)
        }
    }

    private func openSpecialist(_ specialist: AstrologySpecialist, question: String) {
        let context = selectedAstrologyContext
        selectedConversationContext = context
        AnalyticsService.shared.track(
            .specialistSelected,
            params: [
                "specialistId": specialist.id,
                "mode": "individual",
                "questionCategory": questionCategory(for: question),
                "hasBirthData": context.analyticsParams["hasBirthData"] ?? "false",
                "hasPartnerData": context.analyticsParams["hasPartnerData"] ?? "false"
            ]
        )
        AnalyticsService.shared.track(.individualSpecialistConversationOpened, key: "specialistId", value: specialist.id)
        selectedSpecialistRoute = SpecialistRoute(id: specialist.id)
    }

    private func questionCategory(for value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return suggestedQuestions.map { $0.lowercased() }.first { normalized == $0 || normalized.contains($0) } ?? "custom"
    }
}

private struct SpecialistRoute: Identifiable, Hashable {
    let id: String
}

private enum ExpertContextSelection: Hashable {
    case me
    case general
    case person(UUID)

    var accessibilityId: String {
        switch self {
        case .me:
            return "me"
        case .general:
            return "general"
        case .person(let id):
            return "person.\(id.uuidString)"
        }
    }
}

private struct EveryoneHeroCard: View {
    let isRunning: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("✨")
                .font(.system(size: 34))
                .frame(width: 54, height: 54)
                .background(SimastryColor.gold.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Everyone")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Compare all five traditions side by side.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isRunning {
                ProgressView()
                    .tint(SimastryColor.gold)
            } else {
                Image(systemName: "chevron.right")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold)
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.85))
    }
}

private struct SpecialistSelectionRow: View {
    let specialist: AstrologySpecialist
    let onOpen: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    SpecialistAvatar(specialist: specialist, size: 46, symbolSize: 20)

                    VStack(alignment: .leading, spacing: 5) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(specialist.characterName)
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(1)

                            Text(specialist.publicTitle)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.gold.opacity(0.88))
                                .lineLimit(1)
                        }
                        .minimumScaleFactor(0.82)

                        Text(specialist.shortDescription)
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .padding(.top, 5)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityIdentifier("expertAstrologers.specialist.\(specialist.id)")

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.gold.opacity(0.86))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("How \(specialist.displayName) works")
            .accessibilityIdentifier("expertAstrologers.info.\(specialist.id)")
        }
        .padding(14)
        .surfaceCard(cornerRadius: 18)
    }
}

private struct EveryoneResponseCard: View {
    let response: SpecialistConsultationResponse
    let specialist: AstrologySpecialist?
    let isLoading: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                if let specialist {
                    SpecialistAvatar(specialist: specialist, size: 38, symbolSize: 17)
                } else {
                    Text("✦")
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(specialist?.characterName ?? response.specialistId)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                    Text(specialist?.publicTitle ?? "")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold.opacity(0.86))
                        .lineLimit(1)
                }
                Spacer()
            }

            if isLoading && response.specialistResponse == nil && response.errorMessage == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(SimastryColor.gold)
                    Text("Reading through \(specialist?.characterName ?? "this specialist")'s \(specialist?.publicTitle ?? "tradition")...")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            } else if let error = response.errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onRetry()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .goldGlassPill(interactive: true)
                    }
                    .buttonStyle(SpringPressStyle())
                    .disabled(isLoading)
                    .accessibilityIdentifier("expertAstrologers.retry.\(response.specialistId)")
                }
            } else if let text = response.specialistResponse {
                Text(text)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.35))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("expertAstrologers.response.\(response.specialistId)")
    }
}

private struct SpecialistConversationView: View {
    @Bindable var viewModel: AppViewModel
    let specialist: AstrologySpecialist
    let initialQuestion: String?
    let context: UserAstrologyContext

    @State private var draft: String = ""
    @State private var hasSubmittedInitialQuestion = false

    private var messages: [SpecialistMessage] {
        viewModel.specialistConversation(for: specialist.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        SpecialistHeaderCard(specialist: specialist)

                        ForEach(messages) { message in
                            SpecialistMessageBubble(
                                specialist: specialist,
                                message: message
                            )
                            .id(message.id)
                        }

                        if viewModel.typingSpecialistIds.contains(specialist.id) {
                            HStack {
                                ProgressView()
                                    .tint(SimastryColor.gold)
                                Text("\(specialist.characterName) is reading...")
                                    .font(SimastryFont.caption)
                                    .foregroundStyle(SimastryColor.mutedSilver)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .simastryGlass(cornerRadius: 16)
                            .id("typing")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.hidden)
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            composer
        }
        // `.background` keeps the header card below the nav bar (no ZStack clip).
        .background { CelestialBackground() }
        .navigationTitle(specialist.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            guard !hasSubmittedInitialQuestion,
                  messages.isEmpty,
                  let initialQuestion,
                  !initialQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            hasSubmittedInitialQuestion = true
            await viewModel.submitIndividualSpecialistMessage(
                specialistId: specialist.id,
                question: initialQuestion,
                context: context
            )
        }
        .accessibilityIdentifier("expertAstrologers.conversation.\(specialist.id)")
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask \(specialist.displayName)", text: $draft, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 18))
                .accessibilityIdentifier("expertAstrologers.conversationInput")

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(width: 42, height: 42)
                    .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityIdentifier("expertAstrologers.sendMessageButton")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task {
            await viewModel.submitIndividualSpecialistMessage(
                specialistId: specialist.id,
                question: text,
                context: context
            )
        }
    }
}

private struct SpecialistHeaderCard: View {
    let specialist: AstrologySpecialist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SpecialistProfileHero(specialist: specialist)

            Text(specialist.longDescription)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.45))
    }
}

private struct SpecialistProfileHero: View {
    let specialist: AstrologySpecialist

    private var profile: FactoryCompanionProfile? {
        specialist.archivedProfile
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let profile {
                Image(profile.cardImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 142, alignment: .top)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [SimastryColor.surfaceSunken.opacity(0.7), SimastryColor.midnight.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 142)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.62), SimastryColor.midnight.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 12) {
                SpecialistAvatar(specialist: specialist, size: 62, symbolSize: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(specialist.characterName)
                        .font(SimastryFont.titleMedium)
                        .foregroundStyle(.white)
                    Text(specialist.publicTitle)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.gold.opacity(0.94))
                    if let profile {
                        Text(profile.headline)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(height: 142)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [SimastryColor.gold.opacity(0.36), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }
}

private struct SpecialistMessageBubble: View {
    let specialist: AstrologySpecialist
    let message: SpecialistMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 54)
            } else {
                SpecialistAvatar(specialist: specialist, size: 34, symbolSize: 15)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                if !isUser {
                    Text(specialist.displayName)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.gold)
                }

                Text(message.content)
                    .font(isUser ? SimastryFont.bodySmall : SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message.timestamp.expertRelativeDescription)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.48))
            }
            .padding(.horizontal, isUser ? 12 : 14)
            .padding(.vertical, isUser ? 9 : 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUser ? SimastryColor.gold.opacity(0.26) : SimastryColor.surface.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(isUser ? 0.16 : 0.08), lineWidth: 0.6)
            )

            if !isUser {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct SpecialistAvatar: View {
    let specialist: AstrologySpecialist
    let size: CGFloat
    let symbolSize: CGFloat

    private var profile: FactoryCompanionProfile? {
        specialist.archivedProfile
    }

    var body: some View {
        ZStack {
            if let profile {
                Image(profile.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size, alignment: .top)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(SimastryColor.surfaceSunken.opacity(0.46))

                Image(systemName: specialist.symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold.opacity(0.92))

                Text(specialist.placeholderAvatar)
                    .font(.system(size: max(9, symbolSize * 0.46), weight: .bold, design: .rounded))
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.56))
                    .offset(y: size * 0.23)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            SimastryColor.gold.opacity(0.46),
                            .white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .shadow(color: SimastryColor.gold.opacity(profile == nil ? 0 : 0.18), radius: 10, y: 4)
        .accessibilityHidden(true)
    }
}

private extension Date {
    var expertRelativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return "Just now"
        }
        if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        }
        if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        }
        if interval < 172800 {
            return "Yesterday"
        }
        if interval < 604800 {
            return "\(Int(interval / 86400))d ago"
        }
        return SimastryDateFormatter.compactDate.string(from: self)
    }
}

private struct SpecialistInfoSheet: View {
    let specialist: AstrologySpecialist
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SpecialistHeaderCard(specialist: specialist)
                    infoSection(title: "How this expert works", values: specialist.allowedTechniques)
                    infoSection(title: "Stays away from", values: specialist.forbiddenConcepts)
                    infoSection(title: "Response style", values: specialist.personalityTraits)
                }
                .padding(20)
            }
            .navigationTitle(specialist.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground { CelestialBackground() }
    }

    private func infoSection(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)

            // Wrapping chips fill the card width instead of stacking in a narrow
            // left column with dead space on the right.
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
    }
}
