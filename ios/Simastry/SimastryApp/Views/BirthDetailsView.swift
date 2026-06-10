import SwiftUI
import MapKit

struct BirthDetailsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var currentStep: Int = 0
    @State private var isCalculating: Bool = false
    @State private var displayName: String = ""
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var birthTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var birthplace: String = ""
    @State private var appeared: Bool = false
    @State private var birthTimeUnknown: Bool = false
    @State private var showSuggestions: Bool = false
    @State private var selectedFromSuggestion: Bool = false
    @StateObject private var locationCompleter = LocationSearchCompleter()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var birthplaceFocused: Bool
    @FocusState private var nameFocused: Bool
    private let birthplaceGeocodingService = BirthplaceGeocodingService()

    private let totalSteps = 4

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var firstName: String {
        trimmedName.components(separatedBy: " ").first ?? trimmedName
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)

                stepProgress
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Spacer()

                Group {
                    switch currentStep {
                    case 0: nameStep
                    case 1: birthdayStep
                    case 2: birthTimeStep
                    case 3: birthplaceStep
                    default: EmptyView()
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
                .id(currentStep)

                Spacer()

                privacyNote
                    .padding(.bottom, 12)

                if isCalculating {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(SimastryColor.gold)
                        Text("Calculating your birth chart...")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                } else {
                    GoldButton(currentStep == totalSteps - 1 ? "Reveal My Chart" : "Continue", isEnabled: canAdvance) {
                        advanceStep()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            if let staged = viewModel.onboardingDisplayName, displayName.isEmpty {
                displayName = staged
            }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                    appeared = true
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    nameFocused = false
                    birthplaceFocused = false
                }
            }
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return !trimmedName.isEmpty
        case 3: return !birthplace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return true
        }
    }

    private var header: some View {
        HStack {
            Button {
                HapticManager.buttonPress()
                if currentStep > 0 {
                    withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                        currentStep -= 1
                    }
                } else {
                    withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                        viewModel.currentScreen = .landing
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentStep > 0 ? "Previous step" : "Back to landing")

            Spacer()

            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .padding(.trailing, 16)
        }
        .padding(.horizontal, 12)
    }

    private var stepProgress: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(height: 4)
                    .animation(.spring(SimastrySpring.snappy), value: currentStep)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Step Copy

    private func stepEyebrow(_ text: String) -> some View {
        Text(text)
            .font(SimastryFont.overline)
            .foregroundStyle(SimastryColor.gold)
            .tracking(2.2)
            .textCase(.uppercase)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(spacing: 18) {
            stepEyebrow("Your advisory panel")

            Text("What should your guides call you?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Every reading is written to you — your name, your chart, your conversations.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            TextField("Your name", text: $displayName)
                .focused($nameFocused)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .onSubmit {
                    if canAdvance { advanceStep() }
                }
                .font(SimastryFont.titleLarge)
                .foregroundStyle(.white)
                .tint(SimastryColor.gold)
                .multilineTextAlignment(.center)
                .padding(.vertical, 18)
                .padding(.horizontal, 20)
                .background(.white.opacity(0.07), in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            nameFocused ? SimastryColor.gold.opacity(0.5) : .white.opacity(0.14),
                            lineWidth: 1
                        )
                }
                .padding(.top, 6)
                .onChange(of: displayName) { _, newValue in
                    if newValue.count > 30 {
                        displayName = String(newValue.prefix(30))
                    }
                }
        }
        .padding(.horizontal, 28)
    }

    private var birthdayStep: some View {
        VStack(spacing: 18) {
            stepEyebrow("Sun · core drive")

            Text(firstName.isEmpty ? "When were you born?" : "Nice to meet you, \(firstName).\nWhen were you born?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your birthday sets your Sun and Moon — the heart of how you communicate.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 190)
        }
        .padding(.horizontal, 24)
    }

    private var birthTimeStep: some View {
        VStack(spacing: 18) {
            stepEyebrow("Rising · first impression")

            Text("What time were you born?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Birth time pins down your Rising sign — the tone people read first.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if !birthTimeUnknown {
                DatePicker("Birth Time", selection: $birthTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 170)
            }

            Button {
                withAnimation(.spring(SimastrySpring.snappy)) {
                    birthTimeUnknown.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: birthTimeUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(birthTimeUnknown ? SimastryColor.gold : SimastryColor.mutedSilver)
                    Text("I don't know my birth time")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(birthTimeUnknown ? SimastryColor.offWhite : SimastryColor.mutedSilver)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if birthTimeUnknown {
                Text("No worries — your Sun and Moon stay accurate. We'll estimate your Rising sign from your birthday.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
    }

    private var birthplaceStep: some View {
        VStack(spacing: 18) {
            stepEyebrow("Chart · final signal")

            Text(firstName.isEmpty ? "Where were you born?" : "Last one, \(firstName).\nWhere were you born?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                TextField("City, Country", text: $birthplace)
                    .focused($birthplaceFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { birthplaceFocused = false }
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.white)
                    .tint(SimastryColor.gold)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                birthplaceFocused ? SimastryColor.gold.opacity(0.5) : .white.opacity(0.14),
                                lineWidth: 1
                            )
                    }
                    .onChange(of: birthplace) { _, newValue in
                        selectedFromSuggestion = false
                        locationCompleter.search(query: newValue)
                        let hasSuggestions = newValue.count >= 2
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                            showSuggestions = hasSuggestions
                        }
                    }

                // Autocomplete suggestions
                if showSuggestions && !locationCompleter.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(locationCompleter.suggestions, id: \.self) { completion in
                            Button {
                                selectSuggestion(completion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(SimastryFont.bodyMedium)
                                        .foregroundStyle(SimastryColor.offWhite)
                                        .lineLimit(1)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(SimastryFont.caption)
                                            .foregroundStyle(SimastryColor.mutedSilver)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if completion != locationCompleter.suggestions.last {
                                Divider()
                                    .background(.white.opacity(0.08))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .simastryGlass(cornerRadius: SimastryRadius.small)
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                }

                if !showSuggestions || locationCompleter.suggestions.isEmpty {
                    Text("Resolves your chart timezone and Rising sign")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func selectSuggestion(_ completion: MKLocalSearchCompletion) {
        let title = completion.title
        let subtitle = completion.subtitle
        birthplace = subtitle.isEmpty ? title : "\(title), \(subtitle)"
        selectedFromSuggestion = true
        locationCompleter.clear()
        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
            showSuggestions = false
        }
        birthplaceFocused = false
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.gold.opacity(0.7))

            Text("We use this to generate your astrological birth chart. We never share or sell your data.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }

    private func advanceStep() {
        HapticManager.buttonPress()
        if currentStep == 0 {
            guard !trimmedName.isEmpty else { return }
            viewModel.onboardingDisplayName = trimmedName
            nameFocused = false
            withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                currentStep = 1
            }
        } else if currentStep < totalSteps - 1 {
            birthplaceFocused = false
            withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                currentStep += 1
            }
        } else {
            let trimmedBirthplace = birthplace.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBirthplace.isEmpty else {
                viewModel.showToast("Birthplace required", subtitle: "Enter your birthplace so we can calculate your Rising sign accurately.", isError: true)
                return
            }

            birthplaceFocused = false
            isCalculating = true

            viewModel.onboardingBirthday = birthday
            viewModel.onboardingBirthTime = birthTime
            viewModel.onboardingBirthplace = trimmedBirthplace

            Task {
                guard let location = await birthplaceGeocodingService.resolve(trimmedBirthplace) else {
                    isCalculating = false
                    viewModel.showToast("We couldn't find that location", subtitle: "Try a city name like 'London, UK'", isError: true)
                    return
                }

                let chartService = BirthChartService()
                let chart = chartService.calculate(
                    birthday: birthday,
                    birthTime: birthTime,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    timeZone: location.timeZone
                )

                guard chart.risingSign != nil else {
                    isCalculating = false
                    viewModel.showToast("Couldn't calculate your Rising sign", subtitle: "Double-check your birth time and birthplace, then try again.", isError: true)
                    return
                }

                viewModel.stageOnboardingBirthChart(chart)

                isCalculating = false
                withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
                    viewModel.currentScreen = .signUp
                }
            }
        }
    }
}
