import AppKit
import SwiftUI

@MainActor
final class AIResponsePanelController: NSObject, NSWindowDelegate {
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let context: AICaptureContext
    private let request: AIPromptRequest
    private let configuration: AIConfigurationStore
    private let llmService: LLMService
    private let model: AIResponseViewModel

    private var panel: NSPanel?
    private var streamTask: Task<Void, Never>?
    private var escapeMonitor: Any?
    private var isClosed = false

    private let initialSize = NSSize(width: 470, height: 520)

    init(
        context: AICaptureContext,
        request: AIPromptRequest,
        configuration: AIConfigurationStore,
        llmService: LLMService = LLMService()
    ) {
        self.context = context
        self.request = request
        self.configuration = configuration
        self.llmService = llmService
        self.model = AIResponseViewModel(
            requestTitle: request.title,
            providerLabel: configuration.settings.provider.shortTitle,
            modelName: configuration.settings.activeModel
        )
        super.init()
    }

    func present() {
        guard !isClosed else { return }

        let panel = panel ?? makePanel()
        self.panel = panel

        position(panel, near: context.selection)
        installEscapeMonitor()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        startGeneration()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true

        streamTask?.cancel()
        streamTask = nil

        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        panel?.orderOut(nil)
        panel?.delegate = nil

        onDismiss?()
        onDismiss = nil
        onOpenSettings = nil
    }

    func windowWillClose(_ notification: Notification) {
        close()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "SnapSense — ИИ-ассистент"
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .default
        panel.minSize = NSSize(width: 400, height: 300)
        panel.setContentSize(initialSize)
        panel.center()
        panel.delegate = self

        // The response view supplies its own close button; the titlebar remains
        // draggable and the native controls are hidden for a compact HUD look.
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = AIResponsePanelView(
            model: model,
            onStop: { [weak self] in
                self?.stopGeneration()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        panel.contentViewController = hostingController
        panel.setContentSize(initialSize)
        return panel
    }

    private func position(_ panel: NSPanel, near selection: CaptureSelection) {
        let screenFrame = selection.screenFrame
        let size = panel.frame.size
        let margin: CGFloat = 10

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

    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self,
                  event.keyCode == 53,
                  self.panel?.isKeyWindow == true else {
                return event
            }
            self.close()
            return nil
        }
    }

    private func startGeneration() {
        model.phase = .loading
        model.failure = nil

        if configuration.settings.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            model.fail(
                with: AIResponseFailure(
                    title: "Не задан API-ключ",
                    message: "Откройте настройки SnapSense и укажите API-ключ выбранного провайдера.",
                    offersSettings: true
                )
            )
            return
        }

        if request.attachmentMode == .textOnly,
           context.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.fail(
                with: AIResponseFailure(
                    title: "Нет текста для анализа",
                    message: "В выделенной области не найден текст. Попробуйте пресет со скриншотом или выделите другую область.",
                    offersSettings: false
                )
            )
            return
        }

        let input = LLMInput(
            request: request,
            image: context.image,
            ocrText: context.ocrText
        )

        streamTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await llmService.streamResponse(
                    settings: configuration.settings,
                    input: input
                ) { [weak self] token in
                    self?.model.append(token)
                }

                guard !Task.isCancelled else {
                    self.model.stop()
                    return
                }
                self.model.finish()
            } catch is CancellationError {
                self.model.stop()
            } catch {
                guard !Task.isCancelled else {
                    self.model.stop()
                    return
                }
                self.model.fail(with: self.failure(from: error))
            }
        }
    }

    private func stopGeneration() {
        guard streamTask != nil else { return }
        streamTask?.cancel()
        streamTask = nil
        model.stop()
    }

    private func openSettings() {
        let callback = onOpenSettings
        // Settings is a normal-level window. Close the floating panel first so
        // it cannot cover the settings controls.
        close()
        callback?()
    }

    private func failure(from error: Error) -> AIResponseFailure {
        guard let serviceError = error as? LLMServiceError else {
            return AIResponseFailure(
                title: "Не удалось получить ответ",
                message: error.localizedDescription,
                offersSettings: false
            )
        }

        switch serviceError {
        case .missingAPIKey:
            return AIResponseFailure(
                title: "Не задан API-ключ",
                message: "Укажите API-ключ в настройках SnapSense.",
                offersSettings: true
            )

        case .unauthorized(let message):
            return AIResponseFailure(
                title: "Ошибка авторизации",
                message: message,
                offersSettings: true
            )

        case .rateLimited(let message):
            return AIResponseFailure(
                title: "Слишком много запросов",
                message: "API временно ограничило запросы. Подождите немного и попробуйте снова. \(message)",
                offersSettings: false
            )

        case .invalidConfiguration(let message),
             .imageEncodingFailed(let message),
             .providerError(let message),
             .network(let message):
            return AIResponseFailure(
                title: "Ошибка запроса",
                message: message,
                offersSettings: true
            )

        case .noTextAvailable:
            return AIResponseFailure(
                title: "Нет текста для анализа",
                message: "В выделенной области не найден OCR-текст. Выберите пресет со скриншотом или выделите другую область.",
                offersSettings: false
            )

        case .noImageAvailable:
            return AIResponseFailure(
                title: "Нет скриншота",
                message: "Не удалось получить изображение выделенной области.",
                offersSettings: false
            )

        case .httpError(let statusCode, let message):
            return AIResponseFailure(
                title: "Ошибка API \(statusCode)",
                message: message,
                offersSettings: statusCode == 401 || statusCode == 403
                    || statusCode == 404
            )

        case .noInternet:
            return AIResponseFailure(
                title: "Нет интернета",
                message: "Проверьте подключение к сети и повторите запрос.",
                offersSettings: false
            )

        case .timedOut:
            return AIResponseFailure(
                title: "Сервер не ответил",
                message: "Превышено время ожидания. Проверьте Base URL и подключение.",
                offersSettings: true
            )
        }
    }

    deinit {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }
}
