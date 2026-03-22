import SwiftUI

struct BirthDetailsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var currentStep: Int = 0
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var birthTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var isBirthTimeUnknown: Bool = false
    @State private var birthplace: String = ""
    @State private var appeared: Bool = false
    @FocusState private var birthplaceFocused: Bool

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

                GoldButton("Continue") {
                    advanceStep()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(SimastrySpring.smooth).delay(0.2)) {
                appeared = true
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
                    withAnimation(.spring(SimastrySpring.smooth)) {
                        currentStep -= 1
                    }
                } else {
                    withAnimation(.spring(SimastrySpring.smooth)) {
                        viewModel.currentScreen = .landing
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

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
        case 1: return "Combined with your birthday, this determines your Rising sign."
        case 2: return "Optional — improves the accuracy of your Rising sign placement."
        default: return ""
        }
    }

    // MARK: - Steps

    private var birthdayStep: some View {
        VStack(spacing: 24) {
            Text("What's your birthday?")
                .font(.system(size: 28, weight: .bold, design: .serif))
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
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !isBirthTimeUnknown {
                DatePicker("Birth Time", selection: $birthTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 200)
                    .transition(.opacity)
            }

            Button {
                withAnimation(.spring(SimastrySpring.snappy)) {
                    isBirthTimeUnknown.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isBirthTimeUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isBirthTimeUnknown ? SimastryColor.gold : .white.opacity(0.4))

                    Text("I don't know my birth time")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    private var birthplaceStep: some View {
        VStack(spacing: 24) {
            Text("Where were you born?")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("City, Country", text: $birthplace)
                    .focused($birthplaceFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { birthplaceFocused = false }
                    .font(.system(size: 18, weight: .medium))
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

                Text("Optional — helps refine your Rising sign")
                    .font(.system(size: 13))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
        }
        .padding(.horizontal, 24)
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13))
                .foregroundStyle(SimastryColor.gold.opacity(0.7))

            Text("We use this to generate your astrological birth chart. We never share or sell your data.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }

    private func advanceStep() {
        HapticManager.buttonPress()
        if currentStep < 2 {
            birthplaceFocused = false
            withAnimation(.spring(SimastrySpring.smooth)) {
                currentStep += 1
            }
        } else {
            viewModel.onboardingBirthday = birthday
            viewModel.onboardingBirthTime = isBirthTimeUnknown ? nil : birthTime
            viewModel.onboardingBirthplace = birthplace.isEmpty ? nil : birthplace

            // Calculate birth chart using Swiss Ephemeris for accurate placements.
            // Latitude/longitude are not available from text input alone — for Rising
            // sign accuracy, we'd need geocoding. For now, pass nil for location
            // unless we add geocoding later. The user can refine on the sign selection screen.
            let chartService = BirthChartService()
            let chart = chartService.calculate(
                birthday: birthday,
                birthTime: isBirthTimeUnknown ? nil : birthTime,
                latitude: nil,
                longitude: nil
            )

            viewModel.userSunSign = chart.sunSign
            viewModel.userMoonSign = chart.moonSign
            // Rising requires location — set to nil so user picks manually,
            // or use the calculated value if we had coordinates
            viewModel.userRisingSign = chart.risingSign

            birthplaceFocused = false
            withAnimation(.spring(SimastrySpring.smooth)) {
                viewModel.currentScreen = .signUp
            }
        }
    }
}
