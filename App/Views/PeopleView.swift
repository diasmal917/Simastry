import SwiftUI
import PhotosUI
import ContactsUI
import UIKit

nonisolated private enum PeopleSheet: Identifiable {
    case addPerson
    case teamRead

    var id: String {
        switch self {
        case .addPerson:
            return "addPerson"
        case .teamRead:
            return "teamRead"
        }
    }
}

struct PeopleView: View {
    @Bindable var viewModel: AppViewModel
    @State private var searchText: String = ""
    @State private var selectedType: RelationshipType?
    @State private var isSearchExpanded = false
    @FocusState private var searchFieldFocused: Bool
    @State private var activeSheet: PeopleSheet?
    @State private var navigationPath = NavigationPath()
    @State private var handledTeamReadRouteRequest: Int = 0
    @State private var pendingChartUploadPerson: RelationshipPerson?

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

    private var filteredPeopleIds: Set<UUID> {
        Set(filteredPeople.map(\.id))
    }

    private var filteredRecentlyReflectedPeople: [RelationshipPerson] {
        recentlyReflectedPeople.filter { filteredPeopleIds.contains($0.id) }
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        searchAndFilterSection
                            .id("people.searchSection")

                        if let needsAttentionPerson {
                            needsAttentionCard(needsAttentionPerson)
                        }

                        if filteredPeople.isEmpty {
                            emptyState
                        } else {
                            peopleListSection
                        }

                        Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
                .background { CelestialBackground() }
                .safeAreaInset(edge: .top, spacing: 0) {
                    AppTabFloatingHeader(viewModel: viewModel) {
                        Button {
                            toggleSearch(using: proxy)
                        } label: { HeaderActionIcon(systemName: "magnifyingglass") }
                        .accessibilityLabel("Search people")
                        .accessibilityHint("Shows the search field")
                        .accessibilityIdentifier("people.toolbar.searchButton")
                        .buttonStyle(.plain)

                        Button {
                            presentAddPerson()
                        } label: { HeaderActionIcon(systemName: "plus") }
                        .accessibilityLabel("Add person")
                        .accessibilityHint("Add a person to read")
                        .accessibilityIdentifier("people.toolbar.addPersonButton")
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityHidden(activeSheet != nil)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .addPerson:
                        AddRelationshipPersonView(viewModel: viewModel) { person, shouldOpenChartUpload in
                            guard shouldOpenChartUpload else { return }
                            pendingChartUploadPerson = person
                        }
                    case .teamRead:
                        TeamReadView(viewModel: viewModel)
                    }
                }
                .navigationDestination(for: RelationshipPerson.self) { person in
                    RelationshipPersonDetailView(viewModel: viewModel, person: person)
                }
                .onAppear {
                    viewModel.loadRelationshipPeople()
                    #if DEBUG
                    if viewModel.isDebugPreviewStateActive,
                       !viewModel.keepsDebugRelationshipPeopleEmpty,
                       viewModel.relationshipPeople.isEmpty {
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
                .onChange(of: activeSheet?.id) {
                    guard activeSheet == nil, let person = pendingChartUploadPerson else { return }
                    pendingChartUploadPerson = nil
                    navigationPath.append(person)
                }
            }
        }
    }

    /// Expands or collapses the inline search field. Expanding scrolls the
    /// section into view and focuses the field; collapsing clears the query so
    /// a hidden filter can never keep narrowing the list. The expand/collapse
    /// itself is animated by `searchAndFilterSection`'s `.animation` driver.
    private func toggleSearch(using proxy: ScrollViewProxy) {
        isSearchExpanded.toggle()
        if isSearchExpanded {
            withAnimation(.spring(SimastrySpring.snappy)) {
                proxy.scrollTo("people.searchSection", anchor: .top)
            }
            // Focus once the field has mounted — focusing in the same
            // transaction as the insertion is unreliable.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchFieldFocused = true
            }
        } else {
            searchText = ""
            searchFieldFocused = false
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
            activeSheet = .teamRead
        }
    }

    /// Replaces the old nav-bar search field and filter menu: an expandable
    /// search field plus a horizontal row of relationship-type chips, both
    /// bound to the same `searchText`/`selectedType` filtering already used
    /// by `filteredPeople`.
    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSearchExpanded {
                HStack(spacing: 8) {
                    TextField("Search people or signs", text: $searchText)
                        .focused($searchFieldFocused)
                        .font(SimastryFont.bodyMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .accessibilityIdentifier("people.searchField")

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .frame(width: 32, height: 32)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityIdentifier("people.search.clearButton")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .simastryGlassPill()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                    }
                    ForEach(RelationshipType.allCases) { type in
                        filterChip(title: type.rawValue, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .animation(.spring(SimastrySpring.snappy), value: isSearchExpanded)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Text(title)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isSelected ? SimastryColor.gold : SimastryColor.offWhite.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .simastryGlassPill(interactive: true)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Entry to the group communication read — shown once 2+ people exist, as
    /// a compact pill trailing the list header (was a standalone hero card
    /// pre-merge; the header's caption absorbed the old stat card's facts).
    private var teamReadPill: some View {
        Button {
            HapticManager.buttonPress()
            activeSheet = .teamRead
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Read this group")
                    .font(SimastryFont.labelSmall)
            }
            .foregroundStyle(SimastryColor.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .goldGlassPill(interactive: true)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Read this group. How this group communicates.")
        .accessibilityIdentifier("people.teamReadEntryButton")
    }

    /// Single merged list: the "Recent reads" ordering source (people with a
    /// reflection, newest `updatedAt` first) leads, then everyone else in
    /// their existing order. Each person appears exactly once — the old
    /// split (a capped recent strip stacked above the full roster) could
    /// show the same person twice.
    private var orderedPeople: [RelationshipPerson] {
        let recent = filteredRecentlyReflectedPeople
        let recentIds = Set(recent.map(\.id))
        let rest = filteredPeople.filter { !recentIds.contains($0.id) }
        return recent + rest
    }

    private var peopleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            peopleListHeader
            ForEach(orderedPeople) { person in
                NavigationLink(value: person) {
                    relationshipPersonCard(person)
                }
                .buttonStyle(SpringPressStyle())
            }
        }
    }

    /// Replaces the old RELATIONSHIP MEMORY stat card: its facts (people
    /// count, privacy) compress into this overline caption, and "Read this
    /// group" becomes the trailing pill on the same row.
    private var peopleListHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            sectionTitle(peopleListCaption, systemImage: "lock.fill")
            Spacer(minLength: 8)
            if viewModel.relationshipPeople.count >= 2 {
                teamReadPill
            }
        }
    }

    private var peopleListCaption: String {
        "People · \(viewModel.relationshipPeople.count) · private"
    }

    private func needsAttentionCard(_ person: RelationshipPerson) -> some View {
        let reading = viewModel.relationshipReading(for: person)
        return NavigationLink(value: person) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.haze.fill")
                        .font(.system(size: 14, weight: .semibold))
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

    /// Exactly one sign indicator: the leading pastel `ZodiacSignToken` disc
    /// inside `RelationshipAvatarView`. No trailing sign chip, no
    /// relationship-type glyph after the name — the type is already spelled
    /// out in the context line below.
    private func relationshipPersonCard(_ person: RelationshipPerson) -> some View {
        let reading = viewModel.relationshipReading(for: person)
        return HStack(spacing: 14) {
            RelationshipAvatarView(person: person, size: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(person.displayName)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(personCardContextLine(for: person))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)

                Text(reading.bestEnergy)
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glossyCard(cornerRadius: 18)
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
        Button {
            presentAddPerson()
        } label: {
            VStack(spacing: 16) {
                Image("EmptyPeople")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .accessibilityHidden(true)

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

                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add person")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .goldGlassPill(interactive: true)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .glossyCard(cornerRadius: 22)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Add person")
        .accessibilityIdentifier("people.empty.addPersonButton")
    }

    private func presentAddPerson() {
        HapticManager.buttonPress()
        activeSheet = .addPerson
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
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
    @State private var showCoupleRead: Bool = false
    @State private var showPracticeHub: Bool = false

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
                    .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.risingViolet)

                Text("SIMULATION ROOM")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)
            }

            simulationRoomRow(
                title: "Practice a conversation",
                subtitle: "Rehearse the sensitive topic with a simulation of \(currentPerson.displayName) — before the real one.",
                icon: "theatermasks.fill",
                tint: SimastryColor.risingViolet,
                identifier: "people.detail.practiceButton"
            ) {
                showPracticeHub = true
            }

            simulationRoomRow(
                title: "Predict their reply",
                subtitle: "Paste the thread, see the likely answer.",
                icon: SimastryIcon.predict,
                tint: SimastryColor.celestialBlue
            ) {
                viewModel.openPredict(with: PredictionDraft(
                    targetName: currentPerson.displayName,
                    targetSunSign: currentPerson.sunSign,
                    targetMoonSign: currentPerson.moonSign,
                    targetRisingSign: currentPerson.risingSign,
                    question: "What will \(currentPerson.displayName) say next?",
                    conversationText: nil
                ))
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
        .sheet(isPresented: $showPracticeHub) {
            // The coached Practice hub, pre-targeted at this person — the
            // same experience the Talk practice row opens (spec §5).
            RehearsalRoomView(viewModel: viewModel, prefilledPerson: currentPerson)
        }
    }

    private func simulationRoomRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 11) {
                SimastryConceptIconView(
                    name: icon,
                    size: icon == SimastryIcon.predict ? 34 : 36,
                    symbolSize: 14,
                    accent: tint,
                    animatedPrediction: icon == SimastryIcon.predict
                )
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(9)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityIdentifier(identifier ?? "people.detail.simulationRoom.\(title.replacingOccurrences(of: " ", with: ""))")
    }

    // MARK: - Persona Context

    /// Behavior descriptors that sharpen the practice persona. Anything
    /// beyond behavior belongs in the user's own words in Notes — the
    /// persona reads those verbatim.
    private var personaContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)

                Text("TUNE THE PERSONA")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.3)

                Spacer()

                if !isProUser {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("PRO")
                            .font(SimastryFont.overline)
                            .tracking(0.8)
                    }
                    .foregroundStyle(SimastryColor.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SimastryColor.gold.opacity(0.13), in: Capsule())
                }
            }

            if isProUser {
                personaControls
            } else {
                personaUpsellTeaser
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: 20)
    }

    /// The actual persona-tuning controls — Pro only.
    @ViewBuilder
    private var personaControls: some View {
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

    /// Locked teaser shown to free users in place of the persona controls.
    private var personaUpsellTeaser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dial in pronouns, age, personality type, and texting style so practice runs and playbooks sound like the real person.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.buttonPress()
                viewModel.showUpsell = true
            } label: {
                Label("Unlock with Pro", systemImage: "sparkles")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(SimastryGradient.gold, in: Capsule())
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Unlock persona tuning with Simastry Pro")
        }
    }

    private var isProUser: Bool {
        guard viewModel.isRevenueCatAvailable else { return true }
        return (viewModel.profile?.tier ?? "free") == "pro"
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
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 40, height: 40)
                        .background(SimastryColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .padding(14)
                .surfaceCard(cornerRadius: 18, accent: SimastryColor.gold.opacity(0.6))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ExpertChartImportSection(viewModel: viewModel, subject: .person(currentPerson))
                howToTalkSection
                predictReplyButton
                situationSection
                simulationRoomSection
                personaContextSection
                PersonPlaybookSection(viewModel: viewModel, person: currentPerson)
                coupleReadButton
                relationshipPatternSection
                todayReadingSection
                methodPanel
                notesSection
                privacySection
                Spacer().frame(height: SimastrySpacing.tabBarEndClearance)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CelestialBackground() }
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
                                .font(.system(size: 11, weight: .semibold))
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

    /// Bridges this person into the core loop: model their reply in Predict
    /// with their chart signals already filled in.
    private var predictReplyButton: some View {
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
                .font(SimastryFont.labelLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(SimastryColor.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(SimastryGradient.gold, in: Capsule())
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityHint("Opens Predict with \(currentPerson.displayName)'s chart signals filled in")
        .accessibilityIdentifier("people.detail.predictReplyButton")
    }

    @ViewBuilder
    private var howToTalkSection: some View {
        if let guide = CommunicationTemplates.guides[currentPerson.sunSign] {
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
            footer: "Private notes and message context stay on this device unless you choose to share them.",
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
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .font(.system(size: 16, weight: .semibold))
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
        .glossyCard(cornerRadius: 18)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
            Text(title)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)
        }
    }
}

private enum AddPersonSelectionSheet: String, Identifiable, Hashable {
    case relationship
    case personality
    case sun
    case moon
    case rising

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relationship: "Relationship"
        case .personality: "Personality"
        case .sun: "Sun sign"
        case .moon: "Moon sign"
        case .rising: "Rising sign"
        }
    }
}

private enum AddPersonFocusedField: Hashable {
    case name
    case privateLabel
}

private struct RelationshipContactImportPayload {
    let displayName: String
    let imageData: Data?
    let birthday: Date?
}

private struct RelationshipContactPicker: UIViewControllerRepresentable {
    let onSelect: (RelationshipContactImportPayload) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        controller.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactNicknameKey,
            CNContactImageDataKey,
            CNContactBirthdayKey
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (RelationshipContactImportPayload) -> Void

        init(onSelect: @escaping (RelationshipContactImportPayload) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let formattedName = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = [formattedName, nickname, contact.organizationName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? "New person"

            onSelect(
                RelationshipContactImportPayload(
                    displayName: displayName,
                    imageData: contact.imageDataAvailable ? contact.imageData : nil,
                    birthday: Self.birthday(from: contact.birthday)
                )
            )
        }

        private static func birthday(from components: DateComponents?) -> Date? {
            guard var components,
                  components.year != nil,
                  components.month != nil,
                  components.day != nil else {
                return nil
            }
            components.calendar = components.calendar ?? Calendar(identifier: .gregorian)
            return components.date
        }
    }
}

struct AddRelationshipPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AppViewModel
    var onSaved: ((RelationshipPerson, Bool) -> Void)? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectionPath = NavigationPath()
    @State private var imageData: Data?
    @State private var name: String = Self.prefilledNameForUITest()
    @State private var privateLabel: String = ""
    @State private var relationshipType: RelationshipType = .friend
    @State private var sunSign: ZodiacSign = .libra
    @State private var moonSign: ZodiacSign?
    @State private var risingSign: ZodiacSign?
    @State private var personalityType: MBTIPersonalityType?
    @State private var isPersonalityExpanded: Bool = true
    @State private var hasBirthDate: Bool = false
    @State private var birthDate: Date = .now
    @State private var notes: String = ""
    @State private var showingContactPicker: Bool = false
    @State private var openChartUploadAfterSave: Bool = false
    @FocusState private var focusedField: AddPersonFocusedField?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var debugStateSummary: String {
        [
            "name:\(name.trimmingCharacters(in: .whitespacesAndNewlines))",
            "relationship:\(relationshipType.rawValue)",
            "sun:\(sunSign.rawValue)",
            "moon:\(moonSign?.rawValue ?? "unknown")",
            "rising:\(risingSign?.rawValue ?? "unknown")",
            "personality:\(personalityType?.rawValue ?? "unknown")"
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack(path: $selectionPath) {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        identitySection
                        signsSection
                        birthSection
                        notesSection
                        personalitySection
                        Spacer().frame(height: 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 72)
                    .padding(.bottom, 18)
                }
                .tint(SimastryColor.gold)
                .lockHorizontalScroll()
            }
            .navigationTitle("New person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(SimastryColor.gold)
                        .accessibilityIdentifier("people.addPerson.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                    }
                    .disabled(!canSave)
                    .tint(SimastryColor.gold)
                    .accessibilityIdentifier("people.addPerson.saveButton")
                }
            }
            .navigationDestination(for: AddPersonSelectionSheet.self) { sheet in
                selectionScreen(sheet)
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
            .sheet(isPresented: $showingContactPicker) {
                RelationshipContactPicker { payload in
                    applyImportedContact(payload)
                }
            }
        }
        .accessibilityIdentifier("people.addPersonSheet")
        .accessibilityValue(debugStateSummary)
    }

    private static func prefilledNameForUITest() -> String {
        if let environmentName = ProcessInfo.processInfo.environment["SIMASTRY_UI_PREFILL_ADD_PERSON_NAME"],
           !environmentName.isEmpty {
            return environmentName
        }

        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "-SimastryUITestPrefillAddPersonName"),
              arguments.indices.contains(marker + 1) else {
            if arguments.contains("-SimastryPreviewScreen"), arguments.contains("peopleEmpty") {
                return "Alex"
            }
            return ""
        }
        return arguments[marker + 1]
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
                .overlay {
                    // Ring frames a real photo only; the zodiac-glyph fallback stays borderless.
                    if imageData != nil {
                        Circle().stroke(SimastryColor.gold.opacity(0.24), lineWidth: 1)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(width: 26, height: 26)
                        .background(SimastryColor.gold, in: Circle())
                        .overlay(Circle().stroke(SimastryColor.midnight, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("people.addPerson.photoPicker")

            VStack(alignment: .leading, spacing: 5) {
                Text("Private relationship context")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Import only name, photo, and birthday if you choose. No phone, email, discovery, distance, or dating signals.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticManager.buttonPress()
                    showingContactPicker = true
                } label: {
                    Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .simastryGlassPill(interactive: true)
                }
                .buttonStyle(SpringPressStyle())
                .padding(.top, 5)
                .accessibilityIdentifier("people.addPerson.importContactsButton")
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
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 46)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit {
                        focusedField = .privateLabel
                    }
                    .accessibilityIdentifier("people.addPerson.nameField")
                TextField("Private label, optional", text: $privateLabel)
                    .focused($focusedField, equals: .privateLabel)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 46)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("people.addPerson.privateLabelField")

                relationshipChoiceGrid

                Toggle("Upload birth chart after saving", isOn: $openChartUploadAfterSave)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .tint(SimastryColor.gold)
                    .accessibilityIdentifier("people.addPerson.openChartUploadToggle")

                Text("Use this when you have their chart screenshot and want Simastry to keep those details attached to this person privately.")
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

    private var signsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart signals")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.4)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                signChoiceGrid(title: "Sun", selected: sunSign, allowsUnknown: false) { sign in
                    if let sign { sunSign = sign }
                }
                signChoiceGrid(title: "Moon", selected: moonSign, allowsUnknown: true) { sign in
                    moonSign = sign
                }
                signChoiceGrid(title: "Rising", selected: risingSign, allowsUnknown: true) { sign in
                    risingSign = sign
                }
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
                Button {
                    HapticManager.buttonPress()
                    withAnimation(.spring(SimastrySpring.snappy)) {
                        isPersonalityExpanded.toggle()
                    }
                } label: {
                    selectionRowLabel(
                        title: "Personality type",
                        value: personalityType?.rawValue ?? "Unknown",
                        systemImage: "person.text.rectangle.fill"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("people.addPerson.personalityMenu")
                .accessibilityLabel("Personality type, \(personalityType?.rawValue ?? "Unknown")")
                .accessibilityAddTraits(.isButton)

                if isPersonalityExpanded {
                    personalityDropdownOptions
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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

    private var personalityDropdownOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            personalityOptionButton(title: "Unknown", isSelected: personalityType == nil, identifier: optionIdentifier(group: "personality", value: "unknown")) {
                personalityType = nil
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(MBTIPersonalityType.allCases) { type in
                    personalityOptionButton(
                        title: type.rawValue,
                        isSelected: personalityType == type,
                        identifier: optionIdentifier(group: "personality", value: type.rawValue)
                    ) {
                        personalityType = type
                    }
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("people.addPerson.personalityOptions")
    }

    private func personalityOptionButton(
        title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
            withAnimation(.spring(SimastrySpring.snappy)) {
                isPersonalityExpanded = false
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(SimastryFont.captionSmall.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? SimastryColor.gold : .white.opacity(0.075), in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }

    private var relationshipChoiceGrid: some View {
        choiceGroup(title: "Relationship", identifier: "people.addPerson.relationshipRow") {
            ForEach(RelationshipType.allCases) { type in
                choiceChip(
                    title: type.rawValue,
                    systemImage: type.systemImage,
                    isSelected: relationshipType == type,
                    identifier: optionIdentifier(group: "relationship", value: type.rawValue)
                ) {
                    relationshipType = type
                }
            }
        }
    }

    private var personalityChoiceGrid: some View {
        choiceGroup(title: "Personality type", identifier: "people.addPerson.personalityRow") {
            choiceChip(
                title: "Unknown",
                systemImage: "questionmark.circle.fill",
                isSelected: personalityType == nil,
                identifier: optionIdentifier(group: "personality", value: "unknown")
            ) {
                personalityType = nil
            }
            ForEach(MBTIPersonalityType.allCases) { type in
                choiceChip(
                    title: type.rawValue,
                    systemImage: "person.text.rectangle.fill",
                    isSelected: personalityType == type,
                    identifier: optionIdentifier(group: "personality", value: type.rawValue)
                ) {
                    personalityType = type
                }
            }
        }
    }

    private func signChoiceGrid(
        title: String,
        selected: ZodiacSign?,
        allowsUnknown: Bool,
        onSelect: @escaping (ZodiacSign?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .textCase(.uppercase)
                    .tracking(0.7)

                if allowsUnknown {
                    optionalChartSignalPill(title: title)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], alignment: .leading, spacing: 14) {
                if allowsUnknown {
                    unknownSignButton(
                        title: title,
                        isSelected: selected == nil,
                        identifier: optionIdentifier(group: title.lowercased(), value: "unknown")
                    ) {
                        onSelect(nil)
                    }
                }

                ForEach(ZodiacSign.allCases) { sign in
                    zodiacSignButton(
                        sign: sign,
                        title: title,
                        isSelected: selected == sign,
                        identifier: optionIdentifier(group: title.lowercased(), value: sign.rawValue)
                    ) {
                        onSelect(sign)
                    }
                }
            }
        }
        .accessibilityIdentifier("people.addPerson.sign.\(title.lowercased())")
    }

    private func optionalChartSignalPill(title: String) -> some View {
        Label("Optional", systemImage: "info.circle")
            .font(SimastryFont.captionSmall.weight(.semibold))
            .foregroundStyle(SimastryColor.deepMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.055), in: Capsule())
            .help("\(title) can be left blank. Adding it later improves relationship and timing accuracy.")
            .accessibilityLabel("\(title) optional")
            .accessibilityHint("You can skip this now, but adding it later improves accuracy.")
    }

    private func zodiacSignButton(
        sign: ZodiacSign,
        title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.zodiacSelection()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    // Just the icon, no disc/ring behind it — selection is opacity + scale.
                    ZodiacIconView(sign: sign, size: 42, showsGlow: isSelected)
                        .frame(width: 46, height: 46)
                        .accessibilityHidden(true)
                        .opacity(isSelected ? 1.0 : 0.6)
                        .scaleEffect(isSelected ? 1.08 : 1.0)

                    Text(sign.displayName)
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(isSelected ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .accessibilityHidden(true)
                }
                .frame(width: 64, height: 70)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)
                        .background(SimastryColor.midnight, in: Circle())
                        .offset(x: 3, y: -3)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 64, height: 72)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityLabel("\(title) \(sign.displayName)")
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(.isButton)
    }

    private func unknownSignButton(
        title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.mutedSilver)
                        .frame(width: 46, height: 46)
                        .background(isSelected ? SimastryColor.gold : .white.opacity(0.075), in: Circle())
                        .opacity(isSelected ? 1.0 : 0.72)
                        .accessibilityHidden(true)

                    Text("Not sure")
                        .font(SimastryFont.captionSmall.weight(.semibold))
                        .foregroundStyle(isSelected ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true)
                }
                .frame(width: 64, height: 70)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SimastryColor.gold)
                        .background(SimastryColor.midnight, in: Circle())
                        .offset(x: 3, y: -3)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 64, height: 72)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .help("\(title) can be skipped. Add it later for a more accurate read.")
        .accessibilityLabel("\(title) not sure")
        .accessibilityHint("Optional. Add it later for a more accurate read.")
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(.isButton)
    }

    private func choiceGroup<Content: View>(
        title: String,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .textCase(.uppercase)
                .tracking(0.7)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                content()
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func choiceChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(SimastryFont.captionSmall.weight(.semibold))
                .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? SimastryColor.gold : .white.opacity(0.075), in: Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? SimastryColor.gold : .white.opacity(0.08), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
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
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(SimastryColor.offWhite)
                .glossyCard(cornerRadius: 20)
        }
    }

    private func selectionRow(
        title: String,
        value: String,
        systemImage: String,
        identifier: String,
        destination: AddPersonSelectionSheet
    ) -> some View {
        Menu {
            selectionMenuOptions(for: destination)
        } label: {
            selectionRowLabel(title: title, value: value, systemImage: systemImage)
        }
        .accessibilityLabel("\(title), \(value)")
        .accessibilityIdentifier(identifier)
    }

    private func selectionRowLabel(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Text(value)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
        }
        .padding(14)
        .background(SimastryColor.surface.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SimastryColor.gold.opacity(0.18), lineWidth: 0.7)
        )
        .contentShape(.rect)
    }

    @ViewBuilder
    private func selectionMenuOptions(for destination: AddPersonSelectionSheet) -> some View {
        switch destination {
        case .relationship:
            ForEach(RelationshipType.allCases) { type in
                Button(type.rawValue) {
                    HapticManager.buttonPress()
                    relationshipType = type
                }
            }
        case .personality:
            Button("Unknown") {
                HapticManager.buttonPress()
                personalityType = nil
            }
            ForEach(MBTIPersonalityType.allCases) { type in
                Button(type.rawValue) {
                    HapticManager.buttonPress()
                    personalityType = type
                }
            }
        case .sun:
            ForEach(ZodiacSign.allCases) { sign in
                Button(sign.displayName) {
                    HapticManager.buttonPress()
                    sunSign = sign
                }
            }
        case .moon:
            Button("Unknown") {
                HapticManager.buttonPress()
                moonSign = nil
            }
            ForEach(ZodiacSign.allCases) { sign in
                Button(sign.displayName) {
                    HapticManager.buttonPress()
                    moonSign = sign
                }
            }
        case .rising:
            Button("Unknown") {
                HapticManager.buttonPress()
                risingSign = nil
            }
            ForEach(ZodiacSign.allCases) { sign in
                Button(sign.displayName) {
                    HapticManager.buttonPress()
                    risingSign = sign
                }
            }
        }
    }

    private func selectionScreen(_ sheet: AddPersonSelectionSheet) -> some View {
        ZStack {
            CelestialBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    switch sheet {
                    case .relationship:
                        ForEach(RelationshipType.allCases) { type in
                            selectionOption(
                                title: type.rawValue,
                                systemImage: type.systemImage,
                                isSelected: relationshipType == type,
                                identifier: optionIdentifier(group: "relationship", value: type.rawValue)
                            ) {
                                relationshipType = type
                                closeSelection()
                            }
                        }
                    case .personality:
                        selectionOption(
                            title: "Unknown",
                            systemImage: "questionmark.circle.fill",
                            isSelected: personalityType == nil,
                            identifier: optionIdentifier(group: "personality", value: "unknown")
                        ) {
                            personalityType = nil
                            closeSelection()
                        }
                        ForEach(MBTIPersonalityType.allCases) { type in
                            selectionOption(
                                title: type.rawValue,
                                systemImage: "person.text.rectangle.fill",
                                isSelected: personalityType == type,
                                identifier: optionIdentifier(group: "personality", value: type.rawValue)
                            ) {
                                personalityType = type
                                closeSelection()
                            }
                        }
                    case .sun, .moon, .rising:
                        if sheet != .sun {
                            selectionOption(
                                title: "Unknown",
                                systemImage: "questionmark.circle.fill",
                                isSelected: selectedSign(for: sheet) == nil,
                                identifier: optionIdentifier(group: sheet.rawValue, value: "unknown")
                            ) {
                                setSign(nil, for: sheet)
                                closeSelection()
                            }
                        }
                        ForEach(ZodiacSign.allCases) { sign in
                            selectionOption(
                                title: sign.displayName,
                                systemImage: "sparkles",
                                isSelected: selectedSign(for: sheet) == sign,
                                identifier: optionIdentifier(group: sheet.rawValue, value: sign.rawValue)
                            ) {
                                setSign(sign, for: sheet)
                                closeSelection()
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    closeSelection()
                }
                .tint(SimastryColor.gold)
            }
        }
        .accessibilityIdentifier("people.addPerson.selection.\(sheet.rawValue)")
    }

    private func selectionOption(
        title: String,
        systemImage: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.gold)
                    .frame(width: 30, height: 30)
                    .background(
                        isSelected ? SimastryColor.gold : SimastryColor.gold.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Text(title)
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(SimastryColor.gold)
                }
            }
            .padding(15)
            .glossyCard(cornerRadius: 18)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private func closeSelection() {
        if !selectionPath.isEmpty {
            selectionPath.removeLast()
        }
    }

    private func selectedSign(for sheet: AddPersonSelectionSheet) -> ZodiacSign? {
        switch sheet {
        case .sun:
            sunSign
        case .moon:
            moonSign
        case .rising:
            risingSign
        case .relationship, .personality:
            nil
        }
    }

    private func setSign(_ sign: ZodiacSign?, for sheet: AddPersonSelectionSheet) {
        switch sheet {
        case .sun:
            if let sign {
                sunSign = sign
            }
        case .moon:
            moonSign = sign
        case .rising:
            risingSign = sign
        case .relationship, .personality:
            break
        }
    }

    private func optionIdentifier(group: String, value: String) -> String {
        let safeValue = value
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return "people.addPerson.option.\(group).\(safeValue)"
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
        onSaved?(person, openChartUploadAfterSave)
        dismiss()
    }

    private func applyImportedContact(_ payload: RelationshipContactImportPayload) {
        HapticManager.buttonPress()
        name = payload.displayName
        if let imageData = payload.imageData,
           let prepared = SimastryPersonPhoto.prepared(imageData) {
            self.imageData = prepared
        }
        if let birthday = payload.birthday {
            birthDate = birthday
            hasBirthDate = true
        }
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
                ZodiacSignToken(sign: person.sunSign, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            // Ring frames a real photo only; the zodiac-glyph avatar stays borderless.
            if person.imageData != nil {
                Circle().stroke(SimastryColor.gold.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: person.imageData != nil ? person.sunSign.color.opacity(0.22) : .clear, radius: size * 0.12, x: 0, y: size * 0.06)
        .accessibilityLabel("\(person.displayName), \(person.sunSign.displayName) Sun")
    }
}
