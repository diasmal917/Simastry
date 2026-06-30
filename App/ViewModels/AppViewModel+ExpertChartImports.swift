import Foundation

extension AppViewModel {
    // MARK: - Cache accessors

    var latestSelfChartImport: ExpertChartImportRecord? {
        expertChartImports.first { $0.subjectType == ExpertChartSubject.userSelf.subjectType }
    }

    func latestChartImport(forPersonId personId: UUID) -> ExpertChartImportRecord? {
        expertChartImports.first { $0.subjectType == "person" && $0.personId == personId }
    }

    func latestChartImport(for subject: ExpertChartSubject) -> ExpertChartImportRecord? {
        switch subject {
        case .userSelf:
            return latestSelfChartImport
        case .person(let person):
            return latestChartImport(forPersonId: person.id)
        }
    }

    // MARK: - Upload + confirm

    /// Uploads a chart screenshot to private storage and records an
    /// `uploaded` chart-import row. Returns the new record for the confirm step.
    @discardableResult
    func uploadExpertChartImage(_ data: Data, subject: ExpertChartSubject) async -> ExpertChartImportRecord? {
        guard isAuthenticated else {
            showToast("Sign in to upload", subtitle: "Chart screenshots are saved to your account.", isError: true)
            return nil
        }
        guard let prepared = ExpertChartUploadPreparer.prepare(data) else {
            showToast(
                "Unsupported image",
                subtitle: "Use a JPEG, PNG, WebP, or HEIC screenshot under 10 MB.",
                isError: true
            )
            return nil
        }

        #if DEBUG
        if isDebugPreviewStateActive {
            let record = ExpertChartImportRecord(
                id: UUID(),
                userId: UUID(),
                subjectType: subject.subjectType,
                personId: subject.personId,
                storagePath: subject.storagePath(userId: UUID(), importId: UUID(), fileExtension: prepared.format.fileExtension),
                status: ExpertChartImportStatus.uploaded.rawValue,
                sourceLabel: "Uploaded chart screenshot"
            )
            upsertCachedChartImport(record)
            return record
        }
        #endif

        guard let userId = await supabase.currentUserId else {
            showToast("Sign in to upload", subtitle: "Chart screenshots are saved to your account.", isError: true)
            return nil
        }

        let importId = UUID()
        let path = subject.storagePath(userId: userId, importId: importId, fileExtension: prepared.format.fileExtension)
        let record = ExpertChartImportRecord(
            id: importId,
            userId: userId,
            subjectType: subject.subjectType,
            personId: subject.personId,
            storagePath: path,
            status: ExpertChartImportStatus.uploaded.rawValue,
            sourceLabel: "Uploaded chart screenshot"
        )

        do {
            try await supabase.uploadExpertChartImage(
                data: prepared.data,
                contentType: prepared.format.contentType,
                path: path
            )
            try await supabase.insertExpertChartImport(record)
        } catch {
            CrashReporter.log(error, context: "uploadExpertChartImage")
            showToast("Upload failed", subtitle: "We couldn't save that screenshot. Please try again.", isError: true)
            return nil
        }

        upsertCachedChartImport(record)
        if case .person(let person) = subject {
            persistPersonAstrologyIntakeIfPossible(for: person, chartImportId: importId)
        }
        return record
    }

    /// Writes the user-confirmed (whitelisted, non-empty) fields into
    /// `confirmed_data` and flips the row to `confirmed`. `extracted_data` is
    /// never written by the client and is not treated as chart fact.
    @discardableResult
    func confirmExpertChartImport(
        _ record: ExpertChartImportRecord,
        confirmedValues: [String: String],
        subject: ExpertChartSubject
    ) async -> Bool {
        let confirmed = ExpertConfirmedChartCatalog.sanitizedConfirmedData(from: confirmedValues)

        #if DEBUG
        if isDebugPreviewStateActive {
            applyConfirmedDataToCache(record, confirmed: confirmed, subject: subject)
            return true
        }
        #endif

        do {
            try await supabase.confirmExpertChartImport(id: record.id, confirmedData: confirmed)
        } catch {
            CrashReporter.log(error, context: "confirmExpertChartImport")
            showToast("Couldn't save", subtitle: "Your confirmed chart details may not be saved. Try again.", isError: true)
            return false
        }

        applyConfirmedDataToCache(record, confirmed: confirmed, subject: subject)
        return true
    }

    func refreshExpertChartImports() async {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif
        do {
            expertChartImports = try await supabase.fetchExpertChartImports()
        } catch {
            CrashReporter.log(error, context: "refreshExpertChartImports")
        }
    }

    // MARK: - Per-person intake

    func persistPersonAstrologyIntakeIfPossible(personId: UUID) {
        guard let person = relationshipPeople.first(where: { $0.id == personId }) else { return }
        persistPersonAstrologyIntakeIfPossible(
            for: person,
            chartImportId: latestChartImport(forPersonId: personId)?.id
        )
    }

    func persistPersonAstrologyIntakeIfPossible(for person: RelationshipPerson, chartImportId: UUID?) {
        guard isAuthenticated else { return }
        #if DEBUG
        if isDebugPreviewStateActive { return }
        #endif

        let draft = currentPersonAstrologyIntakeRecord(userId: UUID(), person: person, chartImportId: chartImportId)
        Task { [weak self, draft] in
            guard let self else { return }
            guard let userId = await self.supabase.currentUserId else { return }
            var record = draft
            record.userId = userId
            do {
                try await self.supabase.upsertPersonAstrologyIntake(record)
            } catch {
                CrashReporter.log(error, context: "persistPersonAstrologyIntake")
            }
        }
    }

    func currentPersonAstrologyIntakeRecord(
        userId: UUID,
        person: RelationshipPerson,
        chartImportId: UUID?
    ) -> ExpertPersonAstrologyIntakeRecord {
        let place = (person.birthPlace ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ExpertPersonAstrologyIntakeRecord(
            userId: userId,
            personId: person.id,
            displayName: person.displayName,
            birthDate: Self.formatIntakeDate(person.birthDate),
            // People carry no birth-time-unknown flag; an absent time is just absent.
            birthTime: Self.formatIntakeTime(person.birthTime),
            birthTimeUnknown: false,
            birthPlace: place.isEmpty ? nil : place,
            userSuppliedTraditionData: [:],
            chartImportId: chartImportId
        )
    }

    // MARK: - Cache helpers

    private func upsertCachedChartImport(_ record: ExpertChartImportRecord) {
        expertChartImports.removeAll { $0.id == record.id }
        expertChartImports.insert(record, at: 0)
    }

    private func applyConfirmedDataToCache(
        _ record: ExpertChartImportRecord,
        confirmed: [String: String],
        subject: ExpertChartSubject
    ) {
        var updated = record
        updated.confirmedData = confirmed
        updated.status = ExpertChartImportStatus.confirmed.rawValue
        upsertCachedChartImport(updated)
        if case .person(let person) = subject {
            persistPersonAstrologyIntakeIfPossible(for: person, chartImportId: record.id)
        }
    }
}
