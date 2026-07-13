import SwiftUI
import PhotosUI

struct CompassPendingCheckInCard: View {
    let result: PredictionResult
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: SimastrySpacing.sm) {
                Image(systemName: "checkmark.bubble")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SimastryColor.celestialBlue)
                    .frame(width: 44, height: 44)
                    .background(SimastryColor.celestialBlue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                    Text("How did it go?")
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)
                    Text(result.historyTitle)
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            .padding(SimastrySpacing.md)
            .contentSurface(cornerRadius: SimastryRadius.large, accent: SimastryColor.celestialBlue)
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityIdentifier("compass.pending-check-in")
        .accessibilityHint("Record whether a reply arrived and how closely its tone matched")
    }
}

struct CompassDailyGuidanceCard: View {
    let guidance: DailyGuidance

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack {
                Label("TODAY", systemImage: "sun.max.fill")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(1.2)
                Spacer()
                Text(guidance.sourceName)
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Text(guidance.notice)
                .font(SimastryFont.titleSmall)
                .foregroundStyle(SimastryColor.offWhite)
                .fixedSize(horizontal: false, vertical: true)

            Label(guidance.action, systemImage: "arrow.up.forward")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.large)
        .accessibilityElement(children: .combine)
    }
}

struct CompassComposerCard: View {
    @Binding var draft: CompassDraft
    let timingIsAvailable: Bool
    @Binding var selectedPersonID: UUID?
    @Binding var targetSunSign: ZodiacSign?
    @Binding var targetMoonSign: ZodiacSign?
    @Binding var targetRisingSign: ZodiacSign?
    let people: [RelationshipPerson]
    @Binding var screenshotPickerItem: PhotosPickerItem?
    let isRecognizingScreenshot: Bool
    let isGenerating: Bool
    let canSubmit: Bool
    let onSelectPerson: (UUID?) -> Void
    let onSubmit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.lg) {
            questionField
            intentPicker
            contextualFields
            topicPicker
            optionalContext
        }
        .padding(SimastrySpacing.md)
        .contentSurface(cornerRadius: SimastryRadius.card, accent: SimastryColor.risingViolet.opacity(0.7))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: draft.intent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: draft.options.count)
    }

    private var questionField: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            Text("YOUR QUESTION")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.2)

            TextField(
                "What should I do about…",
                text: $draft.question,
                axis: .vertical
            )
            .font(SimastryFont.bodyLarge)
            .foregroundStyle(SimastryColor.offWhite)
            .lineLimit(2...5)
            .padding(SimastrySpacing.md)
            .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: SimastryRadius.medium)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
            .accessibilityIdentifier("compass.question")
        }
    }

    private var intentPicker: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            Text("OPTIONAL FORMAT")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.2)

            ScrollView(.horizontal) {
                HStack(spacing: SimastrySpacing.xs) {
                    ForEach(CompassIntent.allCases) { intent in
                        intentButton(intent)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)

            if !timingIsAvailable {
                Label(
                    "Timing unlocks when a saved chart can produce calculated current-transit evidence.",
                    systemImage: "info.circle"
                )
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func intentButton(_ intent: CompassIntent) -> some View {
        let isSelected = draft.intent == intent
        let isEnabled = intent != .timing || timingIsAvailable

        return Button {
            draft.intent = intent
            HapticManager.zodiacSelection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isEnabled ? intent.systemImage : "lock")
                Text(intent.title)
            }
            .font(SimastryFont.labelLarge)
            .foregroundStyle(isSelected ? SimastryColor.midnight : SimastryColor.offWhite)
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(
                isSelected ? SimastryColor.gold : SimastryColor.surfaceSunken,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.10), lineWidth: 1)
            }
        }
        .buttonStyle(CompassPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(isEnabled ? intent.title : "\(intent.title), unavailable")
        .accessibilityIdentifier("compass.intent.\(intent.rawValue)")
    }

    @ViewBuilder
    private var contextualFields: some View {
        switch draft.intent {
        case .general:
            EmptyView()
        case .conversation:
            conversationFields
        case .compareOptions:
            comparisonFields
        case .timing:
            timingEvidenceNotice
        }
    }

    private var conversationFields: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack {
                Text("CONVERSATION")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.2)
                Spacer()
                PhotosPicker(selection: $screenshotPickerItem, matching: .images) {
                    Label(
                        isRecognizingScreenshot ? "Reading…" : "Import",
                        systemImage: isRecognizingScreenshot ? "hourglass" : "photo.badge.plus"
                    )
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .frame(minHeight: 44)
                }
                .disabled(isRecognizingScreenshot)
                .buttonStyle(CompassPressStyle())
            }

            TextField("Paste the relevant thread", text: $draft.conversationText, axis: .vertical)
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(4...9)
                .padding(SimastrySpacing.md)
                .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.medium))
                .accessibilityIdentifier("compass.conversation")

            Text("Screenshots are read on this iPhone. Obvious personal details are redacted before remote guidance.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comparisonFields: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            HStack {
                Text("OPTIONS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.2)
                Spacer()
                if draft.options.count < 3 {
                    Button("Add third") {
                        draft.options.append("")
                    }
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.gold)
                    .frame(minHeight: 44)
                    .buttonStyle(CompassPressStyle())
                }
            }

            ForEach(draft.options.indices, id: \.self) { index in
                HStack(spacing: SimastrySpacing.xs) {
                    Text("\(index + 1)")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.midnight)
                        .frame(width: 26, height: 26)
                        .background(SimastryColor.gold, in: Circle())
                    TextField("Option \(index + 1)", text: $draft.options[index])
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.offWhite)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, SimastrySpacing.sm)
                .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))
                .accessibilityIdentifier("compass.option.\(index + 1)")
            }
        }
    }

    private var timingEvidenceNotice: some View {
        HStack(alignment: .top, spacing: SimastrySpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(SimastryColor.sageGreen)
            VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                Text("Calculated evidence available")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Compass can discuss today’s whole-sign transit. It will not invent long-range dates.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SimastrySpacing.sm)
        .background(SimastryColor.sageGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: SimastryRadius.small))
    }

    private var topicPicker: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.xs) {
            Text("OPTIONAL TOPIC")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.2)

            ScrollView(.horizontal) {
                HStack(spacing: SimastrySpacing.xs) {
                    ForEach(CompassTopic.allCases) { topic in
                        Button {
                            draft.topic = draft.topic == topic ? nil : topic
                            HapticManager.zodiacSelection()
                        } label: {
                            Label(topic.title, systemImage: topic.systemImage)
                                .font(SimastryFont.labelSmall)
                                .foregroundStyle(draft.topic == topic ? SimastryColor.gold : SimastryColor.mutedSilver)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(
                                    draft.topic == topic ? SimastryColor.gold.opacity(0.12) : SimastryColor.surfaceSunken,
                                    in: Capsule()
                                )
                                .overlay(alignment: .topTrailing) {
                                    if draft.topic == topic {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(SimastryColor.gold)
                                    }
                                }
                        }
                        .buttonStyle(CompassPressStyle())
                        .accessibilityAddTraits(draft.topic == topic ? .isSelected : [])
                        .accessibilityIdentifier("compass.topic.\(topic.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private var optionalContext: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: SimastrySpacing.md) {
                TextField(
                    "Anything else that changes the decision?",
                    text: $draft.additionalContext,
                    axis: .vertical
                )
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.offWhite)
                .lineLimit(2...5)
                .padding(SimastrySpacing.sm)
                .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))

                if draft.intent == .conversation || draft.topic == .relationships {
                    personContext
                }
            }
            .padding(.top, SimastrySpacing.sm)
        } label: {
            Label("Add context or a person", systemImage: "plus.circle")
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .frame(minHeight: 44)
        }
        .tint(SimastryColor.gold)
    }

    private var personContext: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            Menu {
                Button("No saved person") { onSelectPerson(nil) }
                ForEach(people) { person in
                    Button(person.displayName) { onSelectPerson(person.id) }
                }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text(selectedPersonName ?? "Choose a saved person")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(SimastryFont.labelLarge)
                .foregroundStyle(SimastryColor.offWhite)
                .padding(.horizontal, SimastrySpacing.sm)
                .frame(minHeight: 44)
                .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))
            }

            CompassSignMenu(title: "Sun", selection: $targetSunSign)
            CompassSignMenu(title: "Moon", selection: $targetMoonSign)
            CompassSignMenu(title: "Rising", selection: $targetRisingSign)

            Text("Person and chart details are optional. They are labeled as user-confirmed, never treated as observed facts.")
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.deepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedPersonName: String? {
        guard let selectedPersonID else { return nil }
        return people.first(where: { $0.id == selectedPersonID })?.displayName
    }

}

/// D3: the composer's collapsed-state toggle. Compass leads with the
/// glanceable instrument and one-tap bearings; typing a custom question is
/// still one tap away behind this row. Expanding also happens automatically
/// when a legacy `PredictionDraft` hands off a question that needs the full
/// form — see `SimulateView.applyLegacyDraftIfNeeded()`.
struct CompassAskYourOwnRow: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SimastrySpacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)
                    .frame(width: 32, height: 32)
                    .background(SimastryColor.gold.opacity(0.12), in: Circle())

                Text("Ask your own question")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)

                Spacer(minLength: SimastrySpacing.xs)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, SimastrySpacing.md)
            .frame(minHeight: 44)
            .interactiveGlass(cornerRadius: SimastryRadius.medium)
        }
        .buttonStyle(CompassPressStyle())
        .accessibilityIdentifier("compass.composer.expand")
        .accessibilityLabel("Ask your own question")
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
    }
}

/// The one primary Compass CTA. It is also used as a bottom safe-area action
/// so the keyboard cannot strand the user below the fold after typing.
struct CompassPrimaryAction: View {
    let title: String
    let isGenerating: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void
    let submissionHint: String

    var body: some View {
        Button(action: onSubmit) {
            HStack(spacing: SimastrySpacing.xs) {
                if isGenerating {
                    ProgressView()
                        .tint(SimastryColor.midnight)
                } else {
                    Image(systemName: "location.north.fill")
                }
                Text(isGenerating ? "Finding a clear next step…" : title)
                    .font(SimastryFont.titleSmall)
            }
            .foregroundStyle(SimastryColor.midnight)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(SimastryGradient.gold, in: Capsule())
            .goldGlassPill(interactive: true)
        }
        .buttonStyle(CompassPressStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
        .accessibilityIdentifier("compass.submit")
        .accessibilityHint(submissionHint)
        .padding(.horizontal, SimastrySpacing.lg)
        .padding(.vertical, SimastrySpacing.sm)
        .background(.ultraThinMaterial)
    }
}

struct CompassSignMenu: View {
    let title: String
    @Binding var selection: ZodiacSign?

    var body: some View {
        Menu {
            Button("Not provided") { selection = nil }
            ForEach(ZodiacSign.allCases) { sign in
                Button(sign.displayName) { selection = sign }
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(SimastryColor.mutedSilver)
                Spacer()
                Text(selection?.displayName ?? "Not provided")
                    .foregroundStyle(SimastryColor.offWhite)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimastryColor.deepMuted)
            }
            .font(SimastryFont.labelLarge)
            .padding(.horizontal, SimastrySpacing.sm)
            .frame(minHeight: 44)
            .background(SimastryColor.surfaceSunken, in: RoundedRectangle(cornerRadius: SimastryRadius.small))
        }
        .accessibilityLabel("\(title) sign, \(selection?.displayName ?? "not provided")")
    }
}

struct CompassRecentReadingsSection: View {
    let viewModel: AppViewModel
    let readings: [PredictionResult]
    let onOpen: (PredictionResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SimastrySpacing.sm) {
            HStack {
                Text("RECENT READINGS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .tracking(1.2)
                Spacer()
                NavigationLink {
                    CompassHistoryView(viewModel: viewModel)
                } label: {
                    Text("See all")
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.gold)
                        .frame(minHeight: 44)
                }
                .buttonStyle(CompassPressStyle())
                .accessibilityIdentifier("compass.history")
            }

            if readings.isEmpty {
                Text("Your readings will stay on this iPhone and appear here.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SimastrySpacing.md)
                    .contentSurface(cornerRadius: SimastryRadius.medium)
            } else {
                ForEach(readings) { reading in
                    CompassReadingRow(result: reading) { onOpen(reading) }
                }
            }
        }
    }
}

struct CompassReadingRow: View {
    let result: PredictionResult
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: SimastrySpacing.sm) {
                Image(systemName: result.categoryOrDefault.systemImage)
                    .font(.headline)
                    .foregroundStyle(result.categoryOrDefault.accentColor)
                    .frame(width: 44, height: 44)
                    .background(result.categoryOrDefault.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: SimastrySpacing.xxs) {
                    Text(result.historyTitle)
                        .font(SimastryFont.labelLarge)
                        .foregroundStyle(SimastryColor.offWhite)
                        .lineLimit(1)
                    Text(result.contextQuality?.title ?? "Legacy reading")
                        .font(SimastryFont.caption)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimastryColor.deepMuted)
            }
            .padding(SimastrySpacing.sm)
            .contentSurface(cornerRadius: SimastryRadius.medium)
        }
        .buttonStyle(CompassPressStyle())
    }
}

struct CompassPrivacyNote: View {
    var body: some View {
        Label(
            "Recent readings stay on this iPhone. When AI guidance is enabled, obvious personal details are redacted before a request is sent.",
            systemImage: "lock.fill"
        )
        .font(SimastryFont.captionSmall)
        .foregroundStyle(SimastryColor.deepMuted)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

struct CompassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

extension FutureQuestionCategory {
    var accentColor: Color {
        switch self {
        case .loveTiming, .messageOutcome: SimastryColor.orchidPink
        case .commitment, .privateQuestion: SimastryColor.risingViolet
        case .familyPath: SimastryColor.sageGreen
        case .careerSuccess: SimastryColor.celestialBlue
        case .moneyDirection: SimastryColor.gold
        }
    }
}
