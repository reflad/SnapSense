import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageEncodingError: LocalizedError {
    case invalidImageSize
    case contextCreationFailed
    case bitmapCreationFailed
    case destinationCreationFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageSize:
            return "Скриншот имеет нулевой размер."
        case .contextCreationFailed:
            return "Не удалось подготовить изображение для отправки."
        case .bitmapCreationFailed:
            return "Не удалось уменьшить изображение."
        case .destinationCreationFailed:
            return "Не удалось создать JPEG."
        case .encodingFailed:
            return "Не удалось закодировать JPEG."
        }
    }
}

enum ImageEncoder {
    static let maxDimension: CGFloat = 1280
    static let jpegQuality: CGFloat = 0.8

    /// Proportionally scales the image down to fit a 1280 px bounding box,
    /// encodes it as JPEG at 0.8 quality and returns Base64 without a prefix.
    static func jpegBase64(from image: CGImage) throws -> String {
        guard image.width > 0, image.height > 0 else {
            throw ImageEncodingError.invalidImageSize
        }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(1, maxDimension / max(width, height))
        let targetWidth = max(1, Int((width * scale).rounded()))
        let targetHeight = max(1, Int((height * scale).rounded()))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ImageEncodingError.contextCreationFailed
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )

        guard let scaledImage = context.makeImage() else {
            throw ImageEncodingError.bitmapCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageEncodingError.destinationCreationFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ]
        CGImageDestinationAddImage(
            destination,
            scaledImage,
            properties as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw ImageEncodingError.encodingFailed
        }

        return (data as Data).base64EncodedString()
    }
}
