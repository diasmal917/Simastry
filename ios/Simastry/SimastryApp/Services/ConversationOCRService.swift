import Foundation
import Vision
import UIKit

nonisolated enum ConversationOCRError: LocalizedError, Sendable {
    case unreadableImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "Couldn't read that image. Try a different screenshot."
        case .noTextFound:
            "No text found in that screenshot. Try one that shows the conversation."
        }
    }
}

/// On-device screenshot-to-text via Apple Vision. The image never leaves the
/// device — recognition runs locally and only the recognized text continues
/// into the (privacy-redacted) prediction flow.
nonisolated enum ConversationOCRService {
    static func recognizeText(in imageData: Data) async throws -> String {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw ConversationOCRError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try await Task.detached(priority: .userInitiated) {
            try handler.perform([request])
        }.value

        let observations = request.results ?? []

        // Vision's normalized coordinates put the origin bottom-left; sort so
        // lines read top-to-bottom like the original conversation.
        let lines = observations
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ConversationOCRError.noTextFound
        }

        return lines.joined(separator: "\n")
    }
}
