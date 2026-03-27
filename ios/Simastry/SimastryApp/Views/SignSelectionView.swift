import SwiftUI

struct SignSelectionView: View {
    @Bindable var viewModel: AppViewModel
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var birthplace: String = ""
    @State private var birthTime: Date = SignSelectionView.defaultBirthTime()
    @State private var showSignReveal: Bool = false
    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCalculating: Bool = false
    @FocusState private var focusedField: SignInputField?
    private let birthplaceGeocodingService = BirthplaceGeocodingService()

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
            loadExistingBirthDetails()
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
                    title: "Calculate your big three",
                    subtitle: "We use your birth date, exact time, and birthplace timezone to compute your Sun, Moon, and Rising signs.",
                    step: 2,
                    totalSteps: 3,
                    labels: ["Path", "Signs", "Companion"]
                )
                .padding(.horizontal, 20)

                chartAccuracyCard
                    .padding(.horizontal, 20)

                calculationForm
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? .default : .spring(SimastrySpring.smooth), value: appeared)
    }

    private var chartAccuracyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Accurate chart required")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
            } icon: {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(SimastryColor.gold)
            }

            Text("Moon and Rising signs shift with both birth time and birthplace. We only reveal your chart once we can calculate it from real birth details.")
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
    }

    private var calculationForm: some View {
        VStack(spacing: 16) {
            inputCard(role: .sun, title: "Birthday") {
                DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(SimastryColor.gold)
            }

            inputCard(role: .moon, title: "Birth Time") {
                DatePicker("Birth Time", selection: $birthTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 140)
                    .clipped()
                    .tint(SimastryColor.gold)

                Text("We need your exact birth time to calculate your Rising sign accurately.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            inputCard(role: .rising, title: "Birthplace") {
                TextField("City, Country", text: $birthplace)
                    .focused($focusedField, equals: .birthplace)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("We use this to resolve the birthplace timezone and ascendant location.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.deepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isCalculating {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(SimastryColor.gold)
                    Text("Calculating your chart...")
                        .font(SimastryFont.labelMedium)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            } else {
                GoldButton("Calculate My Signs", isEnabled: !trimmedBirthplace.isEmpty) {
                    Task {
                        await calculateBirthChart()
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var trimmedBirthplace: String {
        birthplace.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func inputSubtitle(for role: CelestialRole) -> String {
        switch role {
        case .sun:
            "Locks in the birth date for your chart"
        case .moon:
            "Needed to compute your ascendant precisely"
        case .rising:
            "Sets the location and timezone of the chart"
        }
    }

    private func loadExistingBirthDetails() {
        if let onboardingBirthday = viewModel.onboardingBirthday {
            birthday = onboardingBirthday
        }
        if let onboardingBirthTime = viewModel.onboardingBirthTime {
            birthTime = onboardingBirthTime
        }
        if let onboardingBirthplace = viewModel.onboardingBirthplace {
            birthplace = onboardingBirthplace
        }
    }

    private func calculateBirthChart() async {
        guard !isCalculating else { return }
        guard !trimmedBirthplace.isEmpty else {
            viewModel.showToast("Birthplace required", subtitle: "Enter your birthplace so we can calculate your Rising sign accurately.", isError: true)
            return
        }

        focusedField = nil
        isCalculating = true

        viewModel.onboardingBirthday = birthday
        viewModel.onboardingBirthTime = birthTime
        viewModel.onboardingBirthplace = trimmedBirthplace

        let location = await birthplaceGeocodingService.resolve(trimmedBirthplace)
        guard let location else {
            isCalculating = false
            viewModel.showToast("Couldn't place your birthplace", subtitle: "Use a city and country we can verify for your chart.", isError: true)
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

        HapticManager.signConfirmed()
        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.smooth)) {
            showSignReveal = true
        }
    }

    private static func defaultBirthTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
