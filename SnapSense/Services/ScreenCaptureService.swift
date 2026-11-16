import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Captures exactly one display with ScreenCaptureKit and crops the selected
/// region in pixel space.
struct ScreenCaptureService {
    func capture(selection: CaptureSelection) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw SnapSenseError.screenRecordingPermissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw SnapSenseError.screenCaptureFailed(error.localizedDescription)
        }

        guard let display = content.displays.first(where: {
            $0.displayID == selection.displayID
        }) else {
            throw SnapSenseError.displayUnavailable
        }

        // Exclude SnapSense's own overlay/HUD windows. This is more reliable
        // than relying on window ordering and also prevents a race where the
        // selection overlay is still fading out when the screenshot is taken.
        let ownApplication = content.applications.first {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter: SCContentFilter
        if let ownApplication {
            filter = SCContentFilter(
                display: display,
                excludingApplications: [ownApplication],
                exceptingWindows: []
            )
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }

        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        configuration.scalesToFit = false

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            if !CGPreflightScreenCaptureAccess() {
                throw SnapSenseError.screenRecordingPermissionDenied
            }
            throw SnapSenseError.screenCaptureFailed(error.localizedDescription)
        }

        return try crop(image: image, to: selection)
    }

    private func crop(image: CGImage, to selection: CaptureSelection) throws -> CGImage {
        guard selection.rect.width > 0, selection.rect.height > 0 else {
            throw SnapSenseError.emptySelection
        }

        // Start from the Retina backing scale and correct against the actual
        // captured bitmap. Usually these are identical (2x/1x), but deriving
        // the final scale also keeps cropping exact in scaled display modes.
        var pixelsPerPointX = selection.backingScaleFactor
        var pixelsPerPointY = selection.backingScaleFactor

        if selection.screenFrame.width > 0 {
            pixelsPerPointX = CGFloat(image.width) / selection.screenFrame.width
        }
        if selection.screenFrame.height > 0 {
            pixelsPerPointY = CGFloat(image.height) / selection.screenFrame.height
        }

        let localRect = selection.rectInScreen

        // AppKit uses a bottom-left origin. CGImage cropping uses a top-left
        // origin, so the Y coordinate must be flipped in the display bitmap.
        let cropRect = CGRect(
            x: localRect.minX * pixelsPerPointX,
            y: (selection.screenFrame.height - localRect.maxY) * pixelsPerPointY,
            width: localRect.width * pixelsPerPointX,
            height: localRect.height * pixelsPerPointY
        ).integral

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height
        )
        let clippedRect = cropRect.intersection(imageBounds)

        guard !clippedRect.isNull,
              clippedRect.width >= 1,
              clippedRect.height >= 1,
              let croppedImage = image.cropping(to: clippedRect) else {
            throw SnapSenseError.imageCroppingFailed
        }

        return croppedImage
    }
}
