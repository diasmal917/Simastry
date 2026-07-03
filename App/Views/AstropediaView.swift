import SwiftUI
import Foundation

struct AstropediaView: View {
    @Bindable var viewModel: AppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTopic: AstropediaTopic = .plainEnglish
    @State private var focusedSign: ZodiacSign = .aries
    @State private var searchText: String = ""
    @State private var recentLookups: [AstropediaLookup] = []
    @State private var hasInitialized: Bool = false
    @State private var selectedCommunicationGuideSign: ZodiacSign?
    @State private var hasRevealedCommunicationGuides: Bool = false

    private static let recentLookupsKey: String = "astropedia_recent_lookups"
    private let communicationGuideColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasProfileSigns: Bool {
        viewModel.userSunSign != nil && viewModel.userMoonSign != nil && viewModel.userRisingSign != nil
    }

    private var personalizedTitle: String {
        if let name = viewModel.profile?.displayName, !name.isEmpty {
            return "Welcome back, \(name)"
        }
        return "Your practical astrology library"
    }

    private var filteredEntries: [AstropediaEntry] {
        guard !trimmedSearchText.isEmpty else { return [] }

        return libraryEntries.filter { entry in
            entry.searchText.localizedStandardContains(trimmedSearchText)
        }
        .prefix(8)
        .map { $0 }
    }

    private var suggestionTerms: [String] {
        let suggestions: [String] = ZodiacSign.allCases.map(\.displayName) + AstropediaTopic.allCases.map(\.title)

        guard !trimmedSearchText.isEmpty else {
            return Array(suggestions.prefix(6))
        }

        let filtered: [String] = suggestions.filter { suggestion in
            suggestion.localizedStandardContains(trimmedSearchText)
        }
        return Array(filtered.prefix(6))
    }

    private var libraryEntries: [AstropediaEntry] {
        ZodiacSign.allCases.flatMap { sign in
            AstropediaTopic.allCases.map { topic in
                entry(for: sign, topic: topic)
            }
        }
    }

    private var chartCards: [AstropediaCard] {
        guard let sun = viewModel.userSunSign,
              let moon = viewModel.userMoonSign,
              let rising = viewModel.userRisingSign else {
            return []
        }

        return [
            AstropediaCard(
                id: "sun-\(sun.rawValue)",
                title: "Sun in \(sun.displayName)",
                subtitle: "Your core self",
                iconName: CelestialRole.sun.iconName,
                accent: SimastryColor.gold,
                body: AstrologyTemplates.sunSign[sun.rawValue] ?? "Your center is gathering light."
            ),
            AstropediaCard(
                id: "moon-\(moon.rawValue)",
                title: "Moon in \(moon.displayName)",
                subtitle: "Your emotional world",
                iconName: CelestialRole.moon.iconName,
                accent: SimastryColor.celestialBlue,
                body: AstrologyTemplates.moonSign[moon.rawValue] ?? "Your heart speaks in tides."
            ),
            AstropediaCard(
                id: "rising-\(rising.rawValue)",
                title: "Rising in \(rising.displayName)",
                subtitle: "How people read you first",
                iconName: CelestialRole.rising.iconName,
                accent: SimastryColor.risingViolet,
                body: AstrologyTemplates.risingSign[rising.rawValue] ?? "Your presence leaves an immediate imprint."
            )
        ]
    }

    private var currentTopicCards: [AstropediaCard] {
        topicCards(for: focusedSign, topic: selectedTopic)
    }

    private var todayInsightTitle: String {
        guard let sign = viewModel.userSunSign ?? viewModel.userMoonSign ?? viewModel.userRisingSign else {
            return "Start with the sign that feels most important right now"
        }
        return "Today for \(sign.displayName)"
    }

    private var todayInsightBody: String {
        let sign: ZodiacSign = viewModel.userSunSign ?? viewModel.userMoonSign ?? viewModel.userRisingSign ?? focusedSign
        let dayIndex: Int = Calendar.current.component(.weekday, from: Date())

        switch dayIndex {
        case 1:
            return "Lead with your \(sign.element.rawValue) element today. \(communicationSummary(for: sign))"
        case 2:
            return "In love and friendship, \(loveSummary(for: sign))"
        case 3:
            return "If tension rises, \(conflictSummary(for: sign))"
        case 4:
            return "Your nervous system will thank you if you remember this: \(emotionalNeedsSummary(for: sign))"
        case 5:
            return "Your most magnetic trait today is simple: \(plainEnglishSummary(for: sign))"
        case 6:
            return "This is a strong day to read subtext before you answer. \(communicationSummary(for: sign))"
        default:
            return "Return to what feels true, grounded, and emotionally clean. \(emotionalNeedsSummary(for: sign))"
        }
    }

    private var compatibilityOverview: AstropediaCompatibilityOverview? {
        guard let userSun = viewModel.userSunSign else { return nil }

        let elementText: String = AstrologyTemplates.elementPairingText(
            element1: userSun.element.rawValue,
            element2: focusedSign.element.rawValue
        )

        let companionName: String? = AppConfig.expertAstrologersEnabled ? nil : viewModel.primaryCompanion?.name
        let companionSign: ZodiacSign? = AppConfig.expertAstrologersEnabled ? nil : viewModel.primaryCompanion.flatMap { ZodiacSign(rawValue: $0.sunSign) }
        let companionText: String?

        if let companionName, let companionSign {
            companionText = "With \(companionName)'s \(companionSign.displayName) energy in the app, your current dynamic leans \(AstrologyTemplates.elementPairingText(element1: userSun.element.rawValue, element2: companionSign.element.rawValue).lowercased())."
        } else {
            companionText = nil
        }

        return AstropediaCompatibilityOverview(
            title: "\(userSun.displayName) + \(focusedSign.displayName)",
            body: elementText,
            companionBody: companionText
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        if !trimmedSearchText.isEmpty {
                            searchResultsSection
                        } else {
                            todayInsightSection
                            chartSection
                            topicSection
                            signSection
                            focusedReadingSection
                            communicationGuidesSection
                            educationalSection
                            compatibilitySection
                            recentLookupsSection
                            nextStepSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Astropedia")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search signs, compatibility, or emotional patterns")
            )
            .searchSuggestions {
                ForEach(suggestionTerms, id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            }
            .task {
                guard !hasInitialized else { return }
                hasInitialized = true
                loadRecentLookups()
                initializeFromProfile()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("A S T R O P E D I A")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(4)

                Text(personalizedTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Less mystical overload, more clear answers you can actually use.")
                    .font(.subheadline)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(AstropediaTopic.allCases) { topic in
                        Button {
                            HapticManager.buttonPress()
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                selectedTopic = topic
                            }
                            recordLookup(sign: focusedSign, topic: topic)
                        } label: {
                            Label(topic.shortTitle, systemImage: topic.iconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedTopic == topic ? SimastryColor.midnight : SimastryColor.offWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(selectedTopic == topic ? topic.accent : .white.opacity(0.06), in: .capsule)
                                .overlay {
                                    Capsule()
                                        .stroke(selectedTopic == topic ? topic.accent.opacity(0.2) : .white.opacity(0.08), lineWidth: 1)
                                }
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private var todayInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Today’s insight",
                subtitle: "A reason to come back even when you only have thirty seconds."
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .foregroundStyle(SimastryColor.risingViolet)
                        .frame(width: 42, height: 42)
                        .background(SimastryColor.risingViolet.opacity(0.16), in: .rect(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(todayInsightTitle)
                            .font(.headline)
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(todayInsightBody)
                            .font(.subheadline)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(18)
            .tintedGlass(SimastryColor.risingViolet.opacity(0.12), cornerRadius: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SimastryColor.risingViolet.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Your chart in plain English",
                subtitle: hasProfileSigns ? "Open with your real placements, not abstract astrology jargon." : "Save your Sun, Moon, and Rising to unlock personalized guidance here."
            )

            if hasProfileSigns {
                VStack(spacing: 12) {
                    ForEach(chartCards) { card in
                        AstropediaCardView(card: card)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Astropedia becomes much more useful once it knows your placements.")
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))

                    Button {
                        HapticManager.buttonPress()
                        viewModel.selectedTab = .me
                    } label: {
                        Label("Complete my signs", systemImage: "person.crop.circle.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.midnight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SimastryColor.gold, in: .capsule)
                    }
                    .buttonStyle(SpringPressStyle())
                }
                .padding(18)
                .simastryGlass(cornerRadius: 20)
            }
        }
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Explore by question",
                subtitle: "Choose the lens first, then get the answer fast."
            )

            ViewThatFits {
                HStack(spacing: 12) {
                    ForEach(AstropediaTopic.allCases) { topic in
                        topicButton(topic)
                    }
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(AstropediaTopic.allCases) { topic in
                            topicButton(topic)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 0)
            }
        }
    }

    private var signSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Explore by sign",
                subtitle: "Pick the energy you want to understand better."
            )

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(ZodiacSign.allCases) { sign in
                        VStack(spacing: 8) {
                            ZodiacBadgeView(sign: sign, isSelected: focusedSign == sign, size: 52) {
                                withAnimation(.spring(SimastrySpring.smooth)) {
                                    focusedSign = sign
                                }
                                recordLookup(sign: sign, topic: selectedTopic)
                            }

                            Text(sign.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(focusedSign == sign ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                        }
                        .frame(width: 64)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private var focusedReadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "\(focusedSign.displayName) • \(selectedTopic.title)",
                subtitle: entry(for: focusedSign, topic: selectedTopic).subtitle
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry(for: focusedSign, topic: selectedTopic).title)
                        .font(.headline)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(entry(for: focusedSign, topic: selectedTopic).body)
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .goldGlassRect(cornerRadius: 22)

                ForEach(currentTopicCards) { card in
                    AstropediaCardView(card: card)
                }
            }
        }
    }

    private var educationalSection: some View {
        EducationalSectionsView()
    }

    private var communicationGuideAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(SimastrySpring.smooth)
    }

    private var communicationGuidesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("C O M M U N I C A T I O N  G U I D E S")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AstropediaColors.gold)
                    .tracking(3.2)

                Text("Inspired by Jaylen Brown’s leadership approach")
                    .font(.caption)
                    .foregroundStyle(AstropediaColors.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(hasRevealedCommunicationGuides ? 1 : 0)
            .offset(y: hasRevealedCommunicationGuides ? 0 : 12)
            .animation(communicationGuideAnimation.delay(reduceMotion ? 0 : 0.02), value: hasRevealedCommunicationGuides)

            LazyVGrid(columns: communicationGuideColumns, spacing: 12) {
                ForEach(ZodiacSign.allCases) { sign in
                    Button {
                        toggleCommunicationGuide(for: sign)
                    } label: {
                        CommunicationGuideSignCard(sign: sign, isSelected: selectedCommunicationGuideSign == sign)
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("\(sign.displayName) communication guide")
                    .accessibilityHint(selectedCommunicationGuideSign == sign ? "Hides the guide" : "Shows the guide")
                }
            }
            .opacity(hasRevealedCommunicationGuides ? 1 : 0)
            .offset(y: hasRevealedCommunicationGuides ? 0 : 16)
            .animation(communicationGuideAnimation.delay(reduceMotion ? 0 : 0.08), value: hasRevealedCommunicationGuides)

            if let selectedCommunicationGuideSign {
                CommunicationGuideView(sign: selectedCommunicationGuideSign)
                    .id(selectedCommunicationGuideSign)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .task {
            guard !hasRevealedCommunicationGuides else { return }
            hasRevealedCommunicationGuides = true
        }
    }

    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Compatibility snapshot",
                subtitle: "Make Astropedia useful across the rest of the app."
            )

            if let compatibilityOverview {
                VStack(alignment: .leading, spacing: 14) {
                    Label(compatibilityOverview.title, systemImage: "link")
                        .font(.headline)
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(compatibilityOverview.body)
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    if let companionBody = compatibilityOverview.companionBody {
                        Text(companionBody)
                            .font(.footnote)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .tintedGlass(SimastryColor.celestialBlue.opacity(0.12), cornerRadius: 22)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save your own signs first, then Astropedia can translate compatibility into something personal.")
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))

                    Button {
                        HapticManager.buttonPress()
                        viewModel.selectedTab = .me
                    } label: {
                        Label("Open Profile", systemImage: "person.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .simastryGlassPill()
                    }
                    .buttonStyle(SpringPressStyle())
                }
                .padding(18)
                .simastryGlass(cornerRadius: 22)
            }
        }
    }

    private var recentLookupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Recent lookups",
                subtitle: recentLookups.isEmpty ? "Your last searches and sign deep-dives will live here." : "Jump back into what you were decoding last."
            )

            if recentLookups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try a sign, then switch between communication, love, conflict, and emotional needs.")
                        .font(.subheadline)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.75))
                }
                .padding(18)
                .simastryGlass(cornerRadius: 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentLookups) { lookup in
                        Button {
                            HapticManager.buttonPress()
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                focusedSign = lookup.sign
                                selectedTopic = lookup.topic
                                searchText = ""
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZodiacIconView(sign: lookup.sign, size: 28, showsGlow: false)
                                    .frame(width: 42, height: 42)
                                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(lookup.sign.displayName) • \(lookup.topic.title)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(SimastryColor.offWhite)

                                    Text(lookup.date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(SimastryColor.mutedSilver)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(SimastryColor.gold)
                            }
                            .padding(16)
                            .simastryGlass(cornerRadius: 18)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
        }
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Use this next",
                subtitle: "Astropedia should feed the rest of the experience, not live in isolation."
            )

            ViewThatFits {
                HStack(spacing: 12) {
                    nextStepButton(
                        title: "Open Messages",
                        subtitle: "Take this sign dynamic into a conversation.",
                        iconName: "message.fill",
                        accent: SimastryColor.celestialBlue,
                        tabIndex: 2
                    )

                    nextStepButton(
                        title: AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Open Companions",
                        subtitle: AppConfig.expertAstrologersEnabled ? "Ask one specialist or compare all five traditions." : "Compare what you learned with your companion energy.",
                        iconName: "sparkles",
                        accent: SimastryColor.sunCoral,
                        tabIndex: 1,
                        opensExperts: AppConfig.expertAstrologersEnabled
                    )
                }

                VStack(spacing: 12) {
                    nextStepButton(
                        title: "Open Messages",
                        subtitle: "Take this sign dynamic into a conversation.",
                        iconName: "message.fill",
                        accent: SimastryColor.celestialBlue,
                        tabIndex: 2
                    )

                    nextStepButton(
                        title: AppConfig.expertAstrologersEnabled ? "Expert Astrologers" : "Open Companions",
                        subtitle: AppConfig.expertAstrologersEnabled ? "Ask one specialist or compare all five traditions." : "Compare what you learned with your companion energy.",
                        iconName: "sparkles",
                        accent: SimastryColor.sunCoral,
                        tabIndex: 1,
                        opensExperts: AppConfig.expertAstrologersEnabled
                    )
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AstropediaSectionHeader(
                title: "Search results",
                subtitle: filteredEntries.isEmpty ? "Try a sign name, love, conflict, or communication." : "Tap a result to jump straight into it."
            )

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No matches yet",
                    systemImage: "sparkle.magnifyingglass",
                    description: Text("Try Scorpio, Pisces, communication, love, or emotional needs.")
                )
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredEntries) { entry in
                        Button {
                            HapticManager.buttonPress()
                            withAnimation(.spring(SimastrySpring.smooth)) {
                                focusedSign = entry.sign
                                selectedTopic = entry.topic
                                searchText = ""
                            }
                            recordLookup(sign: entry.sign, topic: entry.topic)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label(entry.title, systemImage: entry.topic.iconName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(SimastryColor.offWhite)
                                    Spacer()
                                    ZodiacIconView(sign: entry.sign, size: 22, showsGlow: false)
                                }

                                Text(entry.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(SimastryColor.mutedSilver)

                                Text(entry.body)
                                    .font(.footnote)
                                    .foregroundStyle(SimastryColor.offWhite.opacity(0.76))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(16)
                            .simastryGlass(cornerRadius: 18)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
            }
        }
    }

    private func topicButton(_ topic: AstropediaTopic) -> some View {
        Button {
            HapticManager.buttonPress()
            withAnimation(.spring(SimastrySpring.smooth)) {
                selectedTopic = topic
            }
            recordLookup(sign: focusedSign, topic: topic)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: topic.iconName)
                    .font(.headline)
                    .foregroundStyle(selectedTopic == topic ? topic.accent : SimastryColor.offWhite)

                Text(topic.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite)
                    .multilineTextAlignment(.leading)

                Text(topic.prompt)
                    .font(.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(selectedTopic == topic ? topic.accent.opacity(0.12) : .white.opacity(0.05), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selectedTopic == topic ? topic.accent.opacity(0.4) : .white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(SpringPressStyle())
    }

    private func nextStepButton(
        title: String,
        subtitle: String,
        iconName: String,
        accent: Color,
        tabIndex: Int,
        opensExperts: Bool = false
    ) -> some View {
        Button {
            HapticManager.buttonPress()
            if opensExperts {
                viewModel.openAIAstrologists()
            } else {
                viewModel.selectedTab = AppTab(normalizing: tabIndex)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tintedGlass(accent.opacity(0.12), cornerRadius: 20)
        }
        .buttonStyle(SpringPressStyle())
    }

    private func toggleCommunicationGuide(for sign: ZodiacSign) {
        HapticManager.zodiacSelection()
        withAnimation(communicationGuideAnimation) {
            selectedCommunicationGuideSign = selectedCommunicationGuideSign == sign ? nil : sign
        }
    }

    private func initializeFromProfile() {
        if let sun = viewModel.userSunSign {
            focusedSign = sun
        }
        recordLookup(sign: focusedSign, topic: selectedTopic, shouldPersistImmediately: false)
    }

    private func recordLookup(
        sign: ZodiacSign,
        topic: AstropediaTopic,
        shouldPersistImmediately: Bool = true
    ) {
        let lookup = AstropediaLookup(id: UUID(), sign: sign, topic: topic, date: Date())
        recentLookups.removeAll { $0.sign == sign && $0.topic == topic }
        recentLookups.insert(lookup, at: 0)
        recentLookups = Array(recentLookups.prefix(6))

        guard shouldPersistImmediately else { return }
        saveRecentLookups()
    }

    private func loadRecentLookups() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentLookupsKey),
              let decoded = try? JSONDecoder().decode([AstropediaLookup].self, from: data) else {
            recentLookups = []
            return
        }
        recentLookups = decoded
    }

    private func saveRecentLookups() {
        guard let data = try? JSONEncoder().encode(recentLookups) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentLookupsKey)
    }

    private func entry(for sign: ZodiacSign, topic: AstropediaTopic) -> AstropediaEntry {
        AstropediaEntry(
            sign: sign,
            topic: topic,
            title: entryTitle(for: sign, topic: topic),
            subtitle: entrySubtitle(for: sign, topic: topic),
            body: entryBody(for: sign, topic: topic)
        )
    }

    private func entryTitle(for sign: ZodiacSign, topic: AstropediaTopic) -> String {
        switch topic {
        case .plainEnglish:
            return "\(sign.displayName) in plain English"
        case .communication:
            return "How \(sign.displayName) communicates"
        case .love:
            return "How \(sign.displayName) loves"
        case .conflict:
            return "How \(sign.displayName) handles conflict"
        case .emotionalNeeds:
            return "What \(sign.displayName) emotionally needs"
        }
    }

    private func entrySubtitle(for sign: ZodiacSign, topic: AstropediaTopic) -> String {
        switch topic {
        case .plainEnglish:
            return "A fast read on their personality, instincts, and vibe"
        case .communication:
            return "Useful when you want to understand texts, tone, and pacing"
        case .love:
            return "The attraction style, reassurance pattern, and green flags"
        case .conflict:
            return "How they protect themselves, react, and repair"
        case .emotionalNeeds:
            return "What helps them feel safe, seen, and regulated"
        }
    }

    private func entryBody(for sign: ZodiacSign, topic: AstropediaTopic) -> String {
        switch topic {
        case .plainEnglish:
            return plainEnglishSummary(for: sign)
        case .communication:
            return communicationSummary(for: sign)
        case .love:
            return loveSummary(for: sign)
        case .conflict:
            return conflictSummary(for: sign)
        case .emotionalNeeds:
            return emotionalNeedsSummary(for: sign)
        }
    }

    private func plainEnglishSummary(for sign: ZodiacSign) -> String {
        let sunText: String = AstrologyTemplates.sunSign[sign.rawValue] ?? "They move through life with a distinct cosmic signature."
        let risingText: String = AstrologyTemplates.risingSign[sign.rawValue] ?? "Their presence tends to speak before they do."
        return "\(sunText). \(risingText)"
    }

    private func communicationSummary(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "\(sign.displayName) tends to text quickly, say the direct thing, and trust momentum more than perfect wording. If the tone feels alive, they stay engaged."
        case .earth:
            return "\(sign.displayName) usually communicates with intention. They notice reliability, consistency, and whether your words line up with your actions."
        case .air:
            return "\(sign.displayName) often processes aloud. They like playful back-and-forth, mental chemistry, and messages that feel sharp, light, or curious."
        case .water:
            return "\(sign.displayName) reads emotional texture first. They hear what is underneath the words, not just the words themselves, and may pull back before they feel exposed."
        }
    }

    private func loveSummary(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "\(sign.displayName) falls for energy, courage, and chemistry. They want to feel chosen with enthusiasm, not managed cautiously from a distance."
        case .earth:
            return "\(sign.displayName) loves through steadiness. They trust devotion that is calm, embodied, and proven over time."
        case .air:
            return "\(sign.displayName) is drawn to wit, intrigue, and freedom. They open when love feels mentally alive rather than emotionally heavy too fast."
        case .water:
            return "\(sign.displayName) loves by bonding deeply. Emotional sincerity matters more than polish, and tenderness travels farther than performance."
        }
    }

    private func conflictSummary(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "\(sign.displayName) reacts fast when hurt, but the feeling often moves just as quickly. Clarity, honesty, and immediate repair work better than avoidance."
        case .earth:
            return "\(sign.displayName) can go quiet in conflict while deciding what is real. They respond best when the conversation is grounded, respectful, and solution-oriented."
        case .air:
            return "\(sign.displayName) may intellectualize tension before admitting the feeling. Give them room to talk it through without cornering them emotionally."
        case .water:
            return "\(sign.displayName) protects their inner world when conflict feels unsafe. Gentleness, reassurance, and emotional accountability matter more than winning the point."
        }
    }

    private func emotionalNeedsSummary(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "\(sign.displayName) needs room to move, express, and feel alive. Praise helps, but freedom and trust help more."
        case .earth:
            return "\(sign.displayName) needs rhythm, loyalty, and proof that the bond is real. Safety often comes from what is repeated, not what is promised once."
        case .air:
            return "\(sign.displayName) needs space to think and breathe. Emotional safety grows when conversation stays open, curious, and non-possessive."
        case .water:
            return "\(sign.displayName) needs softness, intuition, and emotional steadiness. They regulate through feeling understood, not rushed past what they feel."
        }
    }

    private func topicCards(for sign: ZodiacSign, topic: AstropediaTopic) -> [AstropediaCard] {
        switch topic {
        case .plainEnglish:
            return [
                AstropediaCard(
                    id: "plain-core-\(sign.rawValue)",
                    title: "Core personality",
                    subtitle: "Sun-coded",
                    iconName: "sun.max.fill",
                    accent: SimastryColor.gold,
                    body: AstrologyTemplates.sunSign[sign.rawValue] ?? "Their identity has a clear cosmic center."
                ),
                AstropediaCard(
                    id: "plain-heart-\(sign.rawValue)",
                    title: "Inner life",
                    subtitle: "Moon-coded lens",
                    iconName: "moon.fill",
                    accent: SimastryColor.celestialBlue,
                    body: AstrologyTemplates.moonSign[sign.rawValue] ?? "Their emotional life moves in its own rhythm."
                ),
                AstropediaCard(
                    id: "plain-presence-\(sign.rawValue)",
                    title: "First impression",
                    subtitle: "Rising-coded lens",
                    iconName: "sparkles",
                    accent: SimastryColor.risingViolet,
                    body: AstrologyTemplates.risingSign[sign.rawValue] ?? "People feel their presence before they fully understand it."
                )
            ]
        case .communication:
            return [
                AstropediaCard(
                    id: "communication-text-\(sign.rawValue)",
                    title: "How they text",
                    subtitle: "Pacing and tone",
                    iconName: "message.fill",
                    accent: SimastryColor.celestialBlue,
                    body: communicationSummary(for: sign)
                ),
                AstropediaCard(
                    id: "communication-silence-\(sign.rawValue)",
                    title: "What silence usually means",
                    subtitle: "Read the subtext",
                    iconName: "ellipsis.bubble",
                    accent: SimastryColor.sunCoral,
                    body: silenceMeaning(for: sign)
                ),
                AstropediaCard(
                    id: "communication-best-approach-\(sign.rawValue)",
                    title: "Best way to reach them",
                    subtitle: "What lands well",
                    iconName: "paperplane.fill",
                    accent: SimastryColor.gold,
                    body: bestApproach(for: sign)
                )
            ]
        case .love:
            return [
                AstropediaCard(
                    id: "love-attraction-\(sign.rawValue)",
                    title: "Attraction style",
                    subtitle: "What pulls them in",
                    iconName: "heart.fill",
                    accent: SimastryColor.sunCoral,
                    body: loveSummary(for: sign)
                ),
                AstropediaCard(
                    id: "love-green-flags-\(sign.rawValue)",
                    title: "Their green flags",
                    subtitle: "What healthy love looks like",
                    iconName: "checkmark.seal.fill",
                    accent: SimastryColor.celestialBlue,
                    body: greenFlags(for: sign)
                ),
                AstropediaCard(
                    id: "love-reassurance-\(sign.rawValue)",
                    title: "How to reassure them",
                    subtitle: "Make them feel chosen",
                    iconName: "hand.raised.fill",
                    accent: SimastryColor.gold,
                    body: reassuranceStyle(for: sign)
                )
            ]
        case .conflict:
            return [
                AstropediaCard(
                    id: "conflict-trigger-\(sign.rawValue)",
                    title: "What triggers them",
                    subtitle: "Where tension starts",
                    iconName: "flame.fill",
                    accent: SimastryColor.sunCoral,
                    body: conflictSummary(for: sign)
                ),
                AstropediaCard(
                    id: "conflict-repair-\(sign.rawValue)",
                    title: "How repair happens",
                    subtitle: "What actually helps",
                    iconName: "bandage.fill",
                    accent: SimastryColor.gold,
                    body: repairStyle(for: sign)
                ),
                AstropediaCard(
                    id: "conflict-avoid-\(sign.rawValue)",
                    title: "Avoid this move",
                    subtitle: "What escalates things",
                    iconName: "xmark.octagon.fill",
                    accent: SimastryColor.risingViolet,
                    body: conflictAvoidance(for: sign)
                )
            ]
        case .emotionalNeeds:
            return [
                AstropediaCard(
                    id: "needs-safety-\(sign.rawValue)",
                    title: "What creates safety",
                    subtitle: "Their calm point",
                    iconName: "shield.lefthalf.filled",
                    accent: SimastryColor.celestialBlue,
                    body: emotionalNeedsSummary(for: sign)
                ),
                AstropediaCard(
                    id: "needs-regulation-\(sign.rawValue)",
                    title: "How they regulate",
                    subtitle: "What restores them",
                    iconName: "moon.zzz.fill",
                    accent: SimastryColor.celestialBlue,
                    body: regulationStyle(for: sign)
                ),
                AstropediaCard(
                    id: "needs-love-language-\(sign.rawValue)",
                    title: "What tenderness looks like",
                    subtitle: "How care lands best",
                    iconName: "sparkles",
                    accent: SimastryColor.gold,
                    body: tendernessStyle(for: sign)
                )
            ]
        }
    }

    private func silenceMeaning(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Usually they are either living in the moment or cooling off. Silence is less about games and more about impulse moving elsewhere."
        case .earth:
            return "They are probably thinking carefully, protecting energy, or waiting until they know what they mean."
        case .air:
            return "They may be distracted, overstimulated, or unsure what version of the truth they want to say out loud."
        case .water:
            return "They are likely feeling more than they want to show and pulling inward until it feels emotionally safe again."
        }
    }

    private func bestApproach(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Be direct, playful, and alive. A message with confidence lands better than one that apologizes for existing."
        case .earth:
            return "Be clear, grounded, and dependable. Show that you mean what you say and will follow through."
        case .air:
            return "Bring wit, curiosity, and a little surprise. Give them something to bounce off mentally."
        case .water:
            return "Lead with softness and emotional intelligence. If they feel your sincerity, they will hear you."
        }
    }

    private func greenFlags(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "They make love feel bold, energizing, and honest. They usually show interest through initiative and visible enthusiasm."
        case .earth:
            return "They build trust slowly but steadily. Their love shows up in consistency, practical care, and reliability."
        case .air:
            return "They keep the connection fresh and mentally alive. They often express love through attention, conversation, and openness."
        case .water:
            return "They love with depth, memory, and emotional attunement. Their care tends to feel intimate and quietly loyal."
        }
    }

    private func reassuranceStyle(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Choose them clearly, celebrate them openly, and do not leave them guessing whether the energy is mutual."
        case .earth:
            return "Show up when you say you will. Consistency soothes them more than dramatic declarations."
        case .air:
            return "Reassure without caging them. Honest language and emotional transparency beat pressure every time."
        case .water:
            return "Gentle words, patience, and proof that you can stay present with their feelings go a long way."
        }
    }

    private func repairStyle(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Name what happened, own your part, and reconnect quickly. They usually prefer honest repair over slow, vague distance."
        case .earth:
            return "Give them time, then come back with steadiness. A grounded apology restores trust faster than emotional chaos."
        case .air:
            return "Talk it through clearly and let the conversation breathe. They repair through understanding as much as emotion."
        case .water:
            return "Repair begins once they feel safe enough to soften. Empathy matters before problem-solving."
        }
    }

    private func conflictAvoidance(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Do not patronize, belittle, or dampen their energy. They escalate when they feel dismissed."
        case .earth:
            return "Avoid inconsistency, emotional chaos, and pressure for instant answers. That usually hardens their walls."
        case .air:
            return "Do not corner them into one emotional script. They need room to think without being accused of not caring."
        case .water:
            return "Avoid coldness, harshness, or emotional invalidation. Once they feel unsafe, they retreat deep."
        }
    }

    private func regulationStyle(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Movement, momentum, and a sense of aliveness help them reset. They often regulate by doing."
        case .earth:
            return "Routine, touch, sleep, food, and environmental calm do a lot for them. They regulate through grounding."
        case .air:
            return "Conversation, perspective, and mental space help them return to themselves. They regulate through clarity."
        case .water:
            return "Privacy, emotional safety, music, rest, and softness restore them. They regulate through feeling and release."
        }
    }

    private func tendernessStyle(for sign: ZodiacSign) -> String {
        switch sign.element {
        case .fire:
            return "Tenderness looks like warmth, loyalty, and choosing them with full-hearted energy."
        case .earth:
            return "Tenderness looks like being dependable, patient, and physically or practically present."
        case .air:
            return "Tenderness looks like listening closely, making room for their mind, and keeping things emotionally breathable."
        case .water:
            return "Tenderness looks like intuition, softness, and staying kind when they are at their most vulnerable."
        }
    }
}

private struct AstropediaSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(SimastryColor.offWhite)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AstropediaCardView: View {
    let card: AstropediaCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: card.iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(card.accent)
                    .frame(width: 36, height: 36)
                    .background(card.accent.opacity(0.14), in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SimastryColor.offWhite)

                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Spacer(minLength: 0)
            }

            Text(card.body)
                .font(.subheadline)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
    }
}

private struct CommunicationGuideSignCard: View {
    let sign: ZodiacSign
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZodiacIconView(sign: sign, size: 38, showsGlow: isSelected)
                .frame(width: 52, height: 52)
                .background(sign.color.opacity(isSelected ? 0.22 : 0.12), in: .rect(cornerRadius: 18))

            Text(sign.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sign.color)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .simastryGlass(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? sign.color.opacity(0.45) : .white.opacity(0.08), lineWidth: 1)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

nonisolated enum AstropediaTopic: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case plainEnglish = "plain_english"
    case communication = "communication"
    case love = "love"
    case conflict = "conflict"
    case emotionalNeeds = "emotional_needs"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plainEnglish:
            return "Plain English"
        case .communication:
            return "Communication"
        case .love:
            return "Love"
        case .conflict:
            return "Conflict"
        case .emotionalNeeds:
            return "Emotional Needs"
        }
    }

    var shortTitle: String {
        switch self {
        case .plainEnglish:
            return "My Signs"
        case .communication:
            return "Communication"
        case .love:
            return "Love"
        case .conflict:
            return "Conflict"
        case .emotionalNeeds:
            return "Needs"
        }
    }

    var prompt: String {
        switch self {
        case .plainEnglish:
            return "Who are they, fast?"
        case .communication:
            return "How do they text?"
        case .love:
            return "How do they love?"
        case .conflict:
            return "How do they react when hurt?"
        case .emotionalNeeds:
            return "What makes them feel safe?"
        }
    }

    var iconName: String {
        switch self {
        case .plainEnglish:
            return "sparkles"
        case .communication:
            return "message.fill"
        case .love:
            return "heart.fill"
        case .conflict:
            return "flame.fill"
        case .emotionalNeeds:
            return "moon.stars.fill"
        }
    }

    var accent: Color {
        switch self {
        case .plainEnglish:
            return Color(red: 212/255, green: 175/255, blue: 55/255)
        case .communication:
            return Color(red: 74/255, green: 144/255, blue: 217/255)
        case .love:
            return Color(red: 232/255, green: 132/255, blue: 90/255)
        case .conflict:
            return Color(red: 192/255, green: 132/255, blue: 216/255)
        case .emotionalNeeds:
            return Color(red: 74/255, green: 144/255, blue: 217/255)
        }
    }
}

nonisolated struct AstropediaEntry: Identifiable, Hashable, Sendable {
    let sign: ZodiacSign
    let topic: AstropediaTopic
    let title: String
    let subtitle: String
    let body: String

    var id: String {
        "\(sign.rawValue)-\(topic.rawValue)"
    }

    var searchText: String {
        [sign.displayName, topic.title, title, subtitle, body].joined(separator: " ")
    }
}

nonisolated struct AstropediaLookup: Codable, Identifiable, Sendable {
    let id: UUID
    let sign: ZodiacSign
    let topic: AstropediaTopic
    let date: Date
}

struct AstropediaCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let accent: Color
    let body: String
}

struct AstropediaCompatibilityOverview {
    let title: String
    let body: String
    let companionBody: String?
}
