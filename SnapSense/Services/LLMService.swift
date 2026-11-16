import CoreGraphics
import Foundation

enum LLMServiceError: LocalizedError {
    case missingAPIKey
    case invalidConfiguration(String)
    case noTextAvailable
    case noImageAvailable
    case imageEncodingFailed(String)
    case unauthorized(String)
    case rateLimited(String)
    case httpError(statusCode: Int, message: String)
    case providerError(String)
    case noInternet
    case timedOut
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API-ключ не задан."
        case .invalidConfiguration(let message):
            return message
        case .noTextAvailable:
            return "В выделенной области не найден текст для этого режима."
        case .noImageAvailable:
            return "Скриншот недоступен для этого запроса."
        case .imageEncodingFailed(let message):
            return "Не удалось подготовить скриншот: \(message)"
        case .unauthorized(let message):
            return "API-ключ отклонён. \(message)"
        case .rateLimited(let message):
            return "Превышен лимит запросов. \(message)"
        case .httpError(let statusCode, let message):
            return "API вернуло ошибку \(statusCode). \(message)"
        case .providerError(let message):
            return "Ошибка провайдера: \(message)"
        case .noInternet:
            return "Нет подключения к интернету."
        case .timedOut:
            return "Сервер не ответил вовремя."
        case .network(let message):
            return "Сетевая ошибка: \(message)"
        }
    }
}

struct LLMInput {
    let request: AIPromptRequest
    let image: CGImage?
    let ocrText: String
}

/// A minimal URLSession-based client for two streaming API shapes.
///
/// No third-party SDK or transport layer is used. Responses are parsed directly
/// from Server-Sent Events (`data: {...}` lines).
final class LLMService {
    private let session: URLSession
    private let anthropicEndpoint: URL

    init(
        session: URLSession? = nil,
        anthropicEndpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 600
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
        self.anthropicEndpoint = anthropicEndpoint
    }

    func streamResponse(
        settings: AISettings,
        input: LLMInput,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws {
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey
        }

        let model = settings.activeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw LLMServiceError.invalidConfiguration("Укажите Model Name в настройках.")
        }

        let mode = input.request.attachmentMode
        let ocrText = input.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode == .textOnly, ocrText.isEmpty {
            throw LLMServiceError.noTextAvailable
        }

        if mode.sendsImage, input.image == nil {
            throw LLMServiceError.noImageAvailable
        }

        let encodedImage: String?
        if mode.sendsImage, let image = input.image {
            do {
                encodedImage = try ImageEncoder.jpegBase64(from: image)
            } catch {
                throw LLMServiceError.imageEncodingFailed(error.localizedDescription)
            }
        } else {
            encodedImage = nil
        }

        var userText = input.request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode.sendsText, !ocrText.isEmpty {
            userText += """


            --- OCR-текст выделенной области ---
            \(ocrText)
            --- конец OCR-текста ---
            """
        }
        if userText.isEmpty {
            userText = "Проанализируй приложенный контент."
        }

        let request: URLRequest
        switch settings.provider {
        case .openAICompatible:
            request = try makeOpenAIRequest(
                apiKey: apiKey,
                baseURL: settings.openAIBaseURL,
                model: model,
                systemPrompt: input.request.systemPrompt,
                userText: userText,
                imageBase64: encodedImage
            )
        case .anthropic:
            request = try makeAnthropicRequest(
                apiKey: apiKey,
                model: model,
                systemPrompt: input.request.systemPrompt,
                userText: userText,
                imageBase64: encodedImage
            )
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMServiceError.invalidConfiguration(
                    "Сервер вернул неизвестный HTTP-ответ."
                )
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                var body = ""
                for try await line in bytes.lines {
                    body += line
                    body += "\n"
                    if body.count > 8_000 { break }
                }
                throw httpError(statusCode: httpResponse.statusCode, body: body)
            }

            for try await line in bytes.lines {
                try Task.checkCancellation()
                if try await handleSSELine(
                    line,
                    provider: settings.provider,
                    onToken: onToken
                ) {
                    break
                }
            }
        } catch let error as LLMServiceError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled, Task.isCancelled {
                throw CancellationError()
            }
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed:
                throw LLMServiceError.noInternet
            case .timedOut:
                throw LLMServiceError.timedOut
            case .cancelled:
                throw CancellationError()
            default:
                throw LLMServiceError.network(error.localizedDescription)
            }
        } catch {
            throw LLMServiceError.network(error.localizedDescription)
        }
    }

    // MARK: - Requests

    private func makeOpenAIRequest(
        apiKey: String,
        baseURL: String,
        model: String,
        systemPrompt: String,
        userText: String,
        imageBase64: String?
    ) throws -> URLRequest {
        let endpoint = try openAIEndpoint(from: baseURL)

        let messageContent: Any
        if let imageBase64 {
            messageContent = [
                ["type": "text", "text": userText],
                [
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]
                ]
            ] as [[String: Any]]
        } else {
            messageContent = userText
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": messageContent]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try serialized(body)
        return request
    }

    private func makeAnthropicRequest(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userText: String,
        imageBase64: String?
    ) throws -> URLRequest {
        var content: [[String: Any]] = []
        if let imageBase64 {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageBase64
                ]
            ])
        }
        content.append(["type": "text", "text": userText])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2_048,
            "stream": true,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        var request = URLRequest(url: anthropicEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try serialized(body)
        return request
    }

    private func openAIEndpoint(from rawBaseURL: String) throws -> URL {
        let trimmed = rawBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil else {
            throw LLMServiceError.invalidConfiguration(
                "Укажите корректный Base URL, например https://api.openai.com/v1."
            )
        }

        if !components.path.hasSuffix("/chat/completions") {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + components.path
            if components.path == "/" {
                components.path = "/chat/completions"
            } else {
                components.path += "/chat/completions"
            }
        }

        guard let url = components.url else {
            throw LLMServiceError.invalidConfiguration("Не удалось собрать URL запроса.")
        }
        return url
    }

    private func serialized(_ body: [String: Any]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw LLMServiceError.invalidConfiguration(
                "Не удалось сформировать JSON запроса."
            )
        }
    }

    // MARK: - SSE

    /// Returns `true` when the stream sent its terminal event.
    private func handleSSELine(
        _ line: String,
        provider: AIProvider,
        onToken: @MainActor (String) -> Void
    ) async throws -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return false }

        let payload = String(trimmed.dropFirst(5))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return false }
        if payload == "[DONE]" { return true }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Keep-alive, comments and provider-specific non-JSON lines.
            return false
        }

        if let message = providerErrorMessage(in: json) {
            throw LLMServiceError.providerError(message)
        }

        switch provider {
        case .openAICompatible:
            return await handleOpenAIChunk(json, onToken: onToken)
        case .anthropic:
            return await handleAnthropicChunk(json, onToken: onToken)
        }
    }

    private func handleOpenAIChunk(
        _ json: [String: Any],
        onToken: @MainActor (String) -> Void
    ) async -> Bool {
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any] else {
            return false
        }

        if let content = delta["content"] as? String {
            await onToken(content)
        } else if let parts = delta["content"] as? [[String: Any]] {
            for part in parts {
                if let text = part["text"] as? String {
                    await onToken(text)
                }
            }
        }

        return false
    }

    private func handleAnthropicChunk(
        _ json: [String: Any],
        onToken: @MainActor (String) -> Void
    ) async -> Bool {
        guard let type = json["type"] as? String else { return false }

        switch type {
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                await onToken(text)
            }
            return false
        case "message_stop":
            return true
        case "error":
            return false
        default:
            return false
        }
    }

    private func providerErrorMessage(in json: [String: Any]) -> String? {
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let type = error["type"] as? String, !type.isEmpty {
                return type
            }
        }
        return nil
    }

    private func httpError(statusCode: Int, body: String) -> LLMServiceError {
        let message = serverMessage(from: body)

        switch statusCode {
        case 401, 403:
            return .unauthorized(message)
        case 429:
            return .rateLimited(message)
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }

    private func serverMessage(from body: String) -> String {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }

        let collapsed = body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !collapsed.isEmpty else { return "Сервер не вернул описание ошибки." }
        return String(collapsed.prefix(600))
    }
}
