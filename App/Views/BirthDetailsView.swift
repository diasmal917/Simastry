import SwiftUI
import MapKit

struct BirthDetailsView: View {
    @Bindable var viewModel: AppViewModel
    /// Back from the first step. The setup flow pops its navigation path;
    /// legacy hosts fall back to the landing screen.
    var onExit: (() -> Void)? = nil
    /// Called after a successful calculation. The setup flow continues to the
    /// chart summary; legacy hosts fall back to the preserved expert screen.
    var onCalculated: (() -> Void)? = nil
    @ObservedObject private var localization = LocalizationManager.shared
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
    @State private var birthTimePrecision: BirthTimePrecision = .exact
    @State private var approximateUncertaintyMinutes: Int = 60
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

    private var stateAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : SimastryMotion.stateChange
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    var body: some View {
        ZStack {
            // The setup flow's still ink surface — no drifting wallpaper or
            // dust motes during onboarding.
            SimastryColor.pureBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)

                stepProgress
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ScrollView {
                    Group {
                        switch currentStep {
                        case 0: nameStep
                        case 1: birthdayStep
                        case 2: birthTimeStep
                        case 3: birthplaceStep
                        default: EmptyView()
                        }
                    }
                    .transition(stepTransition)
                    .id(currentStep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                privacyNote
                    .padding(.bottom, 12)

                if isCalculating {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(SimastryColor.gold)
                        Text(localization.string("birth.calculating"))
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                } else {
                    GoldButton(currentStep == totalSteps - 1 ? localization.string("birth.reveal") : localization.string("birth.continue"), isEnabled: canAdvance) {
                        advanceStep()
                    }
                    .accessibilityIdentifier("birth.continueButton")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Everything entered before an interruption comes back: the
            // staged values survive navigation and relaunch.
            if let staged = viewModel.onboardingDisplayName, displayName.isEmpty {
                displayName = staged
            }
            if let staged = viewModel.onboardingBirthday {
                birthday = staged
            }
            if let staged = viewModel.onboardingBirthTime {
                birthTime = staged
            }
            if let staged = viewModel.onboardingBirthplace, birthplace.isEmpty {
                birthplace = staged
            }
            if viewModel.onboardingBirthday != nil {
                birthTimePrecision = viewModel.onboardingBirthTimePrecision
                if let staged = viewModel.onboardingBirthTimeUncertaintyMinutes {
                    approximateUncertaintyMinutes = staged
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localization.string("birth.keyboardDone")) {
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
        ZStack {
            HStack {
                Button {
                    HapticManager.buttonPress()
                    if currentStep > 0 {
                        withAnimation(stateAnimation) {
                            currentStep -= 1
                        }
                    } else if let onExit {
                        onExit()
                    } else {
                        withAnimation(stateAnimation) {
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
                .accessibilityLabel(
                    currentStep > 0
                        ? localization.string("common.previousStep")
                        : localization.string(onExit != nil ? "common.back" : "common.backToLanding")
                )

                Spacer()
            }

            Text(localization.string("birth.step", replacements: ["current": "\(currentStep + 1)", "total": "\(totalSteps)"]))
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 72)
        }
        .padding(.horizontal, 12)
    }

    private var stepProgress: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? AnyShapeStyle(SimastryGradient.gold) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(height: 4)
                    .animation(stateAnimation, value: currentStep)
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
            stepEyebrow(localization.string("birth.name.eyebrow"))

            Text(localization.string("birth.name.title"))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.string("birth.name.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            TextField(localization.string("birth.name.placeholder"), text: $displayName)
                .focused($nameFocused)
                .accessibilityIdentifier("birth.name")
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
            stepEyebrow(localization.string("birth.birthday.eyebrow"))

            Text(firstName.isEmpty ? localization.string("birth.birthday.title") : localization.string("birth.birthday.titleNamed", replacements: ["name": firstName]))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.string("birth.birthday.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            DatePicker(localization.string("birth.birthday"), selection: $birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 190)
        }
        .padding(.horizontal, 24)
    }

    private var birthTimeStep: some View {
        VStack(spacing: 18) {
            stepEyebrow(localization.string("birth.time.eyebrow"))

            Text(localization.string("birth.time.title"))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.string("birth.time.subtitle"))
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 8) {
                ForEach(BirthTimePrecision.allCases) { precision in
                    BirthTimePrecisionRow(
                        precision: precision,
                        isSelected: birthTimePrecision == precision
                    ) {
                        selectBirthTimePrecision(precision)
                    }
                }
            }

            if birthTimePrecision.requiresBirthTime {
                DatePicker(localization.string("birth.time"), selection: $birthTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 150)
            }

            if birthTimePrecision == .approximate {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uncertainty range")
                            .font(SimastryFont.labelMedium)
                            .foregroundStyle(SimastryColor.offWhite)
                        Text("We sample the full range")
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }

                    Spacer(minLength: 8)

                    Picker("Uncertainty range", selection: $approximateUncertaintyMinutes) {
                        Text("±30 minutes").tag(30)
                        Text("±1 hour").tag(60)
                        Text("±2 hours").tag(120)
                    }
                    .pickerStyle(.menu)
                    .tint(SimastryColor.gold)
                    .frame(minHeight: 44)
                    .accessibilityHint("Simastry samples the full selected range before showing a Rising sign.")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.045), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
                .transition(.opacity)
            }

            if birthTimePrecision == .unknown {
                Text(localization.string("birth.unknownTimeNote"))
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(stateAnimation, value: birthTimePrecision)
    }

    private func selectBirthTimePrecision(_ precision: BirthTimePrecision) {
        HapticManager.zodiacSelection()
        birthTimePrecision = precision
    }

    private var birthplaceStep: some View {
        VStack(spacing: 18) {
            stepEyebrow(localization.string("birth.place.eyebrow"))

            Text(firstName.isEmpty ? localization.string("birth.place.title") : localization.string("birth.place.titleNamed", replacements: ["name": firstName]))
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                TextField(localization.string("birth.placePlaceholder"), text: $birthplace)
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
                        withAnimation(stateAnimation) {
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
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                }

                if !showSuggestions || locationCompleter.suggestions.isEmpty {
                    Text(localization.string("birth.placeHelp"))
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
        withAnimation(stateAnimation) {
            showSuggestions = false
        }
        birthplaceFocused = false
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(SimastryFont.labelSmall)
                .foregroundStyle(SimastryColor.gold.opacity(0.7))

            Text(localization.string("birth.privacy"))
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
            withAnimation(stateAnimation) {
                currentStep = 1
            }
        } else if currentStep < totalSteps - 1 {
            birthplaceFocused = false
            withAnimation(stateAnimation) {
                currentStep += 1
            }
        } else {
            let trimmedBirthplace = birthplace.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBirthplace.isEmpty else {
                viewModel.showToast(localization.string("birth.requiredTitle"), subtitle: localization.string("birth.requiredSubtitle"), isError: true)
                return
            }

            birthplaceFocused = false
            isCalculating = true

            let confirmedBirthTime = birthTimePrecision.requiresBirthTime ? birthTime : nil
            let uncertaintyMinutes = birthTimePrecision == .approximate
                ? approximateUncertaintyMinutes
                : nil

            viewModel.onboardingBirthday = birthday
            viewModel.onboardingBirthTime = confirmedBirthTime
            viewModel.onboardingBirthplace = trimmedBirthplace
            viewModel.onboardingBirthTimePrecision = birthTimePrecision
            viewModel.onboardingBirthTimeUncertaintyMinutes = uncertaintyMinutes

            Task {
                guard let location = await birthplaceGeocodingService.resolve(trimmedBirthplace) else {
                    isCalculating = false
                    viewModel.showToast(localization.string("birth.notFoundTitle"), subtitle: localization.string("birth.notFoundSubtitle"), isError: true)
                    return
                }

                let chartService = BirthChartService()
                let chart = await chartService.calculate(
                    birthday: birthday,
                    birthTime: confirmedBirthTime,
                    precision: birthTimePrecision,
                    uncertaintyMinutes: uncertaintyMinutes,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    timeZone: location.timeZone
                )

                guard birthTimePrecision != .exact || chart.rising != nil else {
                    isCalculating = false
                    viewModel.showToast(localization.string("birth.risingFailedTitle"), subtitle: localization.string("birth.risingFailedSubtitle"), isError: true)
                    return
                }

                let record = chartService.makeNatalChartRecord(
                    from: chart,
                    birthday: birthday,
                    birthTime: confirmedBirthTime,
                    precision: birthTimePrecision,
                    uncertaintyMinutes: uncertaintyMinutes,
                    birthplace: trimmedBirthplace,
                    location: location
                )
                viewModel.stageOnboardingBirthChart(chart, record: record)

                isCalculating = false
                if let onCalculated {
                    onCalculated()
                } else {
                    withAnimation(stateAnimation) {
                        // Preserved legacy host: the expert-mode read follows
                        // the calculation directly.
                        viewModel.currentScreen = .firstExpertRead
                    }
                }
            }
        }
    }
}

private struct BirthTimePrecisionRow: View {
    let precision: BirthTimePrecision
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isSelected ? SimastryColor.gold : SimastryColor.mutedSilver)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(precision.title)
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(precision.detail)
                        .font(SimastryFont.captionSmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? SimastryColor.gold.opacity(0.1) : Color.white.opacity(0.045),
                in: .rect(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? SimastryColor.gold.opacity(0.45) : .white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Birth time precision: \(precision.title)")
        .accessibilityHint(precision.detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
