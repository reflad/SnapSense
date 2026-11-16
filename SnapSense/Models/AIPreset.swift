import Foundation

enum AIAttachmentMode: String, Codable, CaseIterable, Identifiable {
    case textOnly
    case screenshotOnly
    case screenshotAndText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textOnly:
            return "Только текст"
        case .screenshotOnly:
            return "Только скриншот"
        case .screenshotAndText:
            return "Скриншот + текст"
        }
    }

    var shortTitle: String {
        switch self {
        case .textOnly:
            return "OCR-текст"
        case .screenshotOnly:
            return "Скриншот"
        case .screenshotAndText:
            return "Скриншот + OCR"
        }
    }

    var symbolName: String {
        switch self {
        case .textOnly:
            return "text.alignleft"
        case .screenshotOnly:
            return "photo"
        case .screenshotAndText:
            return "doc.richtext"
        }
    }

    var sendsText: Bool {
        self != .screenshotOnly
    }

    var sendsImage: Bool {
        self != .textOnly
    }
}

struct AIPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var systemPrompt: String
    var attachmentMode: AIAttachmentMode

    init(
        id: UUID = UUID(),
        name: String,
        systemPrompt: String,
        attachmentMode: AIAttachmentMode
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.attachmentMode = attachmentMode
    }

    static let defaultPresets: [AIPreset] = [
        AIPreset(
            name: "Объяснить код / ошибку",
            systemPrompt: """
            Ты — senior software engineer. Объясни фрагмент кода или текст ошибки, \
            который виден на скриншоте и/или распознан OCR. Определи причину проблемы, \
            возможные последствия и предложи конкретное исправление. Если данных \
            недостаточно, честно скажи об этом. Отвечай на языке пользователя.
            """,
            attachmentMode: .screenshotAndText
        ),
        AIPreset(
            name: "Перевести сленг и суть",
            systemPrompt: """
            Ты — опытный переводчик и редактор. Переведи текст, объясни сленг, идиомы \
            и культурный контекст, а затем одной короткой фразой передай суть. \
            Сохраняй смысл, а не дословную структуру. Отвечай на языке пользователя.
            """,
            attachmentMode: .textOnly
        ),
        AIPreset(
            name: "Написать ответ",
            systemPrompt: """
            Ты — ассистент по деловой и личной переписке. Напиши 2–3 варианта ответа \
            на письмо или сообщение: короткий, вежливый и уверенный. Учитывай тон \
            исходного текста, не добавляй вымышленных фактов. Отвечай на языке пользователя.
            """,
            attachmentMode: .textOnly
        ),
        AIPreset(
            name: "Разобрать график / интерфейс",
            systemPrompt: """
            Ты — аналитик данных и интерфейсов. Разбери изображение: что происходит, \
            какие элементы, метрики и тренды видны, что выглядит необычно и какие \
            действия можно предложить. Не выдумывай данные, которых нет на картинке. \
            Отвечай на языке пользователя.
            """,
            attachmentMode: .screenshotOnly
        )
    ]

    static func makeNewPreset() -> AIPreset {
        AIPreset(
            name: "Новый промпт",
            systemPrompt: "Опиши, что ИИ должен сделать с выделенным содержимым.",
            attachmentMode: .screenshotAndText
        )
    }
}

/// A fully resolved request, independent from how it was selected in the HUD.
struct AIPromptRequest: Equatable {
    let title: String
    let systemPrompt: String
    let userPrompt: String
    let attachmentMode: AIAttachmentMode

    init(preset: AIPreset) {
        self.title = preset.name
        self.systemPrompt = preset.systemPrompt
        self.userPrompt = """
        Проанализируй приложенный контент и выполни задачу из системной инструкции.
        """
        self.attachmentMode = preset.attachmentMode
    }

    static func custom(question: String) -> AIPromptRequest {
        AIPromptRequest(
            title: "Свой вопрос",
            systemPrompt: """
            Ты — полезный ИИ-ассистент внутри утилиты захвата экрана. Помогай \
            анализировать выделенный фрагмент, объяснять смысл и предлагать решения. \
            Отвечай понятно, по делу и на языке пользователя.
            """,
            userPrompt: question,
            attachmentMode: .screenshotAndText
        )
    }

    private init(
        title: String,
        systemPrompt: String,
        userPrompt: String,
        attachmentMode: AIAttachmentMode
    ) {
        self.title = title
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.attachmentMode = attachmentMode
    }
}
