import SwiftUI

/// The Rehearsal Room: practice a conversation with a stand-in shaped by what
/// you've saved about someone, while a chosen expert coaches your side.
/// Always labeled as rehearsal — never the real person. Sessions stay local.
struct RehearsalRoomView: View {
    @Bindable var viewModel: AppViewModel
    var prefilledPerson: RelationshipPerson?

    @Environment(\.dismiss) private var dismiss

    // Setup
    @State private var selectedPersonId: UUID?
    @State private var manualName: String = ""
    @State private var manualSun: ZodiacSign?
    @State private var goal: String = ""
    @State private var coachSpecialistId: String = ""

    // Session
    @State private var session: RehearsalSession?
    @State private var draft: String = ""
    @State private var isPartnerTyping = false
    @State private var isCoachThinking = false
    @State private var inlineError: String?

    // Someone-new: describe-and-go, bypasses goal/coach setup entirely.
    @State private var practiceRoomModal: PracticeRoomModal?

    var body: some View {
        NavigationStack {
            Group {
                if session == nil {
                    setupStage
                } else {
                    chatStage
                }
            }
            .background { CelestialBackground() }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(session == nil ? "Close" : "End") {
                        endOrClose()
                    }
                    .tint(SimastryColor.gold)
                    .accessibilityIdentifier("rehearsal.end")
                }
            }
        }
        .presentationBackground { CelestialBackground() }
        .onAppear {
            if coachSpecialistId.isEmpty {
                coachSpecialistId = viewModel.dailyNoteSpecialist?.id ?? "leyla-western"
            }
            if let prefilledPerson, selectedPersonId == nil {
                selectedPersonId = prefilledPerson.id
            }
        }
        .accessibilityIdentifier("rehearsal.screen")
        .sheet(item: $practiceRoomModal) { modal in
            switch modal {
            case .newPerson:
                PracticeNewPersonForm(viewModel: viewModel) { person in
                    practiceRoomModal = .chat(person)
                }
            case .chat(let person):
                PracticeChatView(viewModel: viewModel, person: person)
            }
        }
    }

    // MARK: - Setup

    private var setupStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                disclosureBanner

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Who are you talking to?")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            someoneNewChip
                            ForEach(viewModel.relationshipPeople) { person in
                                personChip(person)
                            }
                            manualChip
                        }
                        .padding(.vertical, 1)
                    }

                    if selectedPersonId == nil {
                        TextField("Their name or nickname", text: $manualName)
                            .font(SimastryFont.bodyMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(12)
                            .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 14))
                            .accessibilityIdentifier("rehearsal.nameField")

                        Menu {
                            Button("No sign — keep it neutral") { manualSun = nil }
                            ForEach(ZodiacSign.allCases, id: \.self) { sign in
                                Button(sign.displayName) { manualSun = sign }
                            }
                        } label: {
                            HStack {
                                Text(manualSun.map { "Sun: \($0.displayName)" } ?? "Their Sun sign (optional)")
                                    .font(SimastryFont.labelMedium)
                                    .foregroundStyle(SimastryColor.offWhite)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(SimastryFont.captionSmall)
                                    .foregroundStyle(SimastryColor.mutedSilver)
                            }
                            .padding(12)
                            .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
                .surfaceCard(cornerRadius: 20)

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("What's the goal?")
                    TextField("e.g. Ask for space without a fight", text: $goal, axis: .vertical)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 14))
                        .accessibilityIdentifier("rehearsal.goalField")
                }
                .padding(16)
                .surfaceCard(cornerRadius: 20)

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Who coaches you?")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ExpertAstrologerRegistry.specialists) { specialist in
                                coachChip(specialist)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    Text("Your coach critiques your drafts — never scripts to control the other person.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.deepMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .surfaceCard(cornerRadius: 20)

            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                startSession()
            } label: {
                Label("Start rehearsing", systemImage: "theatermasks.fill")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(SimastryGradient.gold, in: Capsule())
            }
            .buttonStyle(SpringPressStyle())
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.55)
            .accessibilityIdentifier("rehearsal.start")
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .lockHorizontalScroll()
    }

    private var canStart: Bool {
        let hasSubject = selectedPersonId != nil
            || !manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasSubject && !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func personChip(_ person: RelationshipPerson) -> some View {
        Button {
            HapticManager.buttonPress()
            selectedPersonId = person.id
        } label: {
            Label(person.displayName, systemImage: "person.text.rectangle")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(selectedPersonId == person.id ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .modifier(RehearsalChipBackground(isSelected: selectedPersonId == person.id))
        }
        .buttonStyle(.plain)
    }

    /// Leading option: build a fuller persona (signs, MBTI, texting style) and
    /// jump straight into an uncoached practice chat — the old Quick Simulate
    /// flow, now folded into this hub. Distinct from `manualChip` below, which
    /// stays a lightweight inline name for a goal-and-coach rehearsal. The
    /// pill has no subtitle slot, so the destination hint rides inline in
    /// quiet caption type.
    private var someoneNewChip: some View {
        Button {
            HapticManager.buttonPress()
            practiceRoomModal = .newPerson
        } label: {
            HStack(spacing: 6) {
                Label("Someone new", systemImage: "person.crop.circle.badge.plus")
                    .font(SimastryFont.labelMedium)
                Text("Quick chat")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .foregroundStyle(SimastryColor.offWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .modifier(RehearsalChipBackground(isSelected: false))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Someone new. Quick chat.")
        .accessibilityIdentifier("practice.someoneNewButton")
    }

    /// Quick inline entry — just a name (and optional Sun) typed straight
    /// into this screen, for a goal-and-coach rehearsal. Kept separate from
    /// `someoneNewChip`'s richer describe-someone form above. The inline hint
    /// flips to midnight when selected so it stays legible on the gold pill.
    private var manualChip: some View {
        let isSelected = selectedPersonId == nil
        return Button {
            HapticManager.buttonPress()
            selectedPersonId = nil
        } label: {
            HStack(spacing: 6) {
                Label("Type a name", systemImage: "plus")
                    .font(SimastryFont.labelMedium)
                Text("With a coach")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(isSelected ? SimastryColor.midnight.opacity(0.72) : SimastryColor.mutedSilver)
            }
            .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .modifier(RehearsalChipBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Type a name. With a coach.")
    }

    private func coachChip(_ specialist: AstrologySpecialist) -> some View {
        Button {
            HapticManager.buttonPress()
            coachSpecialistId = specialist.id
        } label: {
            HStack(spacing: 7) {
                if let profile = specialist.archivedProfile {
                    Image(profile.profileImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24, alignment: .top)
                        .clipShape(Circle())
                }
                Text(specialist.characterName)
                    .font(SimastryFont.labelMedium)
            }
            .foregroundStyle(coachSpecialistId == specialist.id ? SimastryColor.midnight : SimastryColor.offWhite)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .modifier(RehearsalChipBackground(isSelected: coachSpecialistId == specialist.id))
        }
        .buttonStyle(.plain)
    }

    private func startSession() {
        HapticManager.buttonPress()
        let persona: RehearsalPersona
        if let person = viewModel.relationshipPeople.first(where: { $0.id == selectedPersonId }) {
            persona = RehearsalPersona(
                name: person.displayName,
                relationship: person.relationshipType.rawValue,
                sunSign: person.sunSign.displayName,
                moonSign: person.moonSign?.displayName,
                risingSign: person.risingSign?.displayName,
                notes: person.notes,
                personId: person.id
            )
        } else {
            persona = RehearsalPersona(
                name: manualName.trimmingCharacters(in: .whitespacesAndNewlines),
                sunSign: manualSun?.displayName
            )
        }
        session = RehearsalSession(
            persona: persona,
            goal: goal.trimmingCharacters(in: .whitespacesAndNewlines),
            coachSpecialistId: coachSpecialistId
        )
    }

    // MARK: - Chat

    @ViewBuilder
    private var chatStage: some View {
        if let session {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            disclosureBanner

                            goalCard(session)

                            ForEach(session.messages) { message in
                                messageRow(message, session: session)
                                    .id(message.id)
                            }

                            if isPartnerTyping || isCoachThinking {
                                HStack(spacing: 8) {
                                    ProgressView().tint(SimastryColor.gold).scaleEffect(0.85)
                                    Text(isCoachThinking ? "\(coachName) is looking at your draft…" : "\(session.persona.name) is typing…")
                                        .font(SimastryFont.captionSmall)
                                        .foregroundStyle(SimastryColor.mutedSilver)
                                }
                                .id("rehearsal.typing")
                            }

                            if let inlineError {
                                Text(inlineError)
                                    .font(SimastryFont.caption)
                                    .foregroundStyle(Color.orange.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if session.isAtTurnLimit {
                                Text("This rehearsal has reached its length. Take what worked into the real conversation.")
                                    .font(SimastryFont.caption)
                                    .foregroundStyle(SimastryColor.goldLight)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SimastryColor.gold.opacity(0.1), in: .rect(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: session.messages.count) {
                        if let last = session.messages.last {
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                composer(session)
            }
            .lockHorizontalScroll()
        }
    }

    private var coachName: String {
        ExpertAstrologerRegistry.specialist(id: coachSpecialistId)?.characterName ?? "Your coach"
    }

    private var disclosureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
            Text("A rehearsal, not the real person — they'll still surprise you.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simastryGlass(cornerRadius: 14)
    }

    private func goalCard(_ session: RehearsalSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("REHEARSING WITH \(session.persona.name.uppercased())")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.gold)
                .tracking(1.2)
            Text(session.goal)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 16)
    }

    @ViewBuilder
    private func messageRow(_ message: RehearsalChatMessage, session: RehearsalSession) -> some View {
        switch message.role {
        case .coach:
            VStack(alignment: .leading, spacing: 5) {
                Label("\(coachName)'s note", systemImage: "graduationcap.fill")
                    .font(SimastryFont.captionSmall.weight(.bold))
                    .foregroundStyle(SimastryColor.gold)
                Text(message.content)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.92))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 16, accent: SimastryColor.gold.opacity(0.5))
        case .user, .partner:
            let isUser = message.role == .user
            HStack {
                if isUser { Spacer(minLength: 48) }
                Text(message.content)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? SimastryColor.gold.opacity(0.26) : SimastryColor.surface.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                if !isUser { Spacer(minLength: 48) }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        }
    }

    private func composer(_ session: RehearsalSession) -> some View {
        HStack(alignment: .bottom, spacing: 9) {
            Button {
                requestCoachNote()
            } label: {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 42, height: 42)
                    .simastryGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .disabled(isCoachThinking || isPartnerTyping || lastUserMessage(session) == nil)
            .accessibilityLabel("Ask \(coachName) to coach your last message")
            .accessibilityIdentifier("rehearsal.coach")

            TextField("Say it like you would…", text: $draft, axis: .vertical)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(1...4)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(SimastryColor.surfaceSunken.opacity(0.55), in: .rect(cornerRadius: 17))
                .accessibilityIdentifier("rehearsal.input")

            Button {
                sendDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .frame(width: 42, height: 42)
                    .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .disabled(
                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isPartnerTyping
                    || session.isAtTurnLimit
            )
            .accessibilityIdentifier("rehearsal.send")
        }
        .padding(.horizontal, 13)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func lastUserMessage(_ session: RehearsalSession) -> RehearsalChatMessage? {
        session.messages.last(where: { $0.role == .user })
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(SimastryFont.labelLarge)
            .foregroundStyle(SimastryColor.offWhite)
    }

    // MARK: - Actions

    private func sendDraft() {
        guard var current = session else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        HapticManager.buttonPress()
        draft = ""
        inlineError = nil
        current.messages.append(RehearsalChatMessage(role: .user, content: text))
        session = current
        persist()

        isPartnerTyping = true
        Task {
            defer { isPartnerTyping = false }
            do {
                let reply = try await viewModel.rehearsalPartnerReply(for: current)
                appendMessage(RehearsalChatMessage(role: .partner, content: reply))
            } catch {
                inlineError = error.localizedDescription
            }
        }
    }

    private func requestCoachNote() {
        guard let current = session else { return }
        HapticManager.buttonPress()
        inlineError = nil
        isCoachThinking = true
        Task {
            defer { isCoachThinking = false }
            do {
                let note = try await viewModel.rehearsalCoachNote(for: current)
                appendMessage(RehearsalChatMessage(role: .coach, content: note))
            } catch {
                inlineError = error.localizedDescription
            }
        }
    }

    private func appendMessage(_ message: RehearsalChatMessage) {
        guard var current = session else { return }
        current.messages.append(message)
        session = current
        persist()
    }

    private func persist() {
        if let session {
            RehearsalSessionStore.save(session)
        }
    }

    private func endOrClose() {
        HapticManager.buttonPress()
        persist()
        dismiss()
    }
}

/// Selected chips keep the gold gradient; unselected ones sit on the same
/// Liquid Glass pill material as the rest of the app.
private struct RehearsalChipBackground: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.background(SimastryGradient.gold, in: Capsule())
        } else {
            content.simastryGlassPill()
        }
    }
}

// MARK: - Someone New

/// Routes the "Someone new" path: describe a persona, then hand off to a
/// simple practice chat — distinct from the goal-and-coach `RehearsalSession`
/// flow the rest of this screen runs. A single `Identifiable` item (rather
/// than two independent booleans) lets SwiftUI swap the sheet's content
/// directly instead of dismissing and re-presenting.
private enum PracticeRoomModal: Identifiable {
    case newPerson
    case chat(RelationshipPerson)

    var id: String {
        switch self {
        case .newPerson:
            "newPerson"
        case .chat(let person):
            "chat-\(person.id.uuidString)"
        }
    }
}

/// The describe-someone form for a persona you haven't saved yet — ported
/// from the old Quick Simulate sheet. Creates a real `RelationshipPerson` on
/// start, exactly as Quick Simulate did, then hands off to `PracticeChatView`
/// for a simple, uncoached chat (the same component `.practice(person)`
/// presents from Talk and from a person's detail screen).
private struct PracticeNewPersonForm: View {
    @Bindable var viewModel: AppViewModel
    let onStart: (RelationshipPerson) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var sunSign: ZodiacSign = .libra
    @State private var moonSign: ZodiacSign?
    @State private var risingSign: ZodiacSign?
    @State private var personalityType: MBTIPersonalityType?
    @State private var notes: String = ""
    @State private var textingStyles: Set<String> = []
    // Deliberately no name-field autofocus: this form is a sheet nested in
    // the hub's own sheet, and a focused field here computes an invalid hit
    // point (untappable) — reproduced in UI tests at zero delay AND with the
    // house 0.25s asyncAfter idiom. Users tap in.

    private let styleOptions = ["dry", "slow replier", "warm", "flirty"]

    private var canStart: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        identitySection
                        signsSection
                        personalitySection
                        notesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Someone new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(SimastryColor.gold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startSimulation()
                    }
                    .disabled(!canStart)
                    .tint(SimastryColor.gold)
                    .accessibilityIdentifier("practice.new.startButton")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)
                    .frame(width: 36, height: 36)
                    .background(SimastryColor.risingViolet.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulated from signs and notes")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text("Not the real person.")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }

            Text("Start with a name and Sun sign. Personality type and notes make the practice sharper.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.risingViolet.opacity(0.6))
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Who are you simulating?")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.3)

            TextField("Name or nickname", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(SimastryFont.bodyMedium)
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityIdentifier("practice.new.nameField")
        }
    }

    private var signsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signs")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.3)

            VStack(spacing: 9) {
                signSelector(title: "Sun", sign: sunSign, required: true) { selected in
                    if let selected { sunSign = selected }
                }
                signSelector(title: "Moon", sign: moonSign, required: false) { selected in
                    moonSign = selected
                }
                signSelector(title: "Rising", sign: risingSign, required: false) { selected in
                    risingSign = selected
                }
            }
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personality")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.3)

            Menu {
                Button("Unknown") { personalityType = nil }
                ForEach(MBTIPersonalityType.allCases) { type in
                    Button(type.rawValue) {
                        personalityType = type == .notSure ? nil : type
                    }
                }
            } label: {
                selectorRow(
                    title: "Personality type",
                    value: personalityType?.rawValue ?? "Unknown",
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: SimastryColor.gold
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How they text")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(styleOptions, id: \.self) { style in
                        styleChip(style)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.3)

            TextField("Optional context, e.g. guarded, jokes when nervous, hates pressure", text: $notes, axis: .vertical)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(3...6)
                .padding(13)
                .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityIdentifier("practice.new.notesField")
        }
    }

    private func signSelector(
        title: String,
        sign: ZodiacSign?,
        required: Bool,
        onSelect: @escaping (ZodiacSign?) -> Void
    ) -> some View {
        Menu {
            if !required {
                Button("Unknown") { onSelect(nil) }
            }
            ForEach(ZodiacSign.allCases) { option in
                Button(option.displayName) {
                    onSelect(option)
                }
            }
        } label: {
            selectorRow(
                title: title,
                value: sign?.displayName ?? "Unknown",
                systemImage: title == "Sun" ? "sun.max.fill" : (title == "Moon" ? "moon.stars.fill" : "sparkles"),
                tint: sign?.color ?? SimastryColor.deepMuted
            )
        }
    }

    private func selectorRow(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.deepMuted)
                Text(value)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .padding(13)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func styleChip(_ style: String) -> some View {
        let selected = textingStyles.contains(style)

        return Button {
            HapticManager.buttonPress()
            if selected {
                textingStyles.remove(style)
            } else {
                textingStyles.insert(style)
            }
        } label: {
            Text(style.capitalized)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(selected ? SimastryColor.midnight : SimastryColor.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? SimastryColor.gold : Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(SpringPressStyle())
    }

    private func startSimulation() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let person = RelationshipPerson(
            id: UUID(),
            name: trimmedName,
            privateLabel: nil,
            relationshipType: .other,
            birthDate: nil,
            birthTime: nil,
            birthPlace: nil,
            sunSign: sunSign,
            moonSign: moonSign,
            risingSign: risingSign,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            imageData: nil,
            isChartCalculated: false,
            updatedAt: .now,
            personalityType: personalityType,
            textingStyles: textingStyles.isEmpty ? nil : Array(textingStyles).sorted()
        )

        viewModel.addRelationshipPerson(person)
        onStart(person)
    }
}
