import SwiftUI

struct CompanionSetupView: View {
    @Bindable var viewModel: AppViewModel
    @State private var setupStep: Int = 0
    @State private var appeared: Bool = false
    @State private var showThirdPartyConsent: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isNamingFocused: Bool

    var body: some View {
        ZStack {
            CelestialBackground()

            switch setupStep {
            case 0:
                companionSignsStep
            case 1:
                companionNamingStep
            case 2:
                companionAppearanceStep
            default:
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNamingFocused = false
                }
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                    appeared = true
                }
            }
        }
        .onChange(of: setupStep) { _, newValue in
            isNamingFocused = newValue == 1
        }
    }

    private var companionSignsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                progressHeader(
                    title: "Shape your \(shapeTitleNoun)",
                    subtitle: "Pick their Sun, Moon, and Rising profile, then name and style your guide's voice."
                )

                stageStrip(activeStep: 0)
                    .padding(.horizontal, 20)

                creationMethodCard
                    .padding(.horizontal, 20)

                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("Start with their placement logic")
                            .font(SimastryFont.titleLarge)
                            .foregroundStyle(SimastryColor.offWhite)
                            .multilineTextAlignment(.center)

                        Text("Choose the companion's chart lens yourself or generate a balanced Sun, Moon, and Rising blend.")
                            .font(SimastryFont.bodySmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        let signs = randomCompanionSigns()
                        viewModel.companionSunSign = signs.0
                        viewModel.companionMoonSign = signs.1
                        viewModel.companionRisingSign = signs.2
                        HapticManager.signConfirmed()
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            setupStep = 1
                        }
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(SimastryColor.gold.opacity(0.18))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(SimastryColor.gold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Surprise Me")
                                    .font(SimastryFont.titleSmall)
                                    .foregroundStyle(SimastryColor.offWhite)

                                Text("We'll generate a balanced placement profile instantly.")
                                    .font(SimastryFont.labelMedium)
                                    .foregroundStyle(SimastryColor.mutedSilver)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(SimastryColor.gold)
                        }
                        .padding(18)
                        .surfaceCard(cornerRadius: 22, accent: SimastryColor.gold.opacity(0.8))
                    }
                    .buttonStyle(SpringPressStyle())

                    Text("or choose each sign below")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.deepMuted)
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth), value: appeared)

                CompanionSignPicker(viewModel: viewModel) {
                    withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                        setupStep = 1
                    }
                }

                SecondaryButton(title: "Choose a different path") {
                    viewModel.homeSetupPhase = .modeSelection
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var companionNamingStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                progressHeader(
                    title: "Give them a name",
                    subtitle: namingSubtitle
                )

                stageStrip(activeStep: 1)
                    .padding(.horizontal, 20)

                previewCard
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth).delay(0.05), value: appeared)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(SimastryFont.labelLarge)
                            .foregroundStyle(SimastryColor.mutedSilver)

                        TextField("Type a name", text: $viewModel.companionName)
                            .focused($isNamingFocused)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit {
                                isNamingFocused = false
                            }
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .tint(SimastryColor.gold)
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isNamingFocused ? SimastryColor.gold.opacity(0.5) : .white.opacity(0.14),
                                lineWidth: 1
                            )
                    }

                    if !nameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(nameSuggestions, id: \.self) { name in
                                    Button(action: {
                                        viewModel.companionName = name
                                    }) {
                                        Text(name)
                                            .font(SimastryFont.labelLarge)
                                            .foregroundStyle(SimastryColor.offWhite)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .simastryGlassPill()
                                    }
                                    .buttonStyle(SpringPressStyle())
                                }
                            }
                        }
                        .contentMargins(.horizontal, 0)
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    GoldButton("Continue", isEnabled: !viewModel.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        isNamingFocused = false
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            setupStep = 2
                        }
                    }

                    SecondaryButton(title: "Back") {
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            setupStep = 0
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var companionAppearanceStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                progressHeader(
                    title: "Choose their essence",
                    subtitle: "Pick the visual tone that feels most like the companion you're about to meet."
                )

                stageStrip(activeStep: 2)
                    .padding(.horizontal, 20)

                previewCard
                    .padding(.horizontal, 20)

                let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AppearanceStyle.allCases) { style in
                        Button(action: {
                            viewModel.companionAppearance = style
                            HapticManager.zodiacSelection()
                        }) {
                            VStack(spacing: 10) {
                                appearanceOrb(for: style)

                                Text(style.displayName)
                                    .font(SimastryFont.labelLarge)
                                    .foregroundStyle(SimastryColor.offWhite)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .surfaceCard(cornerRadius: 16)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(viewModel.companionAppearance == style ? SimastryColor.gold : .clear, lineWidth: 1.6)
                            }
                            .scaleEffect(viewModel.companionAppearance == style ? 1.03 : 1.0)
                            .animation(reduceMotion ? .default : .spring(SimastrySpring.bouncy), value: viewModel.companionAppearance)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    GoldButton("Bring \(viewModel.companionName.isEmpty ? "Them" : viewModel.companionName) to Life") {
                        if !viewModel.hasAcceptedThirdPartyConsent {
                            showThirdPartyConsent = true
                        } else {
                            viewModel.homeSetupPhase = .soulCreation
                        }
                    }

                    SecondaryButton(title: "Back") {
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            setupStep = 1
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .alert("About Adding People", isPresented: $showThirdPartyConsent) {
            Button("I Understand") {
                viewModel.acceptThirdPartyConsent()
                viewModel.homeSetupPhase = .soulCreation
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You're about to enter information about another person. Please make sure you have their knowledge or permission to use their birth details in this app. Their data is stored privately and never shared.")
        }
    }

    /// Mode name lowercased for mid-sentence use, preserving the "AI" acronym.
    private var shapeTitleNoun: String {
        viewModel.selectedMode.displayName
            .lowercased()
            .replacingOccurrences(of: "ai ", with: "AI ")
    }

    private func progressHeader(title: String, subtitle: String) -> some View {
        OnboardingProgressView(
            eyebrow: "Create",
            title: title,
            subtitle: subtitle,
            step: 3,
            totalSteps: 3,
            labels: ["Path", "Signs", "Companion"]
        )
        .padding(.horizontal, 20)
    }

    private var creationMethodCard: some View {
        MethodLayerPanel(
            title: "Companion method",
            summary: "These placements shape how the companion interprets a conversation: Sun for core drive, Moon for emotional pattern, Rising for first instinct.",
            signals: [
                MethodSignal(
                    label: "Sun",
                    detail: "Core drive",
                    systemImage: "sun.max.fill",
                    tint: SimastryColor.sunCoral
                ),
                MethodSignal(
                    label: "Moon",
                    detail: "Emotional pattern",
                    systemImage: "moon.stars.fill",
                    tint: SimastryColor.celestialBlue
                ),
                MethodSignal(
                    label: "Rising",
                    detail: "First instinct",
                    systemImage: "sparkles",
                    tint: SimastryColor.risingViolet
                )
            ],
            footer: "The companion is fictional. Its voice stays anchored to traditional sign logic and your conversation context.",
            accent: SimastryColor.gold
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth).delay(0.04), value: appeared)
    }

    private func stageStrip(activeStep: Int) -> some View {
        HStack(spacing: 8) {
            stagePill(title: "Signs", isActive: activeStep == 0, isComplete: activeStep > 0)
            stagePill(title: "Name", isActive: activeStep == 1, isComplete: activeStep > 1)
            stagePill(title: "Style", isActive: activeStep == 2, isComplete: false)
        }
    }

    private func stagePill(title: String, isActive: Bool, isComplete: Bool) -> some View {
        let isReached = isActive || isComplete

        return HStack(spacing: 5) {
            Circle()
                .fill(isReached ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.14)))
                .frame(width: 6, height: 6)

            Text(title)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(isReached ? SimastryColor.offWhite : SimastryColor.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(isReached ? AnyShapeStyle(SimastryColor.gold.opacity(0.12)) : AnyShapeStyle(Color.white.opacity(0.05)), in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(isActive ? SimastryColor.gold.opacity(0.45) : (isComplete ? SimastryColor.gold.opacity(0.25) : .white.opacity(0.07)), lineWidth: isActive ? 1 : 0.6)
        }
    }

    private var previewCard: some View {
        VStack(spacing: 14) {
            previewAvatar

            VStack(spacing: 4) {
                Text(viewModel.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your future companion" : viewModel.companionName)
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text(viewModel.selectedMode.displayName)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.gold)
            }

            HStack(spacing: 12) {
                previewBadge(role: .sun, sign: viewModel.companionSunSign)
                previewBadge(role: .moon, sign: viewModel.companionMoonSign)
                previewBadge(role: .rising, sign: viewModel.companionRisingSign)
            }
        }
        .padding(20)
        .heroGlass(SimastryColor.gold, cornerRadius: 26)
    }

    /// Portrait of the cast guide this companion will resolve to (same
    /// sun-sign matching the rest of the app uses), so the preview shows a
    /// face instead of an abstract orb.
    @ViewBuilder
    private var previewAvatar: some View {
        let sunSign = viewModel.companionSunSign
        let matched = sunSign.flatMap { sign in
            FactoryCompanionCatalog.all.first { $0.sign == sign && $0.gender == "Female" }
        }

        if let matched {
            Image(matched.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76, alignment: .top)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(
                        (sunSign?.color ?? SimastryColor.gold).opacity(0.7),
                        lineWidth: 1.6
                    )
                }
                .shadow(color: (sunSign?.color ?? SimastryColor.gold).opacity(0.30), radius: 14, y: 5)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                sunSign?.color.opacity(0.5) ?? SimastryColor.gold.opacity(0.4),
                                SimastryColor.surfaceElevated
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle().strokeBorder(SimastryColor.gold.opacity(0.4), lineWidth: 1.2)
                    }

                if let initial = viewModel.companionName.trimmingCharacters(in: .whitespacesAndNewlines).first {
                    Text(String(initial).uppercased())
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                } else {
                    Image(systemName: SimastryIcon.astrologers)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SimastryColor.goldLight)
                }
            }
        }
    }

    private func previewBadge(role: CelestialRole, sign: ZodiacSign?) -> some View {
        VStack(spacing: 6) {
            CelestialRoleIcon(role: role, size: 28)

            if let sign {
                ZodiacIconView(sign: sign, size: 22, showsGlow: false)
            } else {
                Text("-")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            Text(role.displayName)
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
    }

    private func appearanceOrb(for style: AppearanceStyle) -> some View {
        let primary = style.primaryColor
        let secondary = style.secondaryColor

        return Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: primary.r, green: primary.g, blue: primary.b),
                        Color(red: secondary.r, green: secondary.g, blue: secondary.b)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
            .shadow(color: SimastryColor.gold.opacity(0.18), radius: 10)
    }

    private var namingSubtitle: String {
        switch viewModel.selectedMode {
        case .soulmate:
            return "Give your AI guide a name that feels magnetic, warm, and easy to talk to."
        case .bestie:
            return "Pick something warm, easy, and instantly familiar."
        case .simulateAnyone:
            return "Name the person or archetype you want to explore."
        }
    }

    private var nameSuggestions: [String] {
        switch viewModel.selectedMode {
        case .soulmate:
            return ["Nadia", "Luna", "Kai", "Zara", "Orion", "Nova"]
        case .bestie:
            return ["Sam", "Alex", "Quinn", "Jordan", "River", "Sky"]
        case .simulateAnyone:
            return []
        }
    }

    private func randomCompanionSigns() -> (ZodiacSign, ZodiacSign, ZodiacSign) {
        let allSigns = ZodiacSign.allCases
        return (
            allSigns.randomElement() ?? .aries,
            allSigns.randomElement() ?? .aries,
            allSigns.randomElement() ?? .aries
        )
    }
}

struct CompanionSignPicker: View {
    @Bindable var viewModel: AppViewModel
    let onComplete: () -> Void
    @State private var step: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let roles: [CelestialRole] = [.sun, .moon, .rising]

    var body: some View {
        let role = roles[step]

        VStack(spacing: 20) {
            VStack(spacing: 8) {
                CelestialRoleIcon(role: role, size: 56)

                Text("Their \(role.displayName) Sign")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(role.accentColor)

                Text(prompt(for: role))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(Array(roles.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(index <= step ? item.accentColor : Color.white.opacity(0.14))
                            .frame(width: 6, height: 6)

                        Text(item.displayName)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(index <= step ? SimastryColor.offWhite : SimastryColor.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(index <= step ? AnyShapeStyle(item.accentColor.opacity(0.14)) : AnyShapeStyle(Color.white.opacity(0.05)), in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(index == step ? item.accentColor.opacity(0.5) : (index < step ? item.accentColor.opacity(0.25) : .white.opacity(0.07)), lineWidth: index == step ? 1 : 0.6)
                    }
                }
            }
            .padding(.horizontal, 20)

            ZodiacGridView(selectedSign: companionBinding(step), roleName: role.displayName)

            VStack(spacing: 12) {
                GoldButton(step < 2 ? "Continue" : "Continue to Name", isEnabled: companionBinding(step).wrappedValue != nil) {
                    if step < 2 {
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            step += 1
                        }
                    } else {
                        onComplete()
                    }
                }

                if step > 0 {
                    SecondaryButton(title: "Back") {
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                            step -= 1
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 22)
        .heroGlass(role.accentColor, cornerRadius: 28)
        .padding(.horizontal, 20)
        .id(step)
    }

    private func prompt(for role: CelestialRole) -> String {
        switch role {
        case .sun:
            return "Choose their core drive and directness."
        case .moon:
            return "Pick the emotional pattern beneath the surface."
        case .rising:
            return "Choose their first instinct and social tone."
        }
    }

    private func companionBinding(_ step: Int) -> Binding<ZodiacSign?> {
        switch step {
        case 0:
            return $viewModel.companionSunSign
        case 1:
            return $viewModel.companionMoonSign
        case 2:
            return $viewModel.companionRisingSign
        default:
            return $viewModel.companionSunSign
        }
    }
}
