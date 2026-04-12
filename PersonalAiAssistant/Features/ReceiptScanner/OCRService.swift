import UIKit
import Vision

enum OCRServiceError: Error {
    case noTextFound
    case recognitionFailed(String)
}

struct OCRService {
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.recognitionFailed("Failed to get CGImage from UIImage")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRServiceError.recognitionFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRServiceError.noTextFound)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                if text.isEmpty {
                    continuation.resume(throwing: OCRServiceError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.revision = VNRecognizeTextRequestRevision3
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRServiceError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
