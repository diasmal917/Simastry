import Foundation
import UIKit
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
        guard let cgImage = UIImage(data: data)?.cgImage else {
            throw ConversationOCRError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { observation -> (text: String, frame: CGRect)? in
                guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else {
                    return nil
                }
                return (text, observation.boundingBox)
            }
            .sorted { lhs, rhs in
                if abs(lhs.frame.midY - rhs.frame.midY) > 0.03 {
                    return lhs.frame.midY > rhs.frame.midY
                }
                return lhs.frame.minX < rhs.frame.minX
            }
            .map(\.text)

        guard !lines.isEmpty else {
            throw ConversationOCRError.unreadableImage
        }
        return lines.joined(separator: "\n")
    }
}
