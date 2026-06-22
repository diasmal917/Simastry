import SwiftUI
import PhotosUI
import UIKit

struct PeopleView: View {
    @Bindable var viewModel: AppViewModel
    @State private var searchText: String = ""
    @State private var selectedType: RelationshipType?
    @State private var isAddingPerson: Bool = false
    @State private var showTeamRead: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var handledTeamReadRouteRequest: Int = 0

    private var filteredPeople: [RelationshipPerson] {
        viewModel.relationshipPeople.filter { person in
            let matchesSearch = searchText.isEmpty
                || person.displayName.localizedCaseInsensitiveContains(searchText)
                || person.sunSign.displayName.localizedCaseInsensitiveContains(searchText)
                || person.relationshipType.rawValue.localizedCaseInsensitiveContains(searchText)
                || (person.personalityType?.rawValue.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesType = selectedType == nil || person.relationshipType == selectedType
            return matchesSearch && matchesType
        }
    }

    private var needsAttentionPerson: RelationshipPerson? {
        viewModel.relationshipPeople.first { person in
            person.relationshipType == .partner || person.relationshipType == .family
        }
    }

    private var recentlyReflectedPeople: [RelationshipPerson] {
        viewModel.relationshipPeople
            .filter { ($0.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                CelestialBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        peopleContextStrip

                        if viewModel.relationshipPeople.count >= 2 {
                            teamReadEntryCard
                        }

                        if let needsAttentionPerson {
                            needsAttentionCard(needsAttentionPerson)
                        }

                        if !recentlyReflectedPeople.isEmpty {
                            recentSection
                        }

                        if filteredPeople.isEmpty {
                            emptyState
                        } else {
                            allPeopleSection
                        }

                        Spacer().frame(height: SimastrySpacing.tabBarClearance + 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search people or signs")
            .toolbar {
                // One trailing group so iOS 26 renders the filter + add controls
                // as a single blended Liquid Glass cluster that morphs together.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter by relationship", selection: $selectedType) {
                            Text("All people").tag(RelationshipType?.none)
                            ForEach(RelationshipType.allCases) { type in
                                Label(type.rawValue, systemImage: type.systemImage)
                                    .tag(Optional(type))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                    }
                    .tint(selectedType == nil ? SimastryColor.mutedSilver : SimastryColor.gold)

                    Button {
                        isAddingPerson = true
                    } label: {
                        Label("Add person", systemImage: "plus")
                    }
                    .tint(SimastryColor.gold)
                }
            }
            .sheet(isPresented: $isAddingPerson) {
                AddRelationshipPersonView(viewModel: viewModel)
            }
            .sheet(isPresented: $showTeamRead) {
                TeamReadView(viewModel: viewModel)
            }
            .navigationDestination(for: RelationshipPerson.self) { person in
                RelationshipPersonDetailView(viewModel: viewModel, person: person)
            }
            .onAppear {
                viewModel.loadRelationshipPeople()
                #if DEBUG
                if viewModel.isDebugPreviewStateActive && viewModel.relationshipPeople.isEmpty {
                    viewModel.relationshipPeople = RelationshipPeopleStore.previewPeople()
                }
                #endif
                presentRoutesIfRequested()
            }
            .onChange(of: viewModel.peopleDetailRequestPersonId) {
                presentRoutesIfRequested()
            }
            .onChange(of: viewModel.teamReadRouteRequest) {
                presentRoutesIfRequested()
            }
        }
    }

    private func presentRoutesIfRequested() {
        if let personId = viewModel.peopleDetailRequestPersonId {
            viewModel.peopleDetailRequestPersonId = nil
            if let person = viewModel.relationshipPeople.first(where: { $0.id == personId }) {
                navigationPath.append(person)
            }
        }
        if viewModel.teamReadRouteRequest > handledTeamReadRouteRequest {
            handledTeamReadRouteRequest = viewModel.teamReadRouteRequest
            showTeamRead = true
        }
    }

    /// Entry to the group communication read — shown once 2+ people exist.
    private var teamReadEntryCard: some View {
        Button {
            HapticManager.buttonPress()
            showTeamRead = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 42, height: 42)
                    .background(SimastryColor.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Read this group")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("How this group communicates — roles, friction, and the play.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold.opacity(0.7))
            }
            .padding(13)
            .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.7))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Read this group. How this group communicates.")
    }

    private var peopleSubtitle: String {
        if let selectedType {
            return selectedType.rawValue
        }
        let count = viewModel.relationshipPeople.count
        return count == 1 ? "1 person" : "\(count) people"
    }

    private var peopleContextStrip: some View {
        HStack(spacing: 13) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 42, height: 42)
                .background(SimastryColor.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous)
                        .stroke(SimastryColor.gold.opacity(0.16), lineWidth: 0.6)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("RELATIONSHIP MEMORY")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.4)

                Text(peopleSubtitle)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(peopleContextSubtitle)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(SimastryColor.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.7)
        }
    }

    private var peopleContextSubtitle: String {
        if let type = CommunicationTypeProfile.make(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            return "\(type.title) • private relationship memory"
        }
        return "Private, manual relationship memory"
    }

    private var allPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("All people", systemImage: "person.2.fill")
            ForEach(filteredPeople) { person in
                NavigationLink(value: person) {
                    relationshipPersonCard(person)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recent reads", systemImage: "bookmark.fill")
            ForEach(recentlyReflectedPeople.prefix(2)) { person in
                NavigationLink(value: person) {
                    relationshipPersonCard(person)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
    }

    private func needsAttentionCard(_ person: RelationshipPerson) -> some View {
        let reading = viewModel.relationshipReading(for: person)
        return NavigationLink(value: person) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.haze.fill")
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                    Text("Best next move")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(1.2)
                        .textCase(.uppercase)
                }

                Text("\(person.displayName) may benefit from \(reading.bestEnergy.lowercased()) today.")
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                (
                    Text("Avoid: ")
                        .font(SimastryFont.caption.weight(.semibold))
                        .foregroundStyle(SimastryColor.gold.opacity(0.85))
                    + Text(reading.whatToAvoid)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .tintedGlass(SimastryColor.gold, cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SimastryColor.gold.opacity(0.16), lineWidth: 0.7)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SpringPressStyle())
    }

    private func relationshipPersonCard(_ person: RelationshipPerson) -> some View {
        let reading = viewModel.relationshipReading(for: person)
        return HStack(spacing: 14) {
            RelationshipAvatarView(person: person, size: 56)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(person.displayName)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Image(systemName: person.relationshipType.systemImage)
                        .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold.opacity(0.82))
                }

                Text(personCardContextLine(for: person))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text(reading.bestEnergy)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            ZodiacIconView(sign: person.sunSign, size: 34, showsGlow: false)
        }
        .padding(16)
        .glossyCard(cornerRadius: SimastryRadius.large)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func personCardContextLine(for person: RelationshipPerson) -> String {
        var parts = [
            person.relationshipType.rawValue,
            "\(person.sunSign.displayName) Sun"
        ]
        if let personalityType = person.personalityType {
            parts.append(personalityType.rawValue)
        }
        return parts.joined(separator: " • ")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: SimastryIconSize.xl, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)

            Text(viewModel.relationshipPeople.isEmpty ? "No people yet" : "No matching people")
                .font(SimastryFont.titleMedium)
                .foregroundStyle(SimastryColor.offWhite)

            Text(viewModel.relationshipPeople.isEmpty
                 ? "Add someone important manually. Simastry never needs your contacts."
                 : "Try a different name, sign, or relationship type.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.buttonPress()
                isAddingPerson = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    Text("Add person")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .goldGlassPill(interactive: true)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Add person")
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glossyCard(cornerRadius: 22)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)
        }
    }
}

struct RelationshipPersonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AppViewModel
    let person: RelationshipPerson
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var localNotes: String = ""
    @State private var privateLabel: String = ""
    @State private var hasSeededEditableFields: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showHowToTalk: Bool = false
    @State private var showCoupleRead: Bool = false
    @State private var showPracticeChat: Bool = false

    private var currentPerson: RelationshipPerson {
        viewModel.relationshipPeople.first { $0.id == person.id } ?? person
    }

    private var reading: RelationshipPersonReading {
        viewModel.relationshipReading(for: currentPerson)
    }

    /// The ongoing saga: what's happening with this person right now. The
    /// app follows the active situation on Today and in panel starters.
    private var situationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("WHAT'S THE SITUATION?")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)

                Spacer()

                if currentPerson.situationStatus != nil {
                    Text("Day \(currentPerson.situationDay())")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.gold)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SituationStatus.allCases) { status in
                        situationChip(status)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if let status = currentPerson.situationStatus,
               let line = AstrologyTemplates.situationLines[status.rawValue]?[currentPerson.sunSign.element.rawValue] {
                Text(line.replacingOccurrences(of: "{n}", with: "\(currentPerson.situationDay())"))
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.gold.opacity(0.5))
        .animation(.spring(SimastrySpring.smooth), value: currentPerson.situationStatus)
    }

    private func situationChip(_ status: SituationStatus) -> some View {
        let isActive = currentPerson.situationStatus == status

        return Button {
            HapticManager.buttonPress()
            var updated = currentPerson
            if isActive {
                updated.situationStatus = nil
                updated.situationUpdatedAt = nil
            } else {
                updated.situationStatus = status
                updated.situationUpdatedAt = Date()
            }
            viewModel.updateRelationshipPerson(updated)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: status.systemImage)
                    .font(SimastryFont.microSemibold)

                Text(status.title)
                    .font(SimastryFont.labelSmall)
            }
            .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.82))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? AnyShapeStyle(SimastryGradient.gold)
                    : AnyShapeStyle(Color.white.opacity(0.06)),
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(
                    isActive ? .white.opacity(0.22) : .white.opacity(0.08),
                    lineWidth: 0.6
                )
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(status.title) situation")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Simulation Room

    /// One surface, three tools: rehearse the conversation, predict the
    /// reply, decode the text — all reading through this person's chart.
    private var simulationRoomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)

                Text("SIMULATION ROOM")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            simulationRoomRow(
                title: "Practice the conversation",
                subtitle: "Rehearse the sensitive topic with a simulation of \(currentPerson.displayName) — before the real one.",
                icon: "bubble.left.and.bubble.right.fill",
                tint: SimastryColor.risingViolet
            ) {
                showPracticeChat = true
            }

            simulationRoomRow(
                title: "Predict their reply",
                subtitle: "Paste the thread, see the likely answer.",
                icon: SimastryIcon.predict,
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.predictionDraft = PredictionDraft(
                    targetName: currentPerson.displayName,
                    targetSunSign: currentPerson.sunSign,
                    targetMoonSign: currentPerson.moonSign,
                    targetRisingSign: currentPerson.risingSign,
                    question: "What will \(currentPerson.displayName) say next?",
                    conversationText: nil
                )
                viewModel.selectedTab = .today
                viewModel.predictRouteRequest += 1
            }

            simulationRoomRow(
                title: "Decode their text",
                subtitle: "One confusing message, read through their sign.",
                icon: "text.magnifyingglass",
                tint: SimastryColor.gold
            ) {
                viewModel.decodeDraftSign = currentPerson.sunSign
                viewModel.selectedTab = .today
                viewModel.decodeRouteRequest += 1
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20, accent: SimastryColor.risingViolet.opacity(0.6))
        .sheet(isPresented: $showPracticeChat) {
            PracticeChatView(viewModel: viewModel, person: currentPerson)
        }
    }

    private func simulationRoomRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: SimastryIconSize.md, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(subtitle)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(9)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Persona Context

    /// Behavior descriptors that sharpen the practice persona. Anything
    /// beyond behavior belongs in the user's own words in Notes — the
    /// persona reads those verbatim.
    private var personaContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text("TUNE THE PERSONA")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            personaChipRow(
                label: "Pronouns",
                options: ["she/her", "he/him", "they/them"],
                selected: currentPerson.pronouns
            ) { choice in
                var updated = currentPerson
                updated.pronouns = updated.pronouns == choice ? nil : choice
                viewModel.updateRelationshipPerson(updated)
            }

            personaChipRow(
                label: "Age",
                options: ["teens", "20s", "30s", "40s+"],
                selected: currentPerson.ageBand
            ) { choice in
                var updated = currentPerson
                updated.ageBand = updated.ageBand == choice ? nil : choice
                viewModel.updateRelationshipPerson(updated)
            }

            personalityTypePicker

            VStack(alignment: .leading, spacing: 7) {
                Text("How they text")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)

                ForEach([["dry", "emoji-heavy", "paragraphs"], ["slow replier", "double-texter", "voice notes"]], id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { option in
                            personaChip(option, isActive: (currentPerson.textingStyles ?? []).contains(option)) {
                                var updated = currentPerson
                                var styles = Set(updated.textingStyles ?? [])
                                if styles.contains(option) { styles.remove(option) } else { styles.insert(option) }
                                updated.textingStyles = styles.isEmpty ? nil : styles.sorted()
                                viewModel.updateRelationshipPerson(updated)
                            }
                        }
                    }
                }
            }

            Text("Anything else that matters — background, history, in-jokes — goes in Notes below, in your own words. The persona reads them verbatim.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    private var personalityTypePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Personality type")
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.mutedSilver)

            Picker(
                "Personality type",
                selection: Binding<MBTIPersonalityType?>(
                    get: { currentPerson.personalityType },
                    set: { choice in
                        var updated = currentPerson
                        updated.personalityType = choice
                        viewModel.updateRelationshipPerson(updated)
                    }
                )
            ) {
                Text("Unknown").tag(MBTIPersonalityType?.none)
                ForEach(MBTIPersonalityType.allCases) { type in
                    Text(type.rawValue).tag(Optional(type))
                }
            }
            .pickerStyle(.menu)
            .tint(SimastryColor.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.6)
            }

            Text("Optional. This tunes practice/playbook context without defining them.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
        }
    }

    private func personaChipRow(
        label: String,
        options: [String],
        selected: String?,
        onTap: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.mutedSilver)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    personaChip(option, isActive: selected == option) {
                        onTap(option)
                    }
                }
            }
        }
    }

    private func personaChip(_ title: String, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            onTap()
        } label: {
            Text(title)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isActive ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.82))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    isActive ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.06)),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isActive ? .white.opacity(0.22) : .white.opacity(0.08),
                        lineWidth: 0.6
                    )
                }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Couple Read needs both charts — partner-type people plus the user's Sun.
    @ViewBuilder
    private var coupleReadButton: some View {
        if currentPerson.relationshipType == .partner, let userSun = viewModel.userSunSign {
            Button {
                HapticManager.buttonPress()
                showCoupleRead = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: SimastryIconSize.md, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 40, height: 40)
                        .background(SimastryColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: SimastryRadius.small, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couple Read")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("Commitment styles, how you fight, repair, and talk money.")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(14)
                .surfaceCard(cornerRadius: SimastryRadius.large, accent: SimastryColor.gold.opacity(0.6))
                .contentShape(.rect)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Open Couple Read with \(currentPerson.displayName)")
            .sheet(isPresented: $showCoupleRead) {
                CoupleReadView(
                    nameA: (viewModel.profile?.displayName ?? "You").components(separatedBy: " ").first ?? "You",
                    sunA: userSun,
                    nameB: currentPerson.displayName,
                    sunB: currentPerson.sunSign
                )
            }
        }
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    situationSection
                    simulationRoomSection
                    personaContextSection
                    loopActionsRow
                    PersonPlaybookSection(viewModel: viewModel, person: currentPerson)
                    coupleReadButton
                    relationshipPatternSection
                    todayReadingSection
                    howToTalkSection
                    methodPanel
                    notesSection
                    privacySection
                    Spacer().frame(height: SimastrySpacing.tabBarClearance)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(currentPerson.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            guard !hasSeededEditableFields else { return }
            localNotes = currentPerson.notes ?? ""
            privateLabel = currentPerson.privateLabel ?? ""
            hasSeededEditableFields = true
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let prepared = SimastryPersonPhoto.prepared(data) {
                    var updated = currentPerson
                    updated.imageData = prepared
                    await MainActor.run {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            viewModel.updateRelationshipPerson(updated)
                        }
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .confirmationDialog("Delete this person?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete person", role: .destructive) {
                viewModel.deleteRelationshipPerson(currentPerson)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes their local relationship context and notes from this device.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentPerson.displayName)
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("\(currentPerson.relationshipType.rawValue) • \(currentPerson.signLine)")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.gold)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(currentPerson.birthPlace ?? "Private relationship context")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer()

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    RelationshipAvatarView(person: currentPerson, size: 72)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                                .foregroundStyle(SimastryColor.midnight)
                                .frame(width: 26, height: 26)
                                .background(SimastryColor.gold, in: Circle())
                                .overlay(Circle().stroke(SimastryColor.midnight, lineWidth: 2))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 22)
    }

    /// Bridges this person into the core loop: model their reply in Predict,
    /// or read sign-grounded message guidance without leaving the page.
    private var loopActionsRow: some View {
        HStack(spacing: 10) {
            Button {
                HapticManager.buttonPress()
                viewModel.openPredict(with: PredictionDraft(
                    targetName: currentPerson.displayName,
                    targetSunSign: currentPerson.sunSign,
                    targetMoonSign: currentPerson.moonSign,
                    targetRisingSign: currentPerson.risingSign,
                    question: "What will \(currentPerson.displayName) say next?"
                ))
            } label: {
                Label("Predict their reply", systemImage: "wand.and.stars")
                    .font(SimastryFont.labelMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SimastryGradient.gold, in: Capsule())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityHint("Opens Predict with \(currentPerson.displayName)'s chart signals filled in")

            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    showHowToTalk.toggle()
                }
            } label: {
                Label("How to talk", systemImage: "text.bubble")
                    .font(SimastryFont.labelMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.7))
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityHint("Shows communication guidance for a \(currentPerson.sunSign.displayName) Sun")
        }
    }

    @ViewBuilder
    private var howToTalkSection: some View {
        if showHowToTalk, let guide = CommunicationTemplates.guides[currentPerson.sunSign] {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("How to talk to \(currentPerson.displayName)", systemImage: "text.bubble.fill")

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(guide.tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(SimastryFont.microSemibold)
                                .foregroundStyle(SimastryColor.gold)
                                .padding(.top, 4)
                            Text(tip)
                                .font(SimastryFont.bodySmall)
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Best approach")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.gold)
                            .tracking(1)
                            .textCase(.uppercase)
                        Text(guide.bestApproach)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.82))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(SimastryColor.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("What to avoid")
                            .font(SimastryFont.overline)
                            .foregroundStyle(SimastryColor.amber)
                            .tracking(1)
                            .textCase(.uppercase)
                        Text(guide.avoid)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.74))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(SimastryColor.amber.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(16)
                .glossyCard(cornerRadius: 20)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var relationshipPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Relationship pattern", systemImage: "point.3.connected.trianglepath.dotted")
            insightRow("Emotional tone", reading.emotionalTone, systemImage: "heart.text.square.fill")
            insightRow("Communication style", reading.communicationStyle, systemImage: "bubble.left.and.bubble.right.fill")
            insightRow("Conflict style", reading.conflictStyle, systemImage: "exclamationmark.bubble.fill")
            insightRow("Repair style", reading.repairStyle, systemImage: "bandage.fill")
        }
    }

    private var todayReadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Today's reading", systemImage: "moon.stars.fill")
            VStack(alignment: .leading, spacing: 10) {
                Text(reading.headline)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(reading.body)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var methodPanel: some View {
        MethodLayerPanel(
            title: "Why this reading",
            summary: reading.methodSummary,
            signals: methodSignals,
            footer: "Private notes and message context stay on device in this prototype.",
            accent: SimastryColor.gold
        )
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Private notes", systemImage: "note.text")
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $localNotes)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: SimastryRadius.medium, style: .continuous))
                    .foregroundStyle(SimastryColor.offWhite)

                Button {
                    var updated = currentPerson
                    updated.notes = localNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.updateRelationshipPerson(updated)
                } label: {
                    Label("Save notes", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .tint(SimastryColor.gold)
            }
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Data and privacy", systemImage: "lock.shield.fill")
            VStack(alignment: .leading, spacing: 12) {
                Text("People are private relationship contexts. Simastry does not need contacts, distance, public visibility, or social discovery for this surface.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Private label, optional", text: $privateLabel)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .padding(12)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Button {
                        let trimmedLabel = privateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                        var updated = currentPerson
                        updated.privateLabel = trimmedLabel.isEmpty ? nil : trimmedLabel
                        viewModel.updateRelationshipPerson(updated)
                    } label: {
                        Label("Save label", systemImage: "eye.slash")
                    }
                    .buttonStyle(.bordered)
                    .tint(SimastryColor.gold)

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var methodSignals: [MethodSignal] {
        var signals: [MethodSignal] = [
            MethodSignal(label: "Their Sun", detail: currentPerson.sunSign.displayName, systemImage: "sun.max.fill", tint: currentPerson.sunSign.color)
        ]
        if let moon = currentPerson.moonSign {
            signals.append(MethodSignal(label: "Their Moon", detail: moon.displayName, systemImage: "moon.stars.fill", tint: SimastryColor.celestialBlue))
        }
        if let rising = currentPerson.risingSign {
            signals.append(MethodSignal(label: "Their Rising", detail: rising.displayName, systemImage: "sparkles", tint: SimastryColor.risingViolet))
        }
        if let personalityType = currentPerson.personalityType {
            signals.append(MethodSignal(label: "Personality", detail: personalityType.rawValue, systemImage: "person.crop.circle.badge.checkmark", tint: SimastryColor.goldLight))
        }
        if let userMoon = viewModel.userMoonSign {
            signals.append(MethodSignal(label: "Your Moon", detail: userMoon.displayName, systemImage: "moon.fill", tint: SimastryColor.celestialBlue))
        }
        if let typeSignal = CommunicationTypeProfile.methodSignal(
            sun: viewModel.userSunSign,
            moon: viewModel.userMoonSign,
            rising: viewModel.userRisingSign
        ) {
            signals.append(typeSignal)
        }
        return signals
    }

    private func insightRow(_ title: String, _ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: SimastryIconSize.md, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 30, height: 30)
                .background(SimastryColor.gold.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                Text(text)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glossyCard(cornerRadius: SimastryRadius.large)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)
        }
    }
}

struct AddRelationshipPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AppViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var name: String = ""
    @State private var privateLabel: String = ""
    @State private var relationshipType: RelationshipType = .friend
    @State private var sunSign: ZodiacSign = .libra
    @State private var moonSign: ZodiacSign?
    @State private var risingSign: ZodiacSign?
    @State private var personalityType: MBTIPersonalityType?
    @State private var hasBirthDate: Bool = false
    @State private var birthDate: Date = .now
    @State private var notes: String = ""

    private var canSave: Bool {
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
                        personalitySection
                        signsSection
                        birthSection
                        notesSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(SimastryColor.gold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                    }
                    .disabled(!canSave)
                    .tint(SimastryColor.gold)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let prepared = SimastryPersonPhoto.prepared(data) {
                        await MainActor.run {
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                imageData = prepared
                            }
                        }
                    }
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZodiacIconView(sign: sunSign, size: 58, showsGlow: true)
                            .padding(7)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(SimastryColor.gold.opacity(0.24), lineWidth: 1))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: SimastryIconSize.sm, weight: .semibold))
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(width: 26, height: 26)
                        .background(SimastryColor.gold, in: Circle())
                        .overlay(Circle().stroke(SimastryColor.midnight, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text("Private relationship context")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Manual only. No contact import, public discovery, distance, or dating signals.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 22)
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identity")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                TextField("Name or nickname", text: $name)
                    .textContentType(.name)
                TextField("Private label, optional", text: $privateLabel)

                Picker("Relationship", selection: $relationshipType) {
                    ForEach(RelationshipType.allCases) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
            }
            .font(SimastryFont.bodyMedium)
            .foregroundStyle(SimastryColor.offWhite)
            .textFieldStyle(.roundedBorder)
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var signsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart signals")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                signPicker("Sun", selection: Binding(get: { Optional(sunSign) }, set: { if let sign = $0 { sunSign = sign } }))
                signPicker("Moon", selection: $moonSign)
                signPicker("Rising", selection: $risingSign)
            }
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optional context")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                Picker("Personality type", selection: $personalityType) {
                    Text("Unknown").tag(MBTIPersonalityType?.none)
                    ForEach(MBTIPersonalityType.allCases) { type in
                        Text(type.rawValue).tag(Optional(type))
                    }
                }
                .pickerStyle(.menu)
                .tint(SimastryColor.gold)

                Text("This is only used as optional context in practice and playbook prompts.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(SimastryFont.bodyMedium)
            .foregroundStyle(SimastryColor.offWhite)
            .padding(18)
            .glossyCard(cornerRadius: 20)
        }
    }

    private var birthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use birth date to calculate Sun/Moon", isOn: $hasBirthDate)
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .tint(SimastryColor.gold)

            if hasBirthDate {
                DatePicker("Birth date", selection: $birthDate, displayedComponents: .date)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .tint(SimastryColor.gold)

                Text("Without exact birth time and coordinates, Simastry keeps Rising lighter.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 20)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            TextEditor(text: $notes)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: SimastryRadius.medium, style: .continuous))
                .foregroundStyle(SimastryColor.offWhite)
                .glossyCard(cornerRadius: 20)
        }
    }

    private func signPicker(_ title: String, selection: Binding<ZodiacSign?>) -> some View {
        Picker(title, selection: selection) {
            if title != "Sun" {
                Text("Unknown").tag(ZodiacSign?.none)
            }
            ForEach(ZodiacSign.allCases) { sign in
                Text(sign.displayName).tag(Optional(sign))
            }
        }
        .pickerStyle(.menu)
        .tint(SimastryColor.gold)
    }

    private func savePerson() {
        var finalSun = sunSign
        var finalMoon = moonSign
        var calculated = false

        if hasBirthDate {
            let chart = BirthChartService().calculate(
                birthday: birthDate,
                birthTime: nil,
                latitude: nil,
                longitude: nil,
                timeZone: .current
            )
            finalSun = chart.sunSign
            finalMoon = chart.moonSign
            calculated = true
        }

        let person = RelationshipPerson(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            privateLabel: privateLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : privateLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipType: relationshipType,
            birthDate: hasBirthDate ? birthDate : nil,
            birthTime: nil,
            birthPlace: nil,
            sunSign: finalSun,
            moonSign: finalMoon,
            risingSign: risingSign,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            imageData: imageData,
            isChartCalculated: calculated,
            updatedAt: .now,
            personalityType: personalityType
        )
        viewModel.addRelationshipPerson(person)
        dismiss()
    }
}

struct RelationshipAvatarView: View {
    let person: RelationshipPerson
    var size: CGFloat

    var body: some View {
        ZStack {
            if let data = person.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZodiacIconView(sign: person.sunSign, size: size, showsGlow: true)
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(SimastryColor.gold.opacity(0.22), lineWidth: 1))
        .shadow(color: person.sunSign.color.opacity(0.22), radius: size * 0.12, x: 0, y: size * 0.06)
        .accessibilityLabel("\(person.displayName), \(person.sunSign.displayName) Sun")
    }
}
