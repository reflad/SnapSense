import AppKit
import SwiftUI

@MainActor
final class FloatingActionBarController {
    var onDismiss: (() -> Void)?
    var onAIRequest: ((AIPromptRequest) -> Void)?

    private let model = ActionBarModel()
    private let toastController = ToastWindowController()
    private var panel: FloatingActionPanel?
    private var currentSelection: CaptureSelection?
    private var recognizedText = ""
    private var eventMonitors: [Any] = []
    private var isClosed = false

    private let panelSize = NSSize(width: 468, height: 60)

    init() {
        model.onCopy = { [weak self] in
            self?.copyRecognizedText()
        }
        model.onClose = { [weak self] in
            self?.close()
        }
        model.onAIRequest = { [weak self] request in
            self?.onAIRequest?(request)
        }
    }

    func showLoading(for selection: CaptureSelection) {
        guard !isClosed else { return }
        recognizedText = ""
        currentSelection = selection
        model.state = .loading
        presentPanel(for: selection)
    }

    func show(result: OCRResult, for selection: CaptureSelection) {
        guard !isClosed else { return }
        recognizedText = result.fullText
        currentSelection = selection
        model.state = .ready(result)
        presentPanel(for: selection)
    }

    func show(error message: String, for selection: CaptureSelection) {
        guard !isClosed else { return }
        recognizedText = ""
        currentSelection = selection
        model.state = .failure(message)
        presentPanel(for: selection)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true

        removeEventMonitors()
        toastController.dismiss()
        panel?.orderOut(nil)

        let callback = onDismiss
        onDismiss = nil
        callback?()
    }

    private func presentPanel(for selection: CaptureSelection) {
        let panel = panel ?? makePanel()
        self.panel = panel

        position(panel, for: selection)

        if !panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        installEventMonitors()
    }

    private func makePanel() -> FloatingActionPanel {
        let panel = FloatingActionPanel()
        let hostingView = NSHostingView(
            rootView: ActionBarView(
                model: model,
                configuration: .shared
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setContentSize(panelSize)
        return panel
    }

    private func position(
        _ panel: FloatingActionPanel,
        for selection: CaptureSelection
    ) {
        let margin: CGFloat = 10
        let screenFrame = selection.screenFrame
        let size = panel.frame.size

        var x = selection.rect.midX - size.width / 2
        x = min(
            max(x, screenFrame.minX + margin),
            screenFrame.maxX - size.width - margin
        )

        var y = selection.rect.minY - size.height - margin
        if y < screenFrame.minY + margin {
            y = selection.rect.maxY + margin
        }
        y = min(
            max(y, screenFrame.minY + margin),
            screenFrame.maxY - size.height - margin
        )

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func copyRecognizedText() {
        guard !recognizedText.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(recognizedText, forType: .string)

        guard let panel, let currentSelection else { return }
        toastController.show(
            message: "Скопировано в буфер",
            below: panel.frame,
            screenFrame: currentSelection.screenFrame
        )
    }

    private func installEventMonitors() {
        guard eventMonitors.isEmpty else { return }

        let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown, event.keyCode == 53 {
                self.close()
                return nil
            }

            if event.type == .leftMouseDown
                || event.type == .rightMouseDown
                || event.type == .otherMouseDown {
                // While the AI popover is open its own window receives clicks
                // outside the HUD frame; let SwiftUI dismiss the popover rather
                // than tearing down the whole HUD on the first click.
                if self.model.isAIPopoverPresented {
                    return event
                }

                if let panel = self.panel,
                   !panel.frame.contains(NSEvent.mouseLocation) {
                    self.close()
                }
            }

            return event
        }
        if let localMonitor {
            eventMonitors.append(localMonitor)
        }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
        if let globalMonitor {
            eventMonitors.append(globalMonitor)
        }
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    deinit {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }
}
