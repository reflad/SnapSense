import CoreGraphics
import Foundation
import Vision

/// Local OCR powered by Apple Vision. No image or recognized text leaves the Mac.
final class OCRService {
    func recognizeText(in image: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["ru-RU", "en-US"]
                    request.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])

                    let observations = request.results ?? []
                    let blocks = Self.makeBlocks(from: observations)
                    let result = OCRResult(
                        blocks: blocks,
                        imageSize: CGSize(width: image.width, height: image.height)
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(
                        throwing: SnapSenseError.ocrFailed(error.localizedDescription)
                    )
                }
            }
        }
    }

    private static func makeBlocks(
        from observations: [VNRecognizedTextObservation]
    ) -> [OCRTextBlock] {
        let blocks: [OCRTextBlock] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            return OCRTextBlock(
                text: text,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }

        return blocks.sorted { lhs, rhs in
            let verticalDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if verticalDelta > 0.012 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }
}
