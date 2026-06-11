import SwiftUI

/// Group communication read for 2–5 people from the People tab — the
/// locker-room feature: how this specific group talks, clashes, and clicks.
struct TeamReadView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []
    @State private var includeMe: Bool = true
    @State private var teamRead: TeamRead?

    private var canIncludeMe: Bool {
        viewModel.userSunSign != nil
    }

    private var memberCount: Int {
        selectedIds.count + ((includeMe && canIncludeMe) ? 1 : 0)
    }

    private var canRead: Bool {
        (2...5).contains(memberCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let teamRead {
                            teamReadCardStack(teamRead)
                        } else {
                            pickerPhase
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Team Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if teamRead != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Edit group") {
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                teamRead = nil
                            }
                        }
                        .tint(SimastryColor.gold)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
            .onAppear {
                #if DEBUG
                if viewModel.isDebugPreviewStateActive, teamRead == nil, selectedIds.isEmpty {
                    selectedIds = Set(viewModel.relationshipPeople.prefix(3).map(\.id))
                    includeMe = canIncludeMe
                    if canRead { runRead() }
                }
                #endif
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Picker Phase

    private var pickerPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Pick 2–5 people")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Communication styles, not predictions — how this group actually talks.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            if canIncludeMe {
                Button {
                    HapticManager.buttonPress()
                    includeMe.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: includeMe ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(includeMe ? SimastryColor.gold : SimastryColor.mutedSilver)

                        Text("Include me")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.offWhite)

                        if let sun = viewModel.userSunSign {
                            Text(sun.displayName)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(sun.color)
                        }

                        Spacer()
                    }
                    .padding(13)
                    .surfaceCard(cornerRadius: 16)
                    .contentShape(.rect)
                }
                .buttonStyle(SpringPressStyle())
            }

            VStack(spacing: 8) {
                ForEach(viewModel.relationshipPeople) { person in
                    personRow(person)
                }
            }

            GoldButton("Read this group (\(memberCount))", isEnabled: canRead) {
                runRead()
            }
            .padding(.top, 4)

            if !canRead && memberCount > 5 {
                Text("Five voices max — bigger groups blur the read.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.textTertiary)
            }
        }
    }

    private func personRow(_ person: RelationshipPerson) -> some View {
        let isSelected = selectedIds.contains(person.id)

        return Button {
            HapticManager.buttonPress()
            if isSelected {
                selectedIds.remove(person.id)
            } else {
                selectedIds.insert(person.id)
            }
        } label: {
            HStack(spacing: 12) {
                RelationshipAvatarView(person: person, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.displayName)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)

                    Text("\(person.relationshipType.rawValue) · \(person.sunSign.displayName)")
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isSelected ? SimastryColor.gold : SimastryColor.mutedSilver.opacity(0.6))
            }
            .padding(11)
            .surfaceCard(cornerRadius: 16, accent: isSelected ? SimastryColor.gold.opacity(0.6) : nil)
            .contentShape(.rect)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(person.displayName), \(person.sunSign.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func runRead() {
        var members = viewModel.relationshipPeople
            .filter { selectedIds.contains($0.id) }
            .map { TeamReadMember(name: $0.displayName, sun: $0.sunSign, moon: $0.moonSign, isUser: false) }

        if includeMe, let sun = viewModel.userSunSign {
            let firstName = (viewModel.profile?.displayName ?? "You")
                .components(separatedBy: " ").first ?? "You"
            members.insert(
                TeamReadMember(name: firstName, sun: sun, moon: viewModel.userMoonSign, isUser: true),
                at: 0
            )
        }

        guard (2...5).contains(members.count) else { return }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        HapticManager.signConfirmed()
        withAnimation(.spring(SimastrySpring.smooth)) {
            teamRead = TeamReadEngine.read(members: members, seed: dayOfYear)
        }
    }

    // MARK: - Result Phase

    private func teamReadCardStack(_ read: TeamRead) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Headline + composition
            VStack(alignment: .leading, spacing: 12) {
                Text(read.headline)
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(ZodiacElement.allCases, id: \.self) { element in
                        if let count = read.elementCounts[element], count > 0 {
                            compositionChip(
                                label: element.rawValue.capitalized,
                                count: count,
                                tint: elementTint(element)
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(["cardinal", "fixed", "mutable"], id: \.self) { modality in
                        if let count = read.modalityCounts[modality], count > 0 {
                            compositionChip(
                                label: TeamReadTemplates.modalityRoles[modality] ?? modality.capitalized,
                                count: count,
                                tint: SimastryColor.mutedSilver
                            )
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroGlass(SimastryColor.gold, cornerRadius: 22)

            // Roles
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("WHO PLAYS WHAT", icon: "person.3.fill", tint: SimastryColor.celestialBlue)

                ForEach(read.roles, id: \.memberName) { role in
                    HStack(alignment: .top, spacing: 10) {
                        Text(role.title)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.celestialBlue)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(SimastryColor.celestialBlue.opacity(0.12), in: Capsule())
                            .frame(width: 92, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.memberName)
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            Text(role.line)
                                .font(SimastryFont.captionSmall)
                                .foregroundStyle(SimastryColor.mutedSilver)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: 20)

            // Pair highlights
            if !read.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("THE CONNECTIONS", icon: "point.3.connected.trianglepath.dotted", tint: SimastryColor.gold)

                    ForEach(Array(read.highlights.enumerated()), id: \.offset) { _, highlight in
                        Text(highlight.line)
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: 20)
            }

            // Friction + bridge
            if let friction = read.frictionPair, let bridge = read.bridge {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("THE FRICTION — AND THE BRIDGE", icon: "arrow.triangle.merge", tint: SimastryColor.amber)

                    Text(friction.line)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(bridge)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.amber)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard(cornerRadius: 20, accent: SimastryColor.amber.opacity(0.7))
            }

            // The play
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("THE PLAY", icon: "sportscourt.fill", tint: SimastryColor.gold)

                Text(read.play)
                    .font(SimastryFont.bodyLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroGlass(SimastryColor.gold, cornerRadius: 22)

            Text("The same playbook an NBA captain runs on his locker room — signs as a memory system for how people communicate.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.3)
        }
    }

    private func compositionChip(label: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.88))

            Text("\(count)")
                .font(SimastryFont.labelSmall.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay {
            Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.6)
        }
    }

    private func elementTint(_ element: ZodiacElement) -> Color {
        switch element {
        case .fire: SimastryColor.sunCoral
        case .earth: Color(red: 152/255, green: 212/255, blue: 184/255)
        case .air: SimastryColor.risingViolet
        case .water: SimastryColor.celestialBlue
        }
    }
}
