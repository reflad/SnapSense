import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAICompatible:
            return "OpenAI-compatible"
        case .anthropic:
            return "Anthropic Claude"
        }
    }

    var shortTitle: String {
        switch self {
        case .openAICompatible:
            return "OpenAI-compatible"
        case .anthropic:
            return "Anthropic"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-3-5-sonnet-latest"
        }
    }
}

struct AISettings: Codable, Equatable {
    var provider: AIProvider = .openAICompatible
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var openAIModel: String = "gpt-4o-mini"
    var anthropicModel: String = "claude-3-5-sonnet-latest"

    var activeModel: String {
        switch provider {
        case .openAICompatible:
            return openAIModel
        case .anthropic:
            return anthropicModel
        }
    }

    static let defaults = AISettings()
}
