import SwiftUI

struct SoulCreationView: View {
    @Bindable var viewModel: AppViewModel
    @State private var phase: Int = 0
    @State private var orbScale: CGFloat = 0
    @State private var orbActive: Bool = false
    @State private var textOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var nameScale: CGFloat = 0.5
    @State private var nameOpacity: Double = 0
    @State private var signsRevealed: Bool = false
    @State private var zodiacOffsets: [CGSize] = [
        CGSize(width: -120, height: -60),
        CGSize(width: 120, height: -40),
        CGSize(width: 0, height: 80)
    ]
    @State private var zodiacOpacity: Double = 0
    @State private var particlePositions: [CGPoint] = (0..<20).map { _ in
        CGPoint(x: CGFloat.random(in: 50...350), y: CGFloat.random(in: 100...700))
    }

    var body: some View {
        ZStack {
            Color(red: 6/255, green: 8/255, blue: 18/255)
                .ignoresSafeArea()

            StarfieldView()
                .opacity(0.5)
                .ignoresSafeArea()

            particlesLayer

            zodiacCirclesLayer

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    if phase < 3 {
                        GlossyOrbView(
                            signColors: orbColors,
                            state: orbActive ? .active : .idle,
                            size: 130
                        )
                        .scaleEffect(orbScale)
                    } else {
                        avatarPlaceholder
                            .scaleEffect(nameScale)
                            .opacity(nameOpacity)
                    }
                }
                .frame(height: 160)

                Text(phaseText)
                    .font(SimastryFont.bodyLarge.italic())
                    .foregroundStyle(SimastryColor.gold)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .padding(.horizontal, 40)

                if phase == 3, signsRevealed {
                    companionSignBadges
                        .transition(.opacity)
                }

                Spacer()
            }

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { startSequence() }
    }

    private var particlesLayer: some View {
        Canvas { context, _ in
            for point in particlePositions {
                let size: CGFloat = CGFloat.random(in: 2...4)
                context.opacity = 0.4
                context.fill(
                    Circle().path(in: CGRect(x: point.x, y: point.y, width: size, height: size)),
                    with: .color(SimastryColor.gold)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var zodiacCirclesLayer: some View {
        ZStack {
            if let sun = viewModel.companionSunSign {
                zodiacOrbitCircle(sign: sun, offset: zodiacOffsets[0])
            }
            if let moon = viewModel.companionMoonSign {
                zodiacOrbitCircle(sign: moon, offset: zodiacOffsets[1])
            }
            if let rising = viewModel.companionRisingSign {
                zodiacOrbitCircle(sign: rising, offset: zodiacOffsets[2])
            }
        }
        .opacity(zodiacOpacity)
    }

    private func zodiacOrbitCircle(sign: ZodiacSign, offset: CGSize) -> some View {
        Circle()
            .fill(sign.color.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                ZodiacIconView(sign: sign, size: 25, showsGlow: false)
            )
            .offset(offset)
    }

    private var avatarPlaceholder: some View {
        let style = viewModel.companionAppearance
        let pc = style.primaryColor
        let sc = style.secondaryColor
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: pc.r, green: pc.g, blue: pc.b),
                            Color(red: sc.r, green: sc.g, blue: sc.b)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: SimastryColor.gold.opacity(0.3), radius: 20)

            Text(String(viewModel.companionName.prefix(1)).uppercased())
                .font(SimastryFont.displayLarge)
                .foregroundStyle(SimastryColor.offWhite)
        }
    }

    private var companionSignBadges: some View {
        VStack(spacing: 12) {
            Text(viewModel.companionName)
                .font(SimastryFont.titleLarge)
                .foregroundStyle(SimastryColor.gold)

            if let sun = viewModel.companionSunSign {
                miniSignBadge(role: .sun, sign: sun)
            }
            if let moon = viewModel.companionMoonSign {
                miniSignBadge(role: .moon, sign: moon)
            }
            if let rising = viewModel.companionRisingSign {
                miniSignBadge(role: .rising, sign: rising)
            }
        }
        .padding(.horizontal, 40)
    }

    private func miniSignBadge(role: CelestialRole, sign: ZodiacSign) -> some View {
        HStack(spacing: 8) {
            CelestialRoleIcon(role: role, size: 24)
            Text("\(role.displayName) in \(sign.displayName)")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(role.accentColor)
            ZodiacIconView(sign: sign, size: 18, showsGlow: false)
                .opacity(0.7)
        }
    }

    private var orbColors: [Color] {
        [
            viewModel.companionSunSign?.color ?? SimastryColor.gold,
            viewModel.companionMoonSign?.color ?? SimastryColor.celestialBlue
        ]
    }

    private var phaseText: String {
        switch phase {
        case 0, 1: return "Mapping the placement profile..."
        case 2:
            let sun = viewModel.companionSunSign?.displayName ?? "Sun"
            let moon = viewModel.companionMoonSign?.displayName ?? "Moon"
            let rising = viewModel.companionRisingSign?.displayName ?? "Rising"
            return "Translating \(sun) drive, \(moon) emotion, and \(rising) instinct..."
        case 3: return ""
        default: return ""
        }
    }

    private func startSequence() {
        // Phase 1: Gathering
        withAnimation(.spring(SimastrySpring.bouncy)) {
            orbScale = 1.0
            zodiacOpacity = 1.0
            textOpacity = 1.0
        }
        HapticManager.buttonPress()

        // Phase 2: Convergence
        Task {
            try? await Task.sleep(for: .seconds(3))
            phase = 2
            withAnimation(.spring(SimastrySpring.smooth)) {
                zodiacOffsets = [.zero, .zero, .zero]
                orbActive = true
                textOpacity = 0
            }
            HapticManager.createSoul()

            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(SimastrySpring.smooth)) {
                textOpacity = 1.0
            }

            // Phase 3: Reveal
            try? await Task.sleep(for: .seconds(2.5))
            phase = 3
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                flashOpacity = 0.8
            }
            HapticManager.soulFlash()

            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(SimastrySpring.smooth)) {
                flashOpacity = 0
                zodiacOpacity = 0
                nameScale = 1.0
                nameOpacity = 1.0
                textOpacity = 0
            }

            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(SimastrySpring.bouncy)) {
                signsRevealed = true
            }

            try? await Task.sleep(for: .seconds(2))
            await viewModel.createCompanion()
        }
    }
}
