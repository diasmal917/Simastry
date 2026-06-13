import SwiftUI
import PhotosUI

/// Private photo wall on the Me tab. Photos never leave the device; the
/// user's panel guides show up in the comments.
struct MomentsSection: View {
    @Bindable var viewModel: AppViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var captionDraft: String = ""
    @State private var showCaptionSheet: Bool = false
    @State private var selectedMoment: Moment?
    @State private var momentPendingDeletion: Moment?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.moments.isEmpty {
                emptyState
            } else {
                momentsGrid
            }

            addMomentButton
        }
        .padding(16)
        .surfaceCard(cornerRadius: 24)
        .onChange(of: pickerItem) {
            guard let pickerItem else { return }
            Task {
                do {
                    guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                        viewModel.showToast("Moment not added", subtitle: "Choose a different photo and try again.", isError: true)
                        self.pickerItem = nil
                        return
                    }
                    pendingImageData = data
                    captionDraft = ""
                    showCaptionSheet = true
                } catch {
                    viewModel.showToast("Moment not added", subtitle: "The photo could not be loaded.", isError: true)
                }
                self.pickerItem = nil
            }
        }
        .sheet(isPresented: $showCaptionSheet) {
            captionSheet
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMoment) { moment in
            MomentDetailSheet(viewModel: viewModel, momentId: moment.id)
        }
        .confirmationDialog(
            "Delete this moment?",
            isPresented: Binding(
                get: { momentPendingDeletion != nil },
                set: { if !$0 { momentPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Moment", role: .destructive) {
                if let moment = momentPendingDeletion {
                    withAnimation(.spring(SimastrySpring.snappy)) {
                        viewModel.deleteMoment(moment)
                    }
                }
                momentPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                momentPendingDeletion = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimastryColor.gold)

                Text("MOMENTS")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.textSecondary)
                    .tracking(1.5)

                Spacer()

                if !viewModel.moments.isEmpty {
                    Text("\(viewModel.moments.count)")
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(SimastryColor.textTertiary)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: SimastryIcon.privacy)
                    .font(.system(size: 9, weight: .medium))
                Text("Moments stay on this device.")
                    .font(SimastryFont.captionSmall)
            }
            .foregroundStyle(SimastryColor.deepMuted)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(SimastryColor.gold.opacity(0.7))

            Text("Share a moment — your panel always shows up for you.")
                .font(SimastryFont.bodySmall)
                .foregroundStyle(SimastryColor.mutedSilver)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private var momentsGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.moments) { moment in
                Button {
                    HapticManager.buttonPress()
                    selectedMoment = moment
                } label: {
                    momentThumbnail(moment)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        momentPendingDeletion = moment
                    } label: {
                        Label("Delete Moment", systemImage: "trash")
                    }
                }
                .accessibilityLabel("Moment\(moment.caption.map { ": \($0)" } ?? ""), \(moment.comments.count) comments")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func momentThumbnail(_ moment: Moment) -> some View {
        Rectangle()
            .fill(SimastryColor.surfaceSunken)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                MomentImageView(url: viewModel.momentThumbURL(for: moment))
            }
            .overlay(alignment: .bottomTrailing) {
                if !moment.comments.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: SimastryIcon.quote)
                            .font(.system(size: 8, weight: .bold))
                        Text("\(moment.comments.count)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(5)
                }
            }
            .clipped()
            .contentShape(.rect)
    }

    private var addMomentButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Add a moment")
                    .font(SimastryFont.labelLarge)
            }
            .foregroundStyle(SimastryColor.midnight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(SimastryGradient.gold, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
            }
        }
        .buttonStyle(SpringPressStyle())
        .accessibilityLabel("Add a moment from your photo library")
    }

    private var captionSheet: some View {
        ZStack {
            SimastryColor.midnight.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("ADD A CAPTION")
                    .font(SimastryFont.overline)
                    .foregroundStyle(SimastryColor.gold)
                    .tracking(2.0)
                    .padding(.top, 22)

                Text("Optional — your guides read your words, not your photos.")
                    .font(SimastryFont.caption)
                    .foregroundStyle(SimastryColor.mutedSilver)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Say something about this moment", text: $captionDraft, axis: .vertical)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .tint(SimastryColor.gold)
                    .lineLimit(2...3)
                    .padding(14)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: captionDraft) {
                        if captionDraft.count > 140 {
                            captionDraft = String(captionDraft.prefix(140))
                        }
                    }

                GoldButton("Post Moment") {
                    if let data = pendingImageData {
                        withAnimation(.spring(SimastrySpring.smooth)) {
                            _ = viewModel.addMoment(imageData: data, caption: captionDraft)
                        }
                    }
                    pendingImageData = nil
                    showCaptionSheet = false
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

// MARK: - Detail Sheet

struct MomentDetailSheet: View {
    @Bindable var viewModel: AppViewModel
    let momentId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var commentDraft: String = ""
    @State private var showDeleteConfirmation: Bool = false

    private var moment: Moment? {
        viewModel.moments.first { $0.id == momentId }
    }

    private var typingEntries: [PanelMatcher.Entry] {
        viewModel.panelGuideEntries.filter {
            viewModel.momentTypingKeys.contains("\(momentId.uuidString):\($0.profile.id)")
        }
    }

    private var trimmedComment: String {
        commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackground()

                if let moment {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            momentImage(moment)

                            if let caption = moment.caption {
                                Text(caption)
                                    .font(SimastryFont.bodyMedium)
                                    .foregroundStyle(SimastryColor.offWhite)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .surfaceCard(cornerRadius: 16)
                            }

                            reactionRow(moment)

                            commentsSection(moment)
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(SimastryColor.sunCoral)
                    }
                    .accessibilityLabel("Delete moment")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(SimastryColor.gold)
                }
            }
            .confirmationDialog("Delete this moment?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Moment", role: .destructive) {
                    if let moment {
                        viewModel.deleteMoment(moment)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func momentImage(_ moment: Moment) -> some View {
        Rectangle()
            .fill(SimastryColor.surfaceSunken)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                MomentImageView(url: viewModel.momentImageURL(for: moment))
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
            }
    }

    private func reactionRow(_ moment: Moment) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "heart.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SimastryColor.sunCoral)

            Text(moment.reactionCount > 0 ? "\(moment.reactionCount) from your panel" : "Your panel is on its way")
                .font(SimastryFont.labelMedium)
                .foregroundStyle(SimastryColor.mutedSilver)

            Spacer()

            Text(SimastryDateFormatter.compactDate.string(from: moment.createdAt))
                .font(SimastryFont.captionSmall)
                .foregroundStyle(SimastryColor.textTertiary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func commentsSection(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMMENTS")
                .font(SimastryFont.overline)
                .foregroundStyle(SimastryColor.textSecondary)
                .tracking(1.4)

            ForEach(moment.comments) { comment in
                commentRow(comment)
            }

            ForEach(typingEntries) { entry in
                HStack(spacing: 10) {
                    guideAvatar(entry.profile, size: 26)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(SimastryColor.mutedSilver.opacity(0.5))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.05), in: Capsule())
                }
                .transition(.opacity)
            }

            HStack(spacing: 8) {
                TextField("Add a comment", text: $commentDraft)
                    .font(SimastryFont.bodyMedium)
                    .foregroundStyle(SimastryColor.offWhite)
                    .tint(SimastryColor.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.06), in: Capsule())
                    .onChange(of: commentDraft) {
                        if commentDraft.count > 180 {
                            commentDraft = String(commentDraft.prefix(180))
                        }
                    }

                Button {
                    viewModel.addUserComment(trimmedComment, to: momentId)
                    commentDraft = ""
                    HapticManager.buttonPress()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(trimmedComment.isEmpty ? SimastryColor.mutedSilver : SimastryColor.midnight)
                        .frame(width: 34, height: 34)
                        .background(trimmedComment.isEmpty ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(SimastryGradient.gold), in: Circle())
                }
                .disabled(trimmedComment.isEmpty)
                .buttonStyle(SpringPressStyle())
                .accessibilityLabel("Add comment")
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
        .animation(.spring(SimastrySpring.smooth), value: viewModel.momentTypingKeys)
    }

    @ViewBuilder
    private func commentRow(_ comment: MomentComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            switch comment.authorKind {
            case .guide(let profileId):
                if let entry = viewModel.panelGuideEntry(forParticipantId: profileId) {
                    guideAvatar(entry.profile, size: 26)
                } else {
                    fallbackAvatar
                }
            case .user:
                userAvatar
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(comment.authorName)
                        .font(SimastryFont.labelSmall)
                        .foregroundStyle(authorColor(for: comment))
                        .lineLimit(1)

                    if case .guide = comment.authorKind {
                        Text("AI")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(.white.opacity(0.07), in: Capsule())
                    }
                }

                Text(comment.content)
                    .font(SimastryFont.bodySmall)
                    .foregroundStyle(SimastryColor.offWhite.opacity(0.88))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.authorName): \(comment.content)")
    }

    private func authorColor(for comment: MomentComment) -> Color {
        if case .guide(let profileId) = comment.authorKind,
           let entry = viewModel.panelGuideEntry(forParticipantId: profileId) {
            return entry.sign.color
        }
        return SimastryColor.goldLight
    }

    private func guideAvatar(_ profile: FactoryCompanionProfile, size: CGFloat) -> some View {
        Image(profile.profileImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .top)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(profile.sign.color.opacity(0.55), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var userAvatar: some View {
        Circle()
            .fill(SimastryColor.gold.opacity(0.18))
            .frame(width: 26, height: 26)
            .overlay {
                Text(String((viewModel.profile?.displayName ?? "Y").prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SimastryColor.goldLight)
            }
            .accessibilityHidden(true)
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(SimastryColor.gold.opacity(0.18))
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: SimastryIcon.astrologers)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SimastryColor.gold)
            }
            .accessibilityHidden(true)
    }
}
