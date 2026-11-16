import CoreGraphics

/// The exact visual and textual content behind the capture currently shown in
/// the HUD. Kept as one value so every AI preset receives consistent data.
struct AICaptureContext {
    let image: CGImage
    let ocrResult: OCRResult
    let selection: CaptureSelection

    var ocrText: String {
        ocrResult.fullText
    }
}
