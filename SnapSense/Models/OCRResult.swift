import CoreGraphics
import Foundation

/// One recognized line of text together with its normalized Vision bounding box.
///
/// `boundingBox` uses Vision's coordinate space: origin at the bottom-left of
/// the image, values normalized to 0...1. Keeping this data (instead of only
/// the joined string) is what makes the later translation overlay possible.
struct OCRTextBlock: Identifiable, Equatable {
    let id: UUID
    let text: String
    let boundingBox: CGRect
    let confidence: Float

    init(
        id: UUID = UUID(),
        text: String,
        boundingBox: CGRect,
        confidence: Float
    ) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

struct OCRResult: Equatable {
    /// Blocks sorted in natural reading order (top-to-bottom, then left-to-right).
    let blocks: [OCRTextBlock]

    /// Size in pixels of the image that was passed to Vision.
    let imageSize: CGSize

    var isEmpty: Bool {
        blocks.isEmpty || fullText.isEmpty
    }

    /// Joins visual lines with a newline while keeping line wraps logical.
    ///
    /// Vision can occasionally split a single visual line into more than one
    /// observation. Blocks whose vertical centers are almost identical are
    /// therefore grouped and joined with a space, preserving real line breaks.
    var fullText: String {
        guard !blocks.isEmpty else { return "" }

        var lines: [String] = []
        var currentLine: [OCRTextBlock] = []

        for block in blocks {
            if let previous = currentLine.last,
               abs(previous.boundingBox.midY - block.boundingBox.midY) > 0.012 {
                let line = currentLine.map(\.text).joined(separator: " ")
                if !line.isEmpty { lines.append(line) }
                currentLine = [block]
            } else {
                currentLine.append(block)
            }
        }

        if !currentLine.isEmpty {
            let line = currentLine.map(\.text).joined(separator: " ")
            if !line.isEmpty { lines.append(line) }
        }

        return lines.joined(separator: "\n")
    }

    var characterCount: Int {
        fullText.count
    }
}
