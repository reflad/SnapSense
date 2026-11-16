import AppKit
import Carbon.HIToolbox

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let permissionService = ScreenRecordingPermissionService()
    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let hotKeyManager = GlobalHotKeyManager()
    private let selectionOverlay = SelectionOverlayController()
    private let aiConfiguration = AIConfigurationStore.shared
    private let llmService = LLMService()

    private var permissionWindow: ScreenRecordingPermissionWindowController?
    private var settingsWindow: SettingsWindowController?
    private var actionBar: FloatingActionBarController?
    private var aiResponsePanel: AIResponsePanelController?
    private var latestCaptureContext: AICaptureContext?
    private var captureTask: Task<Void, Never>?
    private var isSelecting = false
    private var hasStarted = false

    private init() {
        selectionOverlay.onSelection = { [weak self] selection in
            self?.handleSelection(selection)
        }
        selectionOverlay.onCancel = { [weak self] in
            self?.isSelecting = false
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        registerGlobalHotKey()
    }

    func stop() {
        hotKeyManager.unregister()
        captureTask?.cancel()
        captureTask = nil

        if isSelecting {
            selectionOverlay.cancel()
            isSelecting = false
        }

        closeActionBar()
        closeAIResponsePanel()
        latestCaptureContext = nil
        permissionWindow?.close()
        permissionWindow = nil
        settingsWindow?.close()
        settingsWindow = nil
    }

    func beginCapture() {
        guard !isSelecting else { return }

        captureTask?.cancel()
        captureTask = nil
        closeActionBar()
        closeAIResponsePanel()
        latestCaptureContext = nil

        guard permissionService.hasAccess else {
            presentPermissionWindow()
            return
        }

        isSelecting = true
        selectionOverlay.begin()
    }

    func showPermissionSettings() {
        presentPermissionWindow()
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                configuration: aiConfiguration
            )
        }
        settingsWindow?.present()
    }

    private func handleSelection(_ selection: CaptureSelection) {
        isSelecting = false
        latestCaptureContext = nil

        let actionBar = FloatingActionBarController()
        actionBar.onDismiss = { [weak self] in
            self?.actionBar = nil
            self?.latestCaptureContext = nil
        }
        actionBar.onAIRequest = { [weak self] request in
            self?.startAI(with: request)
        }
        self.actionBar = actionBar
        actionBar.showLoading(for: selection)

        captureTask = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let image = try await captureService.capture(selection: selection)
                try Task.checkCancellation()

                let result = try await ocrService.recognizeText(in: image)
                try Task.checkCancellation()

                self.latestCaptureContext = AICaptureContext(
                    image: image,
                    ocrResult: result,
                    selection: selection
                )
                actionBar.show(result: result, for: selection)
            } catch is CancellationError {
                return
            } catch {
                if !self.permissionService.hasAccess {
                    actionBar.close()
                    self.presentPermissionWindow()
                } else {
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    actionBar.show(error: message, for: selection)
                }
            }
        }
    }

    private func registerGlobalHotKey() {
        do {
            try hotKeyManager.register(
                keyCode: UInt32(kVK_ANSI_2),
                modifiers: UInt32(cmdKey | shiftKey)
            ) { [weak self] in
                self?.beginCapture()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Не удалось зарегистрировать ⌘⇧2"
            alert.informativeText = """
            \(error.localizedDescription)

            Захват области всё равно доступен из меню SnapSense в строке меню.
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func startAI(with request: AIPromptRequest) {
        guard let context = latestCaptureContext else { return }

        closeActionBar()
        closeAIResponsePanel()

        let panel = AIResponsePanelController(
            context: context,
            request: request,
            configuration: aiConfiguration,
            llmService: llmService
        )
        panel.onDismiss = { [weak self] in
            self?.aiResponsePanel = nil
            self?.latestCaptureContext = nil
        }
        panel.onOpenSettings = { [weak self] in
            self?.showSettings()
        }

        aiResponsePanel = panel
        panel.present()
    }

    private func closeAIResponsePanel() {
        guard let aiResponsePanel else { return }
        aiResponsePanel.onDismiss = nil
        aiResponsePanel.close()
        self.aiResponsePanel = nil
    }

    private func presentPermissionWindow() {
        if permissionWindow == nil {
            permissionWindow = ScreenRecordingPermissionWindowController(
                permissionService: permissionService
            )
        }
        permissionWindow?.present()
    }

    private func closeActionBar() {
        guard let actionBar else { return }
        actionBar.onDismiss = nil
        actionBar.close()
        self.actionBar = nil
    }
}
