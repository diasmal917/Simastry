import Foundation
import Vision

nonisolated enum ConversationOCRError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "We couldn't read text from that image."
        }
    }
}

enum ConversationOCRService {
    static func recognizeText(in data: Data) async throws -> String {
        throw ConversationOCRError.unreadableImage
    }
}
