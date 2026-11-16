import AppKit
import CoreGraphics

/// The interactive surface for one display: dims the screen, keeps the selected
/// rectangle bright, and draws a Retina-aware size badge while dragging.
@MainActor
final class SelectionOverlayView: NSView {
    let screen: NSScreen

    var onSelectionCompleted: ((CaptureSelection) -> Void)?
    var onCancel: (() -> Void)?

    private var dragOrigin: CGPoint?
    private var selectionRect: CGRect?
    private var didRequestCancel = false

    init(screen: NSScreen) {
        self.screen = screen
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard !didRequestCancel else { return }

        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)

        let point = clamped(convert(event.locationInWindow, from: nil))
        dragOrigin = point
        selectionRect = CGRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }

        let point = clamped(convert(event.locationInWindow, from: nil))
        selectionRect = CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(point.x - origin.x),
            height: abs(point.y - origin.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let origin = dragOrigin, !didRequestCancel else { return }

        let point = clamped(convert(event.locationInWindow, from: nil))
        let localRect = CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(point.x - origin.x),
            height: abs(point.y - origin.y)
        ).integral

        dragOrigin = nil

        // A simple click (or a nearly zero drag) should not produce a capture.
        guard localRect.width >= 2, localRect.height >= 2 else {
            requestCancel()
            return
        }

        guard let displayNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            requestCancel()
            return
        }

        selectionRect = localRect
        needsDisplay = true

        let globalRect = localRect.offsetBy(
            dx: screen.frame.minX,
            dy: screen.frame.minY
        )

        let selection = CaptureSelection(
            rect: globalRect,
            screenFrame: screen.frame,
            displayID: CGDirectDisplayID(displayNumber.uint32Value),
            backingScaleFactor: screen.backingScaleFactor
        )

        onSelectionCompleted?(selection)
    }

    override func rightMouseDown(with event: NSEvent) {
        requestCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            requestCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        requestCancel()
    }

    private func requestCancel() {
        guard !didRequestCancel else { return }
        didRequestCancel = true
        onCancel?()
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let dimPath = CGMutablePath()
        dimPath.addRect(bounds)
        if let selectionRect, selectionRect.width > 0, selectionRect.height > 0 {
            dimPath.addRect(selectionRect)
        }

        context.saveGState()
        context.addPath(dimPath)
        context.setFillColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        context.drawPath(using: .eoFill)
        context.restoreGState()

        guard let selectionRect,
              selectionRect.width > 1,
              selectionRect.height > 1 else {
            return
        }

        // Draw a dark backing stroke first so the border stays visible over
        // bright content, then the accent stroke on top.
        let borderRect = selectionRect.insetBy(dx: 0.75, dy: 0.75)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 2, yRadius: 2)
        borderPath.lineWidth = 3
        NSColor.black.withAlphaComponent(0.45).setStroke()
        borderPath.stroke()

        borderPath.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        borderPath.stroke()

        drawSizeBadge(for: selectionRect)
    }

    private func drawSizeBadge(for rect: CGRect) {
        let pixelSize = CGSize(
            width: (rect.width * screen.backingScaleFactor).rounded(),
            height: (rect.height * screen.backingScaleFactor).rounded()
        )
        let text = "\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let string = text as NSString
        let textSize = string.size(withAttributes: attributes)
        let badgeSize = CGSize(
            width: ceil(textSize.width) + 16,
            height: ceil(textSize.height) + 8
        )

        var badgeOrigin = CGPoint(
            x: rect.minX + 8,
            y: rect.maxY - badgeSize.height - 8
        )

        if rect.width < badgeSize.width + 16 || rect.height < badgeSize.height + 16 {
            badgeOrigin = CGPoint(
                x: rect.minX,
                y: rect.maxY + 8
            )
            if badgeOrigin.y + badgeSize.height > bounds.maxY {
                badgeOrigin.y = rect.minY - badgeSize.height - 8
            }
        }

        badgeOrigin.x = min(
            max(badgeOrigin.x, bounds.minX + 4),
            bounds.maxX - badgeSize.width - 4
        )
        badgeOrigin.y = min(
            max(badgeOrigin.y, bounds.minY + 4),
            bounds.maxY - badgeSize.height - 4
        )

        let badgeRect = CGRect(origin: badgeOrigin, size: badgeSize)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 6, yRadius: 6).fill()

        string.draw(
            at: CGPoint(
                x: badgeRect.minX + 8,
                y: badgeRect.minY + (badgeRect.height - textSize.height) / 2
            ),
            withAttributes: attributes
        )
    }
}
