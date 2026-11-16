import Combine
import Foundation

/// A single local source of truth for AI settings and quick prompts.
///
/// The API key is deliberately persisted in `UserDefaults` as requested by the
/// project specification. This avoids Keychain prompts after rebuilding the app
/// from Xcode, but it is not encrypted at rest.
@MainActor
final class AIConfigurationStore: ObservableObject {
    static let shared = AIConfigurationStore()

    @Published var settings: AISettings {
        didSet { persistSettings() }
    }

    @Published var presets: [AIPreset] {
        didSet { persistPresets() }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()

    private enum Keys {
        static let settings = "snapsense.ai.settings"
        static let presets = "snapsense.ai.presets"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.settings),
           let decoded = try? JSONDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaults
        }

        if let data = defaults.data(forKey: Keys.presets),
           let decoded = try? JSONDecoder().decode([AIPreset].self, from: data) {
            presets = decoded
        } else {
            presets = AIPreset.defaultPresets
        }

        // Materialize the defaults into UserDefaults on first launch.
        persistSettings()
        persistPresets()
    }

    func addPreset() {
        presets.append(AIPreset.makeNewPreset())
    }

    func removePreset(id: AIPreset.ID) {
        presets.removeAll { $0.id == id }
    }

    func resetPresets() {
        presets = AIPreset.defaultPresets
    }

    private func persistSettings() {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    private func persistPresets() {
        guard let data = try? encoder.encode(presets) else { return }
        defaults.set(data, forKey: Keys.presets)
    }
}
