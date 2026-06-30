import Foundation
import UIKit

// MARK: - Subject

/// Who an uploaded chart screenshot belongs to. Drives `subject_type`,
/// `person_id`, and the storage path.
nonisolated enum ExpertChartSubject: Equatable, Sendable {
    case userSelf
    case person(RelationshipPerson)

    var subjectType: String {
        switch self {
        case .userSelf: "self"
        case .person: "person"
        }
    }

    var personId: UUID? {
        switch self {
        case .userSelf: nil
        case .person(let person): person.id
        }
    }

    /// Storage object path. The first segment must be the lowercased user id:
    /// Postgres renders `user_id::text` lowercase, and both the table check and
    /// the storage RLS policy compare against it.
    func storagePath(userId: UUID, importId: UUID, fileExtension: String) -> String {
        let owner = userId.uuidString.lowercased()
        let file = "\(importId.uuidString.lowercased()).\(fileExtension)"
        switch self {
        case .userSelf:
            return "\(owner)/self/\(file)"
        case .person(let person):
            return "\(owner)/people/\(person.id.uuidString.lowercased())/\(file)"
        }
    }
}

nonisolated enum ExpertChartImportStatus: String, Codable, Sendable {
    case uploaded
    case extracted
    case needsReview = "needs_review"
    case confirmed
    case failed
}

// MARK: - Chart import record

/// One row of `public.expert_astrology_chart_imports`. `extracted_data` is
/// untrusted machine output (never used as chart fact); only `confirmed_data`
/// is prompt-safe, and even that is user-supplied/extracted, not app-calculated.
nonisolated struct ExpertChartImportRecord: Codable, Equatable, Identifiable, Sendable {
    static let bucket = "expert-astrology-charts"

    var id: UUID
    var userId: UUID
    var subjectType: String
    var personId: UUID?
    var storageBucket: String
    var storagePath: String
    var status: String
    var extractedData: [String: String]
    var confirmedData: [String: String]
    var extractionWarnings: [String]
    var sourceLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subjectType = "subject_type"
        case personId = "person_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case status
        case extractedData = "extracted_data"
        case confirmedData = "confirmed_data"
        case extractionWarnings = "extraction_warnings"
        case sourceLabel = "source_label"
    }

    init(
        id: UUID,
        userId: UUID,
        subjectType: String,
        personId: UUID?,
        storagePath: String,
        status: String,
        extractedData: [String: String] = [:],
        confirmedData: [String: String] = [:],
        extractionWarnings: [String] = [],
        sourceLabel: String?
    ) {
        self.id = id
        self.userId = userId
        self.subjectType = subjectType
        self.personId = personId
        self.storageBucket = ExpertChartImportRecord.bucket
        self.storagePath = storagePath
        self.status = status
        self.extractedData = extractedData
        self.confirmedData = confirmedData
        self.extractionWarnings = extractionWarnings
        self.sourceLabel = sourceLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        subjectType = try container.decodeIfPresent(String.self, forKey: .subjectType) ?? "self"
        personId = try container.decodeIfPresent(UUID.self, forKey: .personId)
        storageBucket = try container.decodeIfPresent(String.self, forKey: .storageBucket) ?? ExpertChartImportRecord.bucket
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ExpertChartImportStatus.uploaded.rawValue
        // Resilient: any non-string-map shape is treated as empty rather than failing.
        extractedData = (try? container.decode([String: String].self, forKey: .extractedData)) ?? [:]
        confirmedData = (try? container.decode([String: String].self, forKey: .confirmedData)) ?? [:]
        extractionWarnings = (try? container.decode([String].self, forKey: .extractionWarnings)) ?? []
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
    }

    /// Encodes every insert column (emitting nulls) so an insert is a full row.
    /// `created_at`/`updated_at` are DB-managed and intentionally omitted.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(subjectType, forKey: .subjectType)
        try container.encode(personId, forKey: .personId)
        try container.encode(storageBucket, forKey: .storageBucket)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encode(status, forKey: .status)
        try container.encode(extractedData, forKey: .extractedData)
        try container.encode(confirmedData, forKey: .confirmedData)
        try container.encode(extractionWarnings, forKey: .extractionWarnings)
        try container.encode(sourceLabel, forKey: .sourceLabel)
    }

    var statusValue: ExpertChartImportStatus? {
        ExpertChartImportStatus(rawValue: status)
    }

    var isConfirmed: Bool {
        statusValue == .confirmed
    }
}

/// Minimal update payload that moves user-confirmed fields into `confirmed_data`
/// and flips the row to `confirmed`. `extracted_data` is never touched here.
nonisolated struct ExpertChartImportConfirmation: Encodable, Sendable {
    let confirmed_data: [String: String]
    let status: String
}

// MARK: - Per-person intake record

/// One row of `public.expert_person_astrology_intake`. Birth date/time are
/// wall-clock strings; tradition data holds only whitelisted user-supplied
/// fields. Encoding emits every column so an upsert is a full snapshot.
nonisolated struct ExpertPersonAstrologyIntakeRecord: Codable, Equatable, Sendable {
    var userId: UUID
    var personId: UUID
    var displayName: String?
    var birthDate: String?
    var birthTime: String?
    var birthTimeUnknown: Bool
    var birthPlace: String?
    var userSuppliedTraditionData: [String: String]
    var chartImportId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personId = "person_id"
        case displayName = "display_name"
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthTimeUnknown = "birth_time_unknown"
        case birthPlace = "birth_place"
        case userSuppliedTraditionData = "user_supplied_tradition_data"
        case chartImportId = "chart_import_id"
    }

    init(
        userId: UUID,
        personId: UUID,
        displayName: String?,
        birthDate: String?,
        birthTime: String?,
        birthTimeUnknown: Bool,
        birthPlace: String?,
        userSuppliedTraditionData: [String: String],
        chartImportId: UUID?
    ) {
        self.userId = userId
        self.personId = personId
        self.displayName = displayName
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthTimeUnknown = birthTimeUnknown
        self.birthPlace = birthPlace
        self.userSuppliedTraditionData = userSuppliedTraditionData
        self.chartImportId = chartImportId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        personId = try container.decode(UUID.self, forKey: .personId)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
        birthTime = try container.decodeIfPresent(String.self, forKey: .birthTime)
        birthTimeUnknown = try container.decodeIfPresent(Bool.self, forKey: .birthTimeUnknown) ?? false
        birthPlace = try container.decodeIfPresent(String.self, forKey: .birthPlace)
        userSuppliedTraditionData = (try? container.decode([String: String].self, forKey: .userSuppliedTraditionData)) ?? [:]
        chartImportId = try container.decodeIfPresent(UUID.self, forKey: .chartImportId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(personId, forKey: .personId)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(birthTime, forKey: .birthTime)
        try container.encode(birthTimeUnknown, forKey: .birthTimeUnknown)
        try container.encode(birthPlace, forKey: .birthPlace)
        try container.encode(userSuppliedTraditionData, forKey: .userSuppliedTraditionData)
        try container.encode(chartImportId, forKey: .chartImportId)
    }
}

// MARK: - Confirmed-upload whitelist

/// A single confirmable field on the review screen. `key` is the backend
/// whitelist label written into `confirmed_data` (e.g. `western.sunSign`).
nonisolated struct ExpertConfirmedChartField: Identifiable, Equatable, Sendable {
    let key: String
    let label: String
    let placeholder: String
    let multiline: Bool

    var id: String { key }
}

/// The exact set of labels the backend will accept from a confirmed upload.
/// Anything outside this set is dropped before writing `confirmed_data`.
nonisolated enum ExpertConfirmedChartCatalog {
    static let western: [ExpertConfirmedChartField] = [
        .init(key: "western.sunSign", label: "Sun sign", placeholder: "e.g. Leo", multiline: false),
        .init(key: "western.moonSign", label: "Moon sign", placeholder: "e.g. Cancer", multiline: false),
        .init(key: "western.risingSign", label: "Rising sign", placeholder: "e.g. Libra", multiline: false),
        .init(key: "western.venusSign", label: "Venus sign", placeholder: "e.g. Gemini", multiline: false),
        .init(key: "western.marsSign", label: "Mars sign", placeholder: "e.g. Aries", multiline: false),
        .init(key: "western.houses", label: "Houses", placeholder: "What the screenshot shows", multiline: true),
        .init(key: "western.aspects", label: "Aspects", placeholder: "What the screenshot shows", multiline: true)
    ]

    static let tradition: [ExpertConfirmedChartField] = [
        .init(key: "vedic.nakshatra", label: "Vedic nakshatra", placeholder: "e.g. Rohini", multiline: false),
        .init(key: "vedic.siderealMoonRashi", label: "Sidereal Moon / rashi", placeholder: "e.g. Vrishabha", multiline: false),
        .init(key: "bazi.dayMaster", label: "BaZi Day Master", placeholder: "e.g. Yang Wood", multiline: false),
        .init(key: "bazi.fourPillars", label: "Four Pillars", placeholder: "Year / Month / Day / Hour", multiline: true),
        .init(key: "hellenistic.sect", label: "Hellenistic sect", placeholder: "Day or night chart", multiline: false),
        .init(key: "hellenistic.profectionYear", label: "Profection year", placeholder: "e.g. 3rd house year", multiline: false),
        .init(key: "evolutionary.relationshipPatternNotes", label: "Relationship pattern notes", placeholder: "From the screenshot", multiline: true),
        .init(key: "evolutionary.reflectionPrompts", label: "Reflection prompts", placeholder: "From the screenshot", multiline: true)
    ]

    static var all: [ExpertConfirmedChartField] { western + tradition }

    static let allowedKeys: Set<String> = Set(all.map(\.key))

    /// Keeps only whitelisted, non-empty (trimmed) values — the data that may be
    /// written to `confirmed_data`.
    static func sanitizedConfirmedData(from values: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in values where allowedKeys.contains(key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result[key] = trimmed
            }
        }
        return result
    }
}

// MARK: - Image format detection + upload prep

/// Supported chart-screenshot encodings (matches the bucket's allowed MIME set).
nonisolated enum ExpertChartImageFormat: Sendable {
    case jpeg
    case png
    case webp
    case heic
    case heif

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .webp: "webp"
        case .heic: "heic"
        case .heif: "heif"
        }
    }

    var contentType: String {
        switch self {
        case .jpeg: "image/jpeg"
        case .png: "image/png"
        case .webp: "image/webp"
        case .heic: "image/heic"
        case .heif: "image/heif"
        }
    }

    /// Sniffs the encoding from the file's magic bytes (not the file extension,
    /// which `PhotosPicker` data does not carry).
    static func detect(_ data: Data) -> ExpertChartImageFormat? {
        let bytes = [UInt8](data.prefix(16))
        guard bytes.count >= 12 else { return nil }

        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return .jpeg
        }
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return .png
        }
        // RIFF....WEBP
        if bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return .webp
        }
        // ....ftyp<brand>
        if bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
            let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
            switch brand {
            case "heic", "heix", "hevc", "hevx":
                return .heic
            case "mif1", "msf1", "heif":
                return .heif
            default:
                return nil
            }
        }
        return nil
    }
}

nonisolated enum ExpertChartUploadPreparer {
    static let maxBytes = 10_485_760 // 10 MB

    /// Returns upload-ready data + format. Supported images within the size
    /// limit pass through untouched (preserving detail for a future OCR pass);
    /// oversized or unrecognized images are re-encoded to a JPEG that fits.
    static func prepare(_ data: Data, maxBytes: Int = maxBytes) -> (data: Data, format: ExpertChartImageFormat)? {
        if let format = ExpertChartImageFormat.detect(data), data.count <= maxBytes {
            return (data, format)
        }
        guard let image = UIImage(data: data) else { return nil }
        for maxDimension in [2400.0, 1800.0, 1400.0, 1024.0] as [CGFloat] {
            if let jpeg = downscaledJPEG(image, maxDimension: maxDimension), jpeg.count <= maxBytes {
                return (jpeg, .jpeg)
            }
        }
        return nil
    }

    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat = 0.82) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
