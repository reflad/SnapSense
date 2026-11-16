import CoreGraphics

/// A completed selection in AppKit global screen coordinates.
///
/// SnapSense captures one display at a time. Multi-monitor support means the
/// selection overlay is presented on every display and the user may start a
/// selection on any of them.
struct CaptureSelection: Equatable {
    /// Selection rectangle in AppKit's global coordinate space (origin at the
    /// bottom-left of the primary display, Y grows upwards).
    let rect: CGRect

    /// Full frame of the display on which the selection was made.
    let screenFrame: CGRect

    /// Core Graphics display identifier used to find the matching `SCDisplay`.
    let displayID: CGDirectDisplayID

    /// The display's backing scale factor (2.0 on Retina, 1.0 on most externals).
    let backingScaleFactor: CGFloat

    /// Selection in the display's local point coordinates (bottom-left origin).
    var rectInScreen: CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: rect.minY - screenFrame.minY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Selection size in physical pixels, used by the live size badge.
    var pixelSize: CGSize {
        CGSize(
            width: (rect.width * backingScaleFactor).rounded(),
            height: (rect.height * backingScaleFactor).rounded()
        )
    }
}
