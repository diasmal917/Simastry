import SwiftUI

// MARK: - Sheet Types

private enum SavedGuidesSheet: Identifiable {
    case addGuide
    case guideDetail(SavedGuide)
    case editGuide(SavedGuide)

    var id: String {
        switch self {
        case .addGuide: "add"
        case .guideDetail(let g): "detail_\(g.id)"
        case .editGuide(let g): "edit_\(g.id)"
        }
    }
}

// MARK: - Main View

struct SavedGuidesView: View {
    @Bindable var viewModel: AppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var appeared: Bool = false
    @State private var activeSheet: SavedGuidesSheet?

    private var groupedGuides: [(GuideCategory, [SavedGuide])] {
        let grouped = Dictionary(grouping: viewModel.savedGuides, by: \.category)
        return GuideCategory.allCases.compactMap { category in
            guard let guides = grouped[category], !guides.isEmpty else { return nil }
            return (category, guides.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if viewModel.savedGuides.isEmpty {
                    emptyState
                } else {
                    guidesList
                }
            }
            .navigationTitle("My Guides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.buttonPress()
                        if viewModel.canAddGuide {
                            activeSheet = .addGuide
                        } else {
                            viewModel.showToast("Guide limit reached", subtitle: "Upgrade to save more guides", isError: true)
                            viewModel.showUpsell = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SimastryColor.gold)
                    }
                    .accessibilityLabel("Add a new guide")
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addGuide:
                    AddGuideSheet(viewModel: viewModel)
                case .guideDetail(let guide):
                    GuideDetailSheet(viewModel: viewModel, guide: guide) {
                        activeSheet = .editGuide(guide)
                    }
                case .editGuide(let guide):
                    EditGuideSheet(viewModel: viewModel, guide: guide)
                }
            }
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                        appeared = true
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "text.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(SimastryColor.celestialBlue.opacity(0.5))

            VStack(spacing: 10) {
                Text("No Saved Guides Yet")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("Save guides for people in your life — your boss, siblings, friends — so you always know how to approach them.")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Button {
                HapticManager.buttonPress()
                activeSheet = .addGuide
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Save Your First Guide")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.midnight)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(SimastryColor.gold, in: .capsule)
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Save your first communication guide")

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Guides List

    private var guidesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 8)

                // Usage indicator
                if viewModel.savedGuideLimit != .max {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(SimastryColor.gold)
                        Text("\(viewModel.savedGuides.count)/\(viewModel.savedGuideLimit) guides saved")
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .padding(.horizontal, 20)
                }

                ForEach(groupedGuides, id: \.0) { category, guides in
                    categorySection(category: category, guides: guides)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func categorySection(category: GuideCategory, guides: [SavedGuide]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
            }

            ForEach(guides) { guide in
                guideRow(guide)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func guideRow(_ guide: SavedGuide) -> some View {
        Button {
            HapticManager.buttonPress()
            activeSheet = .guideDetail(guide)
        } label: {
            HStack(spacing: 14) {
                Text(guide.sunSign.glyph)
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(guide.sunSign.color)
                    .frame(width: 44, height: 44)
                    .background(guide.sunSign.color.opacity(0.14), in: .rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.name)
                        .font(SimastryFont.titleSmall)
                        .foregroundStyle(SimastryColor.offWhite)

                    HStack(spacing: 6) {
                        Text(guide.sunSign.displayName)
                            .font(SimastryFont.labelSmall)
                            .foregroundStyle(guide.sunSign.color)

                        Image(systemName: guide.category.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SimastryColor.deepMuted)
            }
            .padding(14)
            .simastryGlass(cornerRadius: 18)
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("\(guide.name), \(guide.sunSign.displayName), \(guide.category.rawValue)")
        .contextMenu {
            Button {
                activeSheet = .editGuide(guide)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                    viewModel.deleteGuide(guide)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Guide Sheet

private struct AddGuideSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name: String = ""
    @State private var selectedSign: ZodiacSign = .aries
    @State private var selectedCategory: GuideCategory = .friends
    @State private var notes: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 12)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Person's Name")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            TextField("e.g. Sarah, Dad, Boss", text: $name)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .padding(14)
                                .simastryGlass(cornerRadius: 14)
                                .focused($nameFieldFocused)
                                .accessibilityLabel("Person's name")
                        }

                        // Zodiac sign picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Their Sun Sign")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            zodiacGrid
                        }

                        // Category picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            categoryChips
                        }

                        // Notes field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            TextField("Anything to remember...", text: $notes, axis: .vertical)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(3...6)
                                .padding(14)
                                .simastryGlass(cornerRadius: 14)
                                .accessibilityLabel("Optional notes")
                        }

                        // Upsell if at limit
                        if !viewModel.canAddGuide {
                            upsellBanner
                        }

                        // Save button
                        Button {
                            HapticManager.buttonPress()
                            viewModel.addGuide(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                sunSign: selectedSign,
                                category: selectedCategory,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            dismiss()
                        } label: {
                            Text("Save Guide")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.midnight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(SimastryColor.gold, in: .capsule)
                        }
                        .buttonStyle(SpringPressStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.canAddGuide)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.canAddGuide ? 0.5 : 1)
                        .accessibilityLabel("Save communication guide")

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFieldFocused = false }
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { CelestialBackground() }
    }

    private var zodiacGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
            ForEach(ZodiacSign.allCases) { sign in
                Button {
                    HapticManager.zodiacSelection()
                    withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                        selectedSign = sign
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(sign.glyph)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(sign.color)
                            .frame(width: 44, height: 44)
                            .background(sign.color.opacity(selectedSign == sign ? 0.24 : 0.10), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(selectedSign == sign ? sign.color.opacity(0.6) : .clear, lineWidth: 2)
                            }

                        Text(sign.displayName)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(selectedSign == sign ? sign.color : SimastryColor.mutedSilver)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("\(sign.displayName)")
                .accessibilityHint(selectedSign == sign ? "Currently selected" : "Tap to select")
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(GuideCategory.allCases, id: \.self) { category in
                    Button {
                        HapticManager.buttonPress()
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(category.rawValue)
                                .font(SimastryFont.labelMedium)
                        }
                        .foregroundStyle(selectedCategory == category ? SimastryColor.midnight : category.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            selectedCategory == category ? category.color : category.color.opacity(0.12),
                            in: .capsule
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("\(category.rawValue) category")
                    .accessibilityHint(selectedCategory == category ? "Currently selected" : "Tap to select")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var upsellBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(SimastryColor.gold)

            VStack(alignment: .leading, spacing: 3) {
                Text("Guide limit reached")
                    .font(SimastryFont.labelLarge)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Upgrade to save more people")
                    .font(SimastryFont.labelSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }

            Spacer()

            Button {
                viewModel.showUpsell = true
            } label: {
                Text("Upgrade")
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(SimastryColor.midnight)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SimastryColor.gold, in: .capsule)
            }
            .buttonStyle(SpringPressStyle())
        }
        .padding(16)
        .tintedGlass(SimastryColor.gold.opacity(0.12), cornerRadius: 18)
    }
}

// MARK: - Guide Detail Sheet

private struct GuideDetailSheet: View {
    let viewModel: AppViewModel
    let guide: SavedGuide
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer().frame(height: 8)

                        // Header
                        headerSection

                        // Category and notes
                        metadataSection

                        // Communication guide content
                        if let guideData = CommunicationTemplates.guides[guide.sunSign] {
                            bestApproachSection(guideData)
                            tipsSection(guideData)
                            avoidSection(guideData)
                        }

                        // Action buttons
                        actionsSection

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onEdit()
                            }
                        } label: {
                            Label("Edit Guide", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            viewModel.deleteGuide(guide)
                            dismiss()
                        } label: {
                            Label("Delete Guide", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(SimastryColor.mutedSilver)
                    }
                    .accessibilityLabel("Guide options")
                }
            }
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(SimastrySpring.smooth).delay(0.1)) {
                        appeared = true
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { CelestialBackground() }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(guide.sunSign.glyph)
                .font(SimastryFont.displayMedium)
                .foregroundStyle(guide.sunSign.color)
                .frame(width: 56, height: 56)
                .background(guide.sunSign.color.opacity(0.14), in: .rect(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(guide.name)'s Communication Guide")
                    .font(SimastryFont.titleMedium)
                    .foregroundStyle(SimastryColor.offWhite)

                Text("\(guide.sunSign.displayName) \(guide.sunSign.glyph)")
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(guide.sunSign.color)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: guide.category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(guide.category.color)
                Text(guide.category.rawValue)
                    .font(SimastryFont.labelMedium)
                    .foregroundStyle(guide.category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(guide.category.color.opacity(0.14), in: .capsule)
            }

            if let notes = guide.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Notes")
                        .font(SimastryFont.overline)
                        .foregroundStyle(SimastryColor.mutedSilver)
                        .tracking(1.2)
                        .textCase(.uppercase)

                    Text(notes)
                        .font(SimastryFont.bodyLarge)
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.8))
                        .lineSpacing(3)
                }
                .padding(14)
                .simastryGlass(cornerRadius: 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private func bestApproachSection(_ guideData: CommunicationGuideData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Best Approach")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SimastryColor.gold.opacity(0.8))
                .tracking(1.8)

            Text(personalizeText(guideData.bestApproach))
                .font(.system(.body, design: .serif, weight: .semibold))
                .italic()
                .foregroundStyle(SimastryColor.gold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .goldGlassRect(cornerRadius: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func tipsSection(_ guideData: CommunicationGuideData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Communication Tips")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SimastryColor.mutedSilver)
                .tracking(1.8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guideData.tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: index.isMultiple(of: 2) ? "sparkles" : "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SimastryColor.gold)
                            .frame(width: 18, height: 18)
                            .padding(.top, 2)

                        Text(personalizeText(tip))
                            .font(.subheadline)
                            .foregroundStyle(SimastryColor.offWhite.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func avoidSection(_ guideData: CommunicationGuideData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimastryColor.sunCoral)

                Text("What to Avoid")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SimastryColor.sunCoral)
                    .tracking(1.4)
            }

            Text(personalizeText(guideData.avoid))
                .font(.subheadline)
                .foregroundStyle(SimastryColor.offWhite.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .tintedGlass(SimastryColor.sunCoral.opacity(0.16), cornerRadius: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Share button
            ShareLink(
                item: shareText,
                subject: Text("\(guide.name)'s Communication Guide"),
                message: Text("Here's how to communicate with \(guide.name)")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share Guide")
                        .font(SimastryFont.labelLarge)
                }
                .foregroundStyle(SimastryColor.celestialBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .simastryGlass(cornerRadius: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SimastryColor.celestialBlue.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(SpringPressStyle())
            .accessibilityLabel("Share \(guide.name)'s communication guide")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var shareText: String {
        guard let guideData = CommunicationTemplates.guides[guide.sunSign] else {
            return "\(guide.name) is a \(guide.sunSign.displayName) \(guide.sunSign.glyph)"
        }
        var text = "\(guide.sunSign.glyph) \(guide.name)'s Communication Guide (\(guide.sunSign.displayName))\n\n"
        text += "Best Approach: \(guideData.bestApproach)\n\n"
        text += "Tips:\n"
        for tip in guideData.tips {
            text += "- \(tip)\n"
        }
        text += "\nWhat to Avoid: \(guideData.avoid)\n\n"
        text += "Made with Simastry"
        return text
    }

    private func personalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "they ", with: "\(guide.name) ", options: [])
            .replacingOccurrences(of: "They ", with: "\(guide.name) ", options: [])
            .replacingOccurrences(of: "them ", with: "\(guide.name) ", options: [])
            .replacingOccurrences(of: "their ", with: "\(guide.name)'s ", options: [])
            .replacingOccurrences(of: "Their ", with: "\(guide.name)'s ", options: [])
    }
}

// MARK: - Edit Guide Sheet

private struct EditGuideSheet: View {
    let viewModel: AppViewModel
    let guide: SavedGuide

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name: String = ""
    @State private var selectedSign: ZodiacSign = .aries
    @State private var selectedCategory: GuideCategory = .friends
    @State private var notes: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 12)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Person's Name")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            TextField("e.g. Sarah, Dad, Boss", text: $name)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .padding(14)
                                .simastryGlass(cornerRadius: 14)
                                .focused($nameFieldFocused)
                                .accessibilityLabel("Person's name")
                        }

                        // Zodiac sign picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Their Sun Sign")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            zodiacGrid
                        }

                        // Category picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            categoryChips
                        }

                        // Notes field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.offWhite)

                            TextField("Anything to remember...", text: $notes, axis: .vertical)
                                .font(SimastryFont.bodyMedium)
                                .foregroundStyle(SimastryColor.offWhite)
                                .lineLimit(3...6)
                                .padding(14)
                                .simastryGlass(cornerRadius: 14)
                                .accessibilityLabel("Optional notes")
                        }

                        // Save button
                        Button {
                            HapticManager.buttonPress()
                            var updated = guide
                            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.sunSign = selectedSign
                            updated.category = selectedCategory
                            updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.updateGuide(updated)
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(SimastryFont.labelLarge)
                                .foregroundStyle(SimastryColor.midnight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(SimastryColor.gold, in: .capsule)
                        }
                        .buttonStyle(SpringPressStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        .accessibilityLabel("Save changes to guide")

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Edit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(SimastryFont.bodySmall)
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFieldFocused = false }
                }
            }
            .onAppear {
                name = guide.name
                selectedSign = guide.sunSign
                selectedCategory = guide.category
                notes = guide.notes ?? ""
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { CelestialBackground() }
    }

    private var zodiacGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
            ForEach(ZodiacSign.allCases) { sign in
                Button {
                    HapticManager.zodiacSelection()
                    withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                        selectedSign = sign
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(sign.glyph)
                            .font(SimastryFont.titleMedium)
                            .foregroundStyle(sign.color)
                            .frame(width: 44, height: 44)
                            .background(sign.color.opacity(selectedSign == sign ? 0.24 : 0.10), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(selectedSign == sign ? sign.color.opacity(0.6) : .clear, lineWidth: 2)
                            }

                        Text(sign.displayName)
                            .font(SimastryFont.captionSmall)
                            .foregroundStyle(selectedSign == sign ? sign.color : SimastryColor.mutedSilver)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("\(sign.displayName)")
                .accessibilityHint(selectedSign == sign ? "Currently selected" : "Tap to select")
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(GuideCategory.allCases, id: \.self) { category in
                    Button {
                        HapticManager.buttonPress()
                        withAnimation(reduceMotion ? .default : .spring(SimastrySpring.snappy)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(category.rawValue)
                                .font(SimastryFont.labelMedium)
                        }
                        .foregroundStyle(selectedCategory == category ? SimastryColor.midnight : category.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            selectedCategory == category ? category.color : category.color.opacity(0.12),
                            in: .capsule
                        )
                    }
                    .buttonStyle(SpringPressStyle())
                    .accessibilityLabel("\(category.rawValue) category")
                    .accessibilityHint(selectedCategory == category ? "Currently selected" : "Tap to select")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
