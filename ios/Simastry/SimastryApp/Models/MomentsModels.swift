import SwiftUI

/// A guide's (or the user's) comment under a Moment.
nonisolated struct MomentComment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let authorKind: PanelSenderKind
    let authorName: String
    let content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        authorKind: PanelSenderKind,
        authorName: String,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.authorKind = authorKind
        self.authorName = authorName
        self.content = content
        self.timestamp = timestamp
    }
}

/// A private photo post on the user's own profile. Device-local only.
nonisolated struct Moment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var caption: String?
    var imageFileName: String
    var createdAt: Date
    var reactionCount: Int
    var comments: [MomentComment]

    init(
        id: UUID = UUID(),
        caption: String? = nil,
        imageFileName: String,
        createdAt: Date = Date(),
        reactionCount: Int = 0,
        comments: [MomentComment] = []
    ) {
        self.id = id
        self.caption = caption
        self.imageFileName = imageFileName
        self.createdAt = createdAt
        self.reactionCount = reactionCount
        self.comments = comments
    }
}

/// File-backed store for Moments: an index JSON plus one JPEG per moment in
/// Application Support. Mirrors RelationshipPeopleStore; the directory is
/// injectable so tests run against a temp location.
final class MomentsStore {
    private let indexFileName = "moments.json"
    private let customDirectoryURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil) {
        customDirectoryURL = directoryURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [Moment] {
        guard let data = try? Data(contentsOf: indexURL),
              let moments = try? decoder.decode([Moment].self, from: data) else {
            return []
        }
        return moments
    }

    func save(_ moments: [Moment]) {
        guard let data = try? encoder.encode(moments) else { return }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: indexURL, options: [.atomic])
    }

    @discardableResult
    func writeImage(_ data: Data, fileName: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: imageURL(for: fileName), options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    func imageURL(for fileName: String) -> URL {
        directoryURL.appending(path: fileName)
    }

    func deleteImage(fileName: String) {
        try? FileManager.default.removeItem(at: imageURL(for: fileName))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private var directoryURL: URL {
        if let customDirectoryURL {
            return customDirectoryURL
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appending(path: "Simastry", directoryHint: .isDirectory)
            .appending(path: "Moments", directoryHint: .isDirectory)
    }

    private var indexURL: URL {
        directoryURL.appending(path: indexFileName)
    }
}

enum MomentPhoto {
    /// Downscales and re-encodes a picked photo for on-device storage.
    static func prepared(_ data: Data, maxDimension: CGFloat = 1080) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
