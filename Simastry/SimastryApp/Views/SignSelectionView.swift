import SwiftUI

struct SignSelectionView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedPath: Int = 0
    @State private var currentStep: Int = 0
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var birthplace: String = ""
    @State private var birthTime: Date = Date()
    @State private var isBirthTimeUnknown: Bool = false
    @State private var showSignReveal: Bool = false
    @State private var appeared: Bool = false
    @FocusState private var focusedField: SignInputField?

    private let roles: [CelestialRole] = [.sun, .moon, .rising]

    private enum SignInputField: Hashable {
        case birthplace
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            if showSignReveal {
                SignRevealView(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                mainContent
            }
        }
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                appeared = true
            }
        }
        .onChange(of: selectedPath) { _, _ in
            currentStep = 0
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                OnboardingProgressView(
                    eyebrow: "Discover",
                    title: selectedPath == 0 ? "Tell us your big three" : "Let us calculate your big three",
                    subtitle: selectedPath == 0
                        ? "Choose your Sun, Moon, and Rising signs directly if you already know them."
                        : "Share a few birth details and we'll turn them into your cosmic starting point.",
                    step: 2,
                    totalSteps: 3,
                    labels: ["Path", "Signs", "Companion"]
                )
                .padding(.horizontal, 20)

                pathCard
                    .padding(.horizontal, 20)

                if selectedPath == 0 {
                    knowMySignsPath
                } else {
                    calculatePath
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(SimastrySpring.smooth), value: appeared)
    }

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Sign Path", selection: $selectedPath) {
                Text("I Know My Signs").tag(0)
                Text("Calculate For Me").tag(1)
            }
            .pickerStyle(.segmented)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selectedPath == 0 ? "sparkles.rectangle.stack" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .padding(.top, 2)

                Text(selectedPath == 0
                    ? "Fastest route: choose each sign yourself and reveal your reading right away."
                    : "Your birth details stay private and are only used to estimate your signs and improve your reading.")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var knowMySignsPath: some View {
        let role = roles[currentStep]

        return VStack(spacing: 24) {
            signStepStrip
                .padding(.horizontal, 20)

            VStack(spacing: 18) {
                CelestialRoleIcon(role: role, size: 68)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text("Your \(role.displayName) Sign")
                        .font(SimastryFont.titleLarge)
                        .foregroundStyle(role.accentColor)

                    Text(role.subtitle)
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                Text(selectionPrompt(for: role))
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(22)
            .padding(.bottom, 8)
            .goldGlassRect(cornerRadius: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(role.accentColor.opacity(0.18), lineWidth: 1)
            }
            .padding(.horizontal, 20)

            ZodiacGridView(selectedSign: bindingForStep(currentStep))

            VStack(spacing: 12) {
                GoldButton(currentStep < 2 ? "Continue" : "Reveal My Signs", isEnabled: bindingForStep(currentStep).wrappedValue != nil) {
                    if currentStep < 2 {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            currentStep += 1
                        }
                        HapticManager.signConfirmed()
                    } else {
                        HapticManager.signConfirmed()
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            showSignReveal = true
                        }
                    }
                }

                if currentStep > 0 {
                    SecondaryButton(title: "Back") {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            currentStep -= 1
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .id(currentStep)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }

    private var signStepStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(roles.enumerated()), id: \.offset) { index, role in
                VStack(spacing: 8) {
                    Text(role.displayName)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(index <= currentStep ? SimastryColor.midnight : SimastryColor.offWhite.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(index <= currentStep ? role.accentColor : .white.opacity(0.06), in: .capsule)

                    Circle()
                        .fill(index == currentStep ? role.accentColor : SimastryColor.offWhite.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private var calculatePath: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Why birth time matters")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                } icon: {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(SimastryColor.gold)
                }

                Text("Birth time helps estimate your Rising sign. If you don't know it yet, you can still continue and refine it later.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .simastryGlass(cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 16) {
                inputCard(role: .sun, title: "Birthday") {
                    DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(SimastryColor.gold)
                }

                inputCard(role: .moon, title: "Birthplace") {
                    TextField("City, Country", text: $birthplace)
                        .focused($focusedField, equals: .birthplace)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SimastryColor.offWhite)

                    Text("Optional for now — add it when you're ready for a more refined chart.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.deepMuted)
                }

                inputCard(role: .rising, title: "Birth Time") {
                    Toggle("I don't know my birth time yet", isOn: $isBirthTimeUnknown)
                        .tint(SimastryColor.gold)
                        .foregroundStyle(SimastryColor.offWhite)

                    DatePicker("Birth Time", selection: $birthTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(SimastryColor.gold)
                        .disabled(isBirthTimeUnknown)
                        .opacity(isBirthTimeUnknown ? 0.45 : 1)

                    Text(isBirthTimeUnknown
                        ? "We'll choose a flexible default for now."
                        : "The closer this is, the more accurate your Rising sign will feel.")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.deepMuted)
                }
            }
            .padding(.horizontal, 20)

            GoldButton("Calculate My Signs") {
                viewModel.userSunSign = ZodiacSign.fromDate(birthday)
                let moonOptions = suggestMoonSigns(for: viewModel.userSunSign ?? .aries)
                viewModel.userMoonSign = moonOptions.first
                let risingOptions = suggestRisingSigns(for: viewModel.userSunSign ?? .aries)
                viewModel.userRisingSign = risingOptions.first
                focusedField = nil
                HapticManager.signConfirmed()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    showSignReveal = true
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func inputCard<Content: View>(role: CelestialRole, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CelestialRoleIcon(role: role, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(role.accentColor)

                    Text(inputSubtitle(for: role))
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }

            content()
        }
        .padding(16)
        .simastryGlass(cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(role.accentColor.opacity(0.14), lineWidth: 1)
        }
    }

    private func selectionPrompt(for role: CelestialRole) -> String {
        switch role {
        case .sun:
            "Choose the sign that feels most like your core self."
        case .moon:
            "Pick the sign that matches your inner emotional weather."
        case .rising:
            "Choose the sign people meet first when they encounter your energy."
        }
    }

    private func inputSubtitle(for role: CelestialRole) -> String {
        switch role {
        case .sun:
            "This powers your Sun sign"
        case .moon:
            "Helps refine your chart later"
        case .rising:
            "Improves your Rising sign"
        }
    }

    private func bindingForStep(_ step: Int) -> Binding<ZodiacSign?> {
        switch step {
        case 0:
            return $viewModel.userSunSign
        case 1:
            return $viewModel.userMoonSign
        case 2:
            return $viewModel.userRisingSign
        default:
            return $viewModel.userSunSign
        }
    }

    private func suggestMoonSigns(for sun: ZodiacSign) -> [ZodiacSign] {
        let water: [ZodiacSign] = [.cancer, .scorpio, .pisces]
        let others = ZodiacSign.allCases.filter { !water.contains($0) && $0 != sun }
        return Array((water + others).prefix(3))
    }

    private func suggestRisingSigns(for sun: ZodiacSign) -> [ZodiacSign] {
        let air: [ZodiacSign] = [.libra, .gemini, .aquarius]
        let others = ZodiacSign.allCases.filter { !air.contains($0) && $0 != sun }
        return Array((air + others).prefix(3))
    }
}
