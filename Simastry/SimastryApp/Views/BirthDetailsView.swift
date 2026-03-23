import SwiftUI
import MapKit

struct BirthDetailsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var currentStep: Int = 0
    @State private var isCalculating: Bool = false
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
    private let birthplaceGeocodingService = BirthplaceGeocodingService()

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)

                OnboardingProgressView(
                    eyebrow: "Your Birth Chart",
                    title: stepTitle,
                    subtitle: stepSubtitle,
                    step: currentStep + 1,
                    totalSteps: 3,
                    labels: ["Birthday", "Time", "Place"]
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Group {
                    switch currentStep {
                    case 0: birthdayStep
                    case 1: birthTimeStep
                    case 2: birthplaceStep
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
                    GoldButton("Continue") {
                        advanceStep()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { birthplaceFocused = false }
            }
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
        }
        .padding(.horizontal, 12)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Your Birthday"
        case 1: return "Your Birth Time"
        case 2: return "Your Birthplace"
        default: return ""
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "We'll calculate your Sun and Moon signs from this."
        case 1: return "We need your exact birth time to calculate your Rising sign correctly."
        case 2: return "We use your birthplace to resolve the chart timezone and location."
        default: return ""
        }
    }

    // MARK: - Steps

    private var birthdayStep: some View {
        VStack(spacing: 24) {
            Text("What's your birthday?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 200)
        }
        .padding(.horizontal, 24)
    }

    private var birthTimeStep: some View {
        VStack(spacing: 24) {
            Text("What time were you born?")
                .font(SimastryFont.titleLarge)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !birthTimeUnknown {
                DatePicker("Birth Time", selection: $birthTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 200)
            }

            // "I don't know" toggle
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
            }
            .buttonStyle(.plain)

            if birthTimeUnknown {
                Text("No worries — your Sun and Moon signs will still be accurate. We'll estimate your Rising sign based on your birthday.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("Don't know your exact birth time? That's okay — your Sun and Moon signs are still accurate. Rising sign needs birth time for precision, but we'll estimate if needed.")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver.opacity(0.85))
                .multilineTextAlignment(.center)
                .opacity(birthTimeUnknown ? 0 : 0.7)
        }
        .padding(.horizontal, 24)
    }

    private var birthplaceStep: some View {
        VStack(spacing: 24) {
            Text("Where were you born?")
                .font(SimastryFont.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("City, Country", text: $birthplace)
                    .focused($birthplaceFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { birthplaceFocused = false }
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
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
                    Text("Required — used to resolve your chart timezone and Rising sign")
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
        if currentStep < 2 {
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
