import AppKit

/// Presents one selection surface per display and coordinates their lifecycle.
///
/// A selection is intentionally confined to the display where it started; this
/// keeps pixel coordinates deterministic on mixed Retina/non-Retina setups.
/// Users can start a selection on any connected monitor.
@MainActor
final class SelectionOverlayController {
    var onSelection: ((CaptureSelection) -> Void)?
    var onCancel: (() -> Void)?

    private var windows: [SelectionOverlayWindow] = []
    private var escapeMonitor: Any?
    private var isPresenting = false

    func begin() {
        guard !isPresenting else { return }
        isPresenting = true

        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()

        // The key overlay view already handles Escape, but a local monitor
        // makes cancellation reliable even if keyboard focus lands elsewhere.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.cancel()
            return nil
        }

        for screen in NSScreen.screens {
            let window = SelectionOverlayWindow(screen: screen)
            let view = SelectionOverlayView(screen: screen)

            view.onSelectionCompleted = { [weak self] selection in
                self?.finish(with: selection)
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }

            window.contentView = view
            windows.append(window)
            window.orderFrontRegardless()
        }

        // Give keyboard focus to the display under the pointer so Escape works
        // even before the user starts dragging.
        let mouseLocation = NSEvent.mouseLocation
        if let window = windows.first(where: { $0.frame.contains(mouseLocation) })
            ?? windows.first {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }

    func cancel() {
        guard isPresenting else { return }
        tearDown()
        onCancel?()
    }

    private func finish(with selection: CaptureSelection) {
        guard isPresenting else { return }
        tearDown()
        onSelection?(selection)
    }

    private func tearDown() {
        isPresenting = false

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        NSCursor.pop()
    }
}
