import SwiftUI

// MARK: - Choose / switch primary

struct PrimaryCompanionChooserView: View {
    @Bindable var viewModel: AppViewModel
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pendingSelection: CompanionPersona?
    @State private var profilePreview: CompanionPersona?

    private var recommendations: [CompanionPersona] {
        viewModel.recommendedCompanionPersonas
    }

    private var remaining: [CompanionPersona] {
        CompanionPersonaRegistry.pilot.filter { persona in
            !Set(recommendations.map(\.id)).contains(persona.id)
        }
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    chooserHeader

                    companionSection(title: "RECOMMENDED FOR YOUR CHART", personas: recommendations)

                    if !remaining.isEmpty {
                        companionSection(title: "ALSO PILOT-CERTIFIED", personas: remaining)
                    }

                    Text("You are choosing one primary AI companion. Switching later keeps every relationship and history separate; nothing is merged or deleted.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Choose companion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            switchConfirmationTitle,
            isPresented: Binding(
                get: { pendingSelection != nil },
                set: { if !$0 { pendingSelection = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingSelection {
                Button(viewModel.primaryCompanionPersona == nil ? "Choose \(pendingSelection.displayName)" : "Switch to \(pendingSelection.displayName)") {
                    completeSelection(pendingSelection)
                }
            }
            Button("Cancel", role: .cancel) { pendingSelection = nil }
        } message: {
            Text(switchConfirmationMessage)
        }
        .sheet(item: $profilePreview) { persona in
            CompanionIdentityPreview(persona: persona) {
                profilePreview = nil
                pendingSelection = persona
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("companion.chooser.screen")
    }

    private var chooserHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.primaryCompanionPersona == nil ? "Choose your primary companion" : "Choose who supports you")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.offWhite)

            Text("Four companions are certified for this closed pilot. Your chart shapes the recommendations; the choice stays yours.")
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func companionSection(title: String, personas: [CompanionPersona]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)

            ForEach(personas) { persona in
                companionCard(persona)
            }
        }
    }

    private func companionCard(_ persona: CompanionPersona) -> some View {
        HStack(spacing: 14) {
            Button {
                profilePreview = persona
            } label: {
                Image(persona.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 96, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(persona.sign.color.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Preview \(persona.displayName)")

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(persona.displayName)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("AI")
                        .font(SimastryFont.microSemibold)
                        .foregroundStyle(SimastryColor.midnight)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(SimastryColor.gold, in: Capsule())
                    ZodiacIconView(sign: persona.sign, size: 18, showsGlow: false)
                }

                Text(persona.supportPromise)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticManager.buttonPress()
                    if viewModel.primaryCompanionRelationship?.companionId == persona.id {
                        return
                    }
                    pendingSelection = persona
                } label: {
                    Text(viewModel.primaryCompanionRelationship?.companionId == persona.id ? "Primary" : "Choose \(persona.displayName)")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(viewModel.primaryCompanionRelationship?.companionId == persona.id ? SimastryColor.gold : SimastryColor.midnight)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            viewModel.primaryCompanionRelationship?.companionId == persona.id
                                ? AnyShapeStyle(SimastryColor.gold.opacity(0.12))
                                : AnyShapeStyle(SimastryGradient.gold),
                            in: Capsule()
                        )
                }
                .buttonStyle(SpringPressStyle())
                .disabled(viewModel.primaryCompanionRelationship?.companionId == persona.id)
                .accessibilityIdentifier("companion.chooser.choose.\(persona.id.rawValue)")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .surfaceCard(cornerRadius: 22, accent: persona.sign.color.opacity(0.55))
    }

    private var switchConfirmationTitle: String {
        guard let pendingSelection else { return "Choose companion?" }
        return viewModel.primaryCompanionPersona == nil
            ? "Choose \(pendingSelection.displayName)?"
            : "Switch primary companion?"
    }

    private var switchConfirmationMessage: String {
        guard let pendingSelection else { return "" }
        if let current = viewModel.primaryCompanionPersona {
            return "\(pendingSelection.displayName) will become primary. Your history with \(current.displayName) stays separate and intact."
        }
        return "\(pendingSelection.displayName) will be the one companion pinned across Home and Talk."
    }

    private func completeSelection(_ persona: CompanionPersona) {
        viewModel.choosePrimaryCompanion(persona.id)
        pendingSelection = nil
        onComplete?()
        dismiss()
    }
}

private struct CompanionIdentityPreview: View {
    let persona: CompanionPersona
    let choose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(persona.cardImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 330)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    HStack(spacing: 8) {
                        Text(persona.displayName)
                            .font(SimastryFont.displayMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("AI companion")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.gold)
                    }

                    Text(persona.headline)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(persona.supportPromise)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)

                    Text("\(persona.sign.displayName) shapes the voice—not a claim to read minds or predict another person's choices.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("IDENTITY GALLERY")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.textSecondary)
                            .tracking(1.2)
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { index in
                                Image("Factory_\(persona.id.rawValue)_post\(index)")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.82, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }

                    GoldButton("Choose \(persona.displayName)") { choose() }
                }
                .padding(20)
            }
            .background { CelestialBackground() }
            .navigationTitle("Companion profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Focused Home

struct CompanionHomeView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showChooser = false
    @State private var outcomePerson: RelationshipPerson?
    @State private var transitReading: DailyTransitReading?

    private var recentPerson: RelationshipPerson? {
        viewModel.relationshipPeople.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                primaryCard
                compassCard

                if let outcome = viewModel.pendingCommunicationOutcomes.first {
                    followUpCard(outcome)
                }

                realPersonCard
                focusedActions
                Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background { CelestialBackground() }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppTabFloatingHeader(viewModel: viewModel) {
                HomeHeaderGreetingSummary()
            }
        }
        .sheet(isPresented: $showChooser) {
            NavigationStack {
                PrimaryCompanionChooserView(viewModel: viewModel) {
                    showChooser = false
                }
            }
        }
        .sheet(item: $outcomePerson) { person in
            CommunicationOutcomeSheet(viewModel: viewModel, person: person)
        }
        .task(id: compassContextKey) {
            transitReading = await TransitEngine.dailyReading(
                sun: viewModel.userSunSign,
                moon: viewModel.userMoonSign,
                rising: viewModel.userRisingSign
            )
        }
        .accessibilityIdentifier("companion.home.screen")
    }

    @ViewBuilder
    private var primaryCard: some View {
        if let persona = viewModel.primaryCompanionPersona {
            HStack(spacing: 15) {
                Image(persona.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 112, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR PRIMARY AI COMPANION")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.gold)
                        .tracking(1.2)
                    Text(persona.displayName)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(persona.supportPromise)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Talk") { viewModel.openPrimaryCompanion() }
                            .buttonStyle(SimastryPrimaryButtonStyle())
                            .accessibilityIdentifier("companion.home.talk")
                        Button("Switch") { showChooser = true }
                            .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.offWhite.opacity(0.18)))
                            .accessibilityIdentifier("companion.home.switch")
                    }
                }
            }
            .padding(16)
            .surfaceCard(cornerRadius: 26, accent: persona.sign.color.opacity(0.65))
        }
    }

    private var compassCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Today's Compass", systemImage: "location.north.circle.fill")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.gold)

            Text(compassLine)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Compass") { viewModel.openPredict() }
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.gold)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.celestialBlue.opacity(0.55))
    }

    private var compassLine: String {
        if let transitReading {
            return "\(transitReading.headline): \(transitReading.guidance)"
        }
        let moon = viewModel.userMoonSign?.displayName ?? "your emotional rhythm"
        return "Let your \(moon) context inform the tone, then choose one action the other person can actually respond to."
    }

    private var compassContextKey: String {
        [viewModel.userSunSign, viewModel.userMoonSign, viewModel.userRisingSign]
            .map { $0?.rawValue ?? "unknown" }
            .joined(separator: "|")
    }

    @ViewBuilder
    private var realPersonCard: some View {
        if let person = recentPerson {
            VStack(alignment: .leading, spacing: 10) {
                Text("ONE REAL-WORLD ACTION")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.2)
                Text("With \(person.displayName)")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(viewModel.relationshipReading(for: person).communicationStyle)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("Open person") {
                        viewModel.selectedTab = .people
                        viewModel.peopleDetailRequestPersonId = person.id
                    }
                    .buttonStyle(SimastryPrimaryButtonStyle())

                    Button("Record outcome") { outcomePerson = person }
                        .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.offWhite.opacity(0.18)))
                }
            }
            .padding(16)
            .surfaceCard(cornerRadius: 22, accent: person.sunSign.color.opacity(0.55))
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Text("Bring in a real person")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Add someone privately so your companion can help you prepare for the conversations that matter.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                Button("Open People") { viewModel.selectedTab = .people }
                    .buttonStyle(SimastryPrimaryButtonStyle())
            }
            .padding(16)
            .surfaceCard(cornerRadius: 22)
        }
    }

    private var focusedActions: some View {
        HStack(spacing: 10) {
            companionAction(title: "Decode", icon: "text.magnifyingglass") {
                viewModel.selectedTab = .today
                viewModel.decodeRouteRequest += 1
            }
            companionAction(title: "Rehearse", icon: "theatermasks.fill") {
                viewModel.openPractice()
            }
            companionAction(title: "People", icon: "person.2.fill") {
                viewModel.selectedTab = .people
            }
        }
    }

    private func companionAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title).font(SimastryFont.labelMedium)
            }
            .foregroundStyle(SimastryColor.offWhite)
            .frame(maxWidth: .infinity, minHeight: 72)
                .interactiveGlass(cornerRadius: 18, tint: SimastryColor.offWhite.opacity(0.18))
        }
        .buttonStyle(SpringPressStyle())
    }

    private func followUpCard(_ outcome: CommunicationOutcome) -> some View {
        let person = viewModel.relationshipPeople.first { $0.id == outcome.personId }
        let name = person?.displayName ?? "that conversation"
        return VStack(alignment: .leading, spacing: 9) {
            Text("FOLLOW-UP · RECORDED BY YOU")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1.2)
            Text("You marked \(name) as \(outcome.result.title.lowercased()). Want to reflect on what to keep or change?")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Talk it through") {
                    viewModel.resolveCommunicationOutcome(outcome.id, state: .acknowledged)
                    viewModel.openPrimaryCompanion()
                }
                .buttonStyle(SimastryPrimaryButtonStyle())
                Button("Dismiss") {
                    viewModel.resolveCommunicationOutcome(outcome.id, state: .dismissed)
                }
                .buttonStyle(SimastryAccentButtonStyle(accent: SimastryColor.offWhite.opacity(0.18)))
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.5))
    }
}

// MARK: - Primary Talk

struct PrimaryCompanionTalkView: View {
    @Bindable var viewModel: AppViewModel
    @State private var draft = ""
    @State private var streamedText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showChooser = false
    @State private var showSupport = false
    @State private var showMemories = false
    @State private var showRehearsal = false
    @State private var handledPracticeRouteRequest = 0
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var conversation: CompanionConversation? {
        viewModel.primaryCompanionConversation()
    }

    private var messages: [CompanionChatMessage] {
        guard let conversation else { return [] }
        return viewModel.companionChatMessages(conversationId: conversation.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.primaryCompanionPersona == nil {
                    PrimaryCompanionChooserView(viewModel: viewModel)
                } else {
                    chatBody
                }
            }
            .background { CelestialBackground() }
            .safeAreaInset(edge: .top, spacing: 0) { talkHeader }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showChooser) {
            NavigationStack {
                PrimaryCompanionChooserView(viewModel: viewModel) { showChooser = false }
            }
        }
        .sheet(isPresented: $showSupport) {
            CompanionSupportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showMemories) {
            CompanionMemoryControlsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showRehearsal) {
            RehearsalRoomView(viewModel: viewModel)
        }
        .onAppear {
            if draft.isEmpty, let pending = viewModel.primaryCompanionDraft {
                draft = pending
                viewModel.primaryCompanionDraft = nil
            }
            presentRehearsalIfRequested()
        }
        .onChange(of: viewModel.practiceRouteRequest) {
            presentRehearsalIfRequested()
        }
        .accessibilityIdentifier("companion.talk.screen")
    }

    private var chatBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    disclosure
                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    if isSending {
                        streamingBubble
                            .id("streaming")
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(SimastryFont.caption)
                            .foregroundStyle(SimastryColor.amber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(reduceMotion ? nil : .spring(SimastrySpring.smooth)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: streamedText) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private var talkHeader: some View {
        if let persona = viewModel.primaryCompanionPersona {
            HStack(spacing: 12) {
                Image(persona.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46, alignment: .top)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(persona.sign.color.opacity(0.6), lineWidth: 1) }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(SimastryFont.titleSmall)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("AI")
                            .font(SimastryFont.microSemibold)
                            .foregroundStyle(SimastryColor.gold)
                    }
                    Text("Primary companion · \(persona.sign.displayName) lens")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()

                Menu {
                    Button("How \(persona.displayName) supports you") { showSupport = true }
                    Button("Memory controls") { showMemories = true }
                    Button("Switch primary companion") { showChooser = true }
                } label: {
                    HeaderActionIcon(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Companion and memory options")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .simastryToolbarGlass()
        }
    }

    private var disclosure: some View {
        Text("\(viewModel.primaryCompanionPersona?.displayName ?? "Your companion") is an AI ally for real-life conversations—not a person, therapist, or replacement for human support.")
            .font(SimastryFont.captionSmall)
            .foregroundStyle(SimastryColor.textTertiary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(SimastryColor.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func messageBubble(_ message: CompanionChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 54) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user ? SimastryColor.gold.opacity(0.2) : Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                if message.modelVersion == "offline-fallback-v1" {
                    Text("OFFLINE FALLBACK")
                        .font(SimastryFont.microSemibold)
                        .foregroundStyle(SimastryColor.textTertiary)
                }
            }
            if message.role == .assistant { Spacer(minLength: 54) }
        }
        .frame(maxWidth: .infinity)
    }

    private var streamingBubble: some View {
        HStack {
            if streamedText.isEmpty {
                TypingDotsBubble { EmptyView() }
            } else {
                Text(streamedText)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Spacer(minLength: 54)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var composer: some View {
        if viewModel.primaryCompanionPersona != nil {
            HStack(spacing: 10) {
                TextField("Discuss a person or conversation…", text: $draft, axis: .vertical)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .focused($composerFocused)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? SimastryColor.midnight : SimastryColor.mutedSilver)
                        .frame(width: 38, height: 38)
                        .background(canSend ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.08)), in: Circle())
                }
                .disabled(!canSend)
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Send to primary companion")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .simastryToolbarGlass()
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, let conversation, let persona = viewModel.primaryCompanionPersona else { return }
        let privacy = ConversationPrivacyService().prepare(text)
        guard privacy.canProceed else {
            errorMessage = privacy.blockingMessage ?? "Please remove private contact details before sending."
            return
        }

        let clientMessageId = UUID()
        draft = ""
        errorMessage = nil
        isSending = true
        streamedText = ""
        viewModel.appendCompanionUserMessage(
            privacy.redactedText,
            conversationId: conversation.id,
            clientMessageId: clientMessageId
        )

        Task {
            do {
                // A newly chosen primary can reach Talk before the background
                // mirror finishes. Establish the owner-scoped relationship
                // first so the server never mistakes that harmless race for a
                // spoofed/non-primary companion request.
                try await viewModel.syncCompanionPilotDataNow(includePrivateRecords: false)
                let stream = viewModel.streamPrimaryCompanionReply(
                    companionId: persona.id,
                    conversationId: conversation.id,
                    clientMessageId: clientMessageId,
                    message: privacy.redactedText
                )
                var completedText = ""
                for try await event in stream {
                    switch event {
                    case .meta:
                        break
                    case .delta(let text):
                        streamedText += text
                    case .done(let text, _):
                        completedText = text.isEmpty ? streamedText : text
                    case .error(_, let message):
                        throw SupabaseServiceError.functionFailed(message)
                    }
                }
                let final = completedText.isEmpty ? streamedText : completedText
                if final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw SupabaseServiceError.invalidFunctionResponse
                }
                viewModel.appendCompanionAssistantMessage(
                    final,
                    conversationId: conversation.id,
                    clientMessageId: clientMessageId
                )
            } catch {
                let fallback = viewModel.primaryCompanionOfflineFallback(for: privacy.redactedText, persona: persona)
                viewModel.analytics.track(.companionTalkOfflineFallback)
                viewModel.appendCompanionAssistantMessage(
                    fallback,
                    conversationId: conversation.id,
                    clientMessageId: clientMessageId,
                    modelVersion: "offline-fallback-v1"
                )
                errorMessage = "Live guidance was unavailable, so this reply used the labeled on-device fallback."
            }
            streamedText = ""
            isSending = false
        }
    }

    private func presentRehearsalIfRequested() {
        guard viewModel.practiceRouteRequest > handledPracticeRouteRequest else { return }
        handledPracticeRouteRequest = viewModel.practiceRouteRequest
        showRehearsal = true
    }
}

// MARK: - Support and memory controls

struct CompanionSupportSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: CompanionSupportPreferences
    @State private var newTopic = ""

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _preferences = State(initialValue: viewModel.primaryCompanionRelationship?.preferences ?? .init())
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tone", selection: $preferences.tone) {
                    ForEach(CompanionSupportTone.allCases) { Text($0.title).tag($0) }
                }
                Picker("Directness", selection: $preferences.directness) {
                    ForEach(CompanionSupportDirectness.allCases) { Text($0.title).tag($0) }
                }
                Picker("Length", selection: $preferences.length) {
                    ForEach(CompanionSupportLength.allCases) { Text($0.title).tag($0) }
                }

                Section("Topics") {
                    ForEach(preferences.topics, id: \.self) { topic in
                        Text(topic)
                    }
                    .onDelete { preferences.topics.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add a topic", text: $newTopic)
                        Button("Add") { addTopic() }
                            .disabled(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    Text("These choices tune presentation only. They never create romance, exclusivity, intimacy levels, or hidden personality claims.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background { CelestialBackground() }
            .navigationTitle("How \(viewModel.primaryCompanionPersona?.displayName ?? "your companion") supports you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updatePrimaryCompanionSupport(preferences)
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTopic() {
        let topic = String(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !topic.isEmpty, !preferences.topics.contains(topic), preferences.topics.count < 8 else { return }
        preferences.topics.append(topic)
        newTopic = ""
    }
}

struct CompanionMemoryControlsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newMemory = ""
    @State private var editingMemory: CompanionMemoryItem?
    @State private var editText = ""

    private var visibleMemories: [CompanionMemoryItem] {
        let primaryId = viewModel.primaryCompanionRelationship?.companionId
        return viewModel.companionPivotState.memories
            .filter { $0.scope == .sharedUserFact || $0.companionId == primaryId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Only things you save or outcomes you record appear here. Simastry never claims to know what happened offline.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Add a memory") {
                    TextField("What should your companion remember?", text: $newMemory, axis: .vertical)
                    Button("Save memory") {
                        viewModel.addCompanionMemory(content: newMemory, scope: .sharedUserFact)
                        newMemory = ""
                    }
                    .disabled(newMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Saved memory") {
                    if visibleMemories.isEmpty {
                        Text("No saved memory yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visibleMemories) { memory in
                        Button {
                            editingMemory = memory
                            editText = memory.content
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memory.content)
                                    .foregroundStyle(SimastryColor.offWhite)
                                Text(memory.source == .recordedOutcome ? "Recorded outcome" : "Saved by you")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteCompanionMemory(id: memory.id)
                            }
                        }
                    }
                }

                Section("Recorded outcomes") {
                    if recordedOutcomes.isEmpty {
                        Text("No offline outcomes recorded yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recordedOutcomes) { outcome in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(outcome.intendedAction)
                                .foregroundStyle(SimastryColor.offWhite)
                            Text("\(outcome.result.title) · \(outcome.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteCommunicationOutcome(id: outcome.id)
                            }
                        }
                    }
                }

                Section("Private People sync") {
                    Toggle(
                        "Sync People and companion data",
                        isOn: Binding(
                            get: { viewModel.companionPivotState.syncConsent },
                            set: { enabled in
                                if enabled {
                                    viewModel.grantCompanionSyncConsentAndMigrateLegacyData()
                                } else {
                                    viewModel.revokeCompanionSyncConsent()
                                }
                            }
                        )
                    )
                    Text(viewModel.companionPivotState.syncConsent
                        ? "Turning sync off stops future private uploads on this device. Already-synced records remain available to your companion until you delete the People record, memory, outcome, or account."
                        : "Turning this on starts an idempotent, exact-ID migration. Turning it off stops future uploads but does not erase or stop use of records already synced. Custom legacy companions remain read-only and are never matched by name or sign.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background { CelestialBackground() }
            .navigationTitle("Memory controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Edit memory", isPresented: Binding(
                get: { editingMemory != nil },
                set: { if !$0 { editingMemory = nil } }
            )) {
                TextField("Memory", text: $editText)
                Button("Save") {
                    if let editingMemory {
                        viewModel.updateCompanionMemory(id: editingMemory.id, content: editText)
                    }
                    editingMemory = nil
                }
                Button("Cancel", role: .cancel) { editingMemory = nil }
            }
        }
    }

    private var recordedOutcomes: [CommunicationOutcome] {
        viewModel.companionPivotState.outcomes.sorted { $0.createdAt > $1.createdAt }
    }
}

struct LegacyCompanionArchiveView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List {
            Section {
                Text("These are unmatched device-local records from the previous companion experience. They are read-only and were not mapped to a new identity by name or zodiac sign.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.companionPivotState.legacyRecords) { record in
                Section {
                    let messages = archivedMessages(for: record.id)
                    if messages.isEmpty {
                        Text("No local messages remain for this record.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.direction == .outgoing ? "You" : record.originalName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SimastryColor.gold)
                                Text(message.content)
                                    .foregroundStyle(SimastryColor.offWhite)
                                    .textSelection(.enabled)
                                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(record.originalName) · \(record.originalSign)")
                } footer: {
                    Text("Local read-only record")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { CelestialBackground() }
        .navigationTitle("Previous companions")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("legacyCompanions.archive")
    }

    private func archivedMessages(for companionId: UUID) -> [CompanionMessage] {
        viewModel.companionMessages
            .filter { $0.companionId == companionId }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Explicit offline outcome

struct CommunicationOutcomeSheet: View {
    @Bindable var viewModel: AppViewModel
    let person: RelationshipPerson
    @Environment(\.dismiss) private var dismiss
    @State private var action = ""
    @State private var result: CommunicationOutcomeResult = .asExpected
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What you did offline") {
                    TextField("The message, boundary, or conversation", text: $action, axis: .vertical)
                }
                Section("What happened") {
                    Picker("Result", selection: $result) {
                        ForEach(CommunicationOutcomeResult.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Optional note in your own words", text: $notes, axis: .vertical)
                }
                Section {
                    Text("Your companion can follow up only from this record. It will not infer an outcome from silence, location, or private messages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background { CelestialBackground() }
            .navigationTitle("Outcome with \(person.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.recordCommunicationOutcome(
                            person: person,
                            intendedAction: action,
                            result: result,
                            notes: notes
                        )
                        dismiss()
                    }
                    .disabled(action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
