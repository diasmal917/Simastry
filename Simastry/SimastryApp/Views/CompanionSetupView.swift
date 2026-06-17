import SwiftUI

struct CompanionSetupView: View {
    @Bindable var viewModel: AppViewModel
    @State private var setupStep: Int = 0
    @State private var appeared: Bool = false
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
            withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                appeared = true
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
                    title: "Shape your \(viewModel.selectedMode.displayName.lowercased())",
                    subtitle: "Pick their cosmic makeup now, then name and style them in the next two moments."
                )

                stageStrip(activeStep: 0)
                    .padding(.horizontal, 20)

                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("Start with their energy")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(SimastryColor.offWhite)
                            .multilineTextAlignment(.center)

                        Text("You can let fate decide or choose each sign yourself.")
                            .font(.system(size: 14))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        let signs = randomCompanionSigns()
                        viewModel.companionSunSign = signs.0
                        viewModel.companionMoonSign = signs.1
                        viewModel.companionRisingSign = signs.2
                        HapticManager.signConfirmed()
                        withAnimation(.spring(SimastrySpring.smooth)) {
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
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(SimastryColor.offWhite)

                                Text("We'll generate a balanced cosmic blend instantly.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(SimastryColor.mutedSilver)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(SimastryColor.gold)
                        }
                        .padding(18)
                        .goldGlassRect(cornerRadius: 22)
                    }
                    .buttonStyle(SpringPressStyle())

                    Text("or choose each sign below")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SimastryColor.deepMuted)
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(.spring(SimastrySpring.smooth), value: appeared)

                CompanionSignPicker(viewModel: viewModel) {
                    withAnimation(.spring(SimastrySpring.smooth)) {
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
                    .animation(.spring(SimastrySpring.smooth).delay(0.05), value: appeared)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.system(size: 13, weight: .semibold))
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
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                    .simastryGlass(cornerRadius: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    }

                    if !nameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(nameSuggestions, id: \.self) { name in
                                    Button(action: {
                                        viewModel.companionName = name
                                    }) {
                                        Text(name)
                                            .font(.system(size: 14, weight: .medium))
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
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            setupStep = 2
                        }
                    }

                    SecondaryButton(title: "Back") {
                        withAnimation(.spring(SimastrySpring.smooth)) {
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
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(SimastryColor.offWhite)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .simastryGlass(cornerRadius: 16)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(viewModel.companionAppearance == style ? SimastryColor.gold : .white.opacity(0.06), lineWidth: viewModel.companionAppearance == style ? 2 : 1)
                            }
                            .scaleEffect(viewModel.companionAppearance == style ? 1.03 : 1.0)
                            .animation(.spring(SimastrySpring.bouncy), value: viewModel.companionAppearance)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    GoldButton("Bring \(viewModel.companionName.isEmpty ? "Them" : viewModel.companionName) to Life") {
                        viewModel.homeSetupPhase = .soulCreation
                    }

                    SecondaryButton(title: "Back") {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            setupStep = 1
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
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

    private func stageStrip(activeStep: Int) -> some View {
        HStack(spacing: 8) {
            stagePill(title: "Signs", isActive: activeStep == 0, isComplete: activeStep > 0)
            stagePill(title: "Name", isActive: activeStep == 1, isComplete: activeStep > 1)
            stagePill(title: "Style", isActive: activeStep == 2, isComplete: false)
        }
    }

    private func stagePill(title: String, isActive: Bool, isComplete: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isActive || isComplete ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(isActive ? SimastryColor.gold : (isComplete ? SimastryColor.offWhite.opacity(0.82) : .white.opacity(0.06)), in: .capsule)
    }

    private var previewCard: some View {
        VStack(spacing: 14) {
            GlossyOrbView(
                signColors: companionPreviewColors,
                state: .idle,
                size: 72
            )

            VStack(spacing: 4) {
                Text(viewModel.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your future companion" : viewModel.companionName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SimastryColor.offWhite)

                Text(viewModel.selectedMode.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SimastryColor.gold)
            }

            HStack(spacing: 12) {
                previewBadge(role: .sun, sign: viewModel.companionSunSign)
                previewBadge(role: .moon, sign: viewModel.companionMoonSign)
                previewBadge(role: .rising, sign: viewModel.companionRisingSign)
            }
        }
        .padding(20)
        .goldGlassRect(cornerRadius: 26)
    }

    private var companionPreviewColors: [Color] {
        [
            viewModel.companionSunSign?.color ?? SimastryColor.gold,
            viewModel.companionMoonSign?.color ?? SimastryColor.celestialBlue
        ]
    }

    private func previewBadge(role: CelestialRole, sign: ZodiacSign?) -> some View {
        VStack(spacing: 6) {
            CelestialRoleIcon(role: role, size: 28)

            Text(sign?.glyph ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SimastryColor.offWhite)

            Text(role.displayName)
                .font(.system(size: 11, weight: .medium))
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
            return "Give your romantic match a name that already feels magnetic."
        case .bestie:
            return "Pick something warm, easy, and instantly familiar."
        case .simulateAnyone:
            return "Name the person or archetype you want to explore."
        }
    }

    private var nameSuggestions: [String] {
        switch viewModel.selectedMode {
        case .soulmate:
            return ["Aria", "Luna", "Kai", "Zara", "Orion", "Nova"]
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

    private let roles: [CelestialRole] = [.sun, .moon, .rising]

    var body: some View {
        let role = roles[step]

        VStack(spacing: 20) {
            VStack(spacing: 8) {
                CelestialRoleIcon(role: role, size: 56)

                Text("Their \(role.displayName) Sign")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(role.accentColor)

                Text(prompt(for: role))
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(Array(roles.enumerated()), id: \.offset) { index, item in
                    Text(item.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index <= step ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.72))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(index <= step ? item.accentColor : .white.opacity(0.06), in: .capsule)
                }
            }
            .padding(.horizontal, 20)

            ZodiacGridView(selectedSign: companionBinding(step))

            VStack(spacing: 12) {
                GoldButton(step < 2 ? "Continue" : "Continue to Name", isEnabled: companionBinding(step).wrappedValue != nil) {
                    if step < 2 {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            step += 1
                        }
                    } else {
                        onComplete()
                    }
                }

                if step > 0 {
                    SecondaryButton(title: "Back") {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            step -= 1
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 22)
        .goldGlassRect(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(role.accentColor.opacity(0.14), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .id(step)
    }

    private func prompt(for role: CelestialRole) -> String {
        switch role {
        case .sun:
            return "Choose the energy they lead with."
        case .moon:
            return "Pick the emotional tone beneath the surface."
        case .rising:
            return "Choose the first impression they leave behind."
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
