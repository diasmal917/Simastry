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
            .navigationTitle("Rehearsal Room")
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
            }
            .padding(20)
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
                .background(
                    selectedPersonId == person.id
                        ? AnyShapeStyle(SimastryGradient.gold)
                        : AnyShapeStyle(.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var manualChip: some View {
        Button {
            HapticManager.buttonPress()
            selectedPersonId = nil
        } label: {
            Label("Someone new", systemImage: "plus")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(selectedPersonId == nil ? SimastryColor.midnight : SimastryColor.offWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    selectedPersonId == nil
                        ? AnyShapeStyle(SimastryGradient.gold)
                        : AnyShapeStyle(.white.opacity(0.06)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
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
            .background(
                coachSpecialistId == specialist.id
                    ? AnyShapeStyle(SimastryGradient.gold)
                    : AnyShapeStyle(.white.opacity(0.06)),
                in: Capsule()
            )
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
