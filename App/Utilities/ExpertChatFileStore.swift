import Foundation

/// File-backed persistence for expert consultations. Replaces the old
/// UserDefaults blobs — which loaded synchronously at launch and grew without
/// bound — with capped, atomically written JSON files. Legacy defaults data
/// migrates once on first load, then the keys are removed.
nonisolated enum ExpertChatFileStore {
    static let maxStoredMessages = 600
    static let maxStoredResponses = 300

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SimastryExpertChats", isDirectory: true)
    }

    private static var messagesURL: URL {
        directoryURL.appendingPathComponent("specialist_messages.json")
    }

    private static var responsesURL: URL {
        directoryURL.appendingPathComponent("consultation_responses.json")
    }

    /// nil means "no file yet" (fresh install or pre-migration) — distinct
    /// from an empty history, so callers know to try the legacy defaults.
    static func loadMessages() -> [SpecialistMessage]? {
        guard let data = try? Data(contentsOf: messagesURL) else { return nil }
        return try? decoder().decode([SpecialistMessage].self, from: data)
    }

    static func loadResponses() -> [SpecialistConsultationResponse]? {
        guard let data = try? Data(contentsOf: responsesURL) else { return nil }
        return try? decoder().decode([SpecialistConsultationResponse].self, from: data)
    }

    /// Messages arrive sorted oldest-first; the cap keeps the most recent.
    static func saveMessages(_ messages: [SpecialistMessage]) {
        write(Array(messages.suffix(maxStoredMessages)), to: messagesURL)
    }

    static func saveResponses(_ responses: [SpecialistConsultationResponse]) {
        write(Array(responses.suffix(maxStoredResponses)), to: responsesURL)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: messagesURL)
        try? FileManager.default.removeItem(at: responsesURL)
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            CrashReporter.log(error, context: "expertChatFileStoreWrite")
        }
    }
}
