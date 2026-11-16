import SwiftUI

struct AISettingsView: View {
    @ObservedObject var configuration: AIConfigurationStore

    @State private var showsResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                providerCard
                connectionCard
                presetsSection
                storageNote
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "Сбросить пресеты?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Сбросить", role: .destructive) {
                configuration.resetPresets()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Ваши изменения будут заменены четырьмя стандартными промптами.")
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.85), .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "sparkles")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("ИИ-ассистент")
                    .font(.system(size: 22, weight: .bold))
                Text("Провайдер, модель и быстрые действия для выделенной области")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var providerCard: some View {
        settingsCard(title: "Провайдер", systemImage: "network") {
            Picker(
                "Провайдер",
                selection: $configuration.settings.provider
            ) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(providerDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectionCard: some View {
        settingsCard(title: "Подключение", systemImage: "key.horizontal") {
            connectionRow(title: "API Key") {
                SecureField("Вставьте API-ключ", text: $configuration.settings.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            connectionRow(title: "Model Name") {
                TextField("Название модели", text: modelBinding)
                    .textFieldStyle(.roundedBorder)
            }

            if configuration.settings.provider == .openAICompatible {
                connectionRow(title: "Base URL") {
                    TextField(
                        "https://api.openai.com/v1",
                        text: $configuration.settings.openAIBaseURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                Text(
                    "Для OpenRouter или Ollama используйте их совместимый Base URL. "
                    + "Если адрес заканчивается на /chat/completions, он будет использован как есть."
                )
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Anthropic Messages API · https://api.anthropic.com/v1/messages")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Быстрые промпты", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    configuration.addPreset()
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showsResetConfirmation = true
                } label: {
                    Label("Сбросить", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Сбросить пресеты по умолчанию")
            }

            if configuration.presets.isEmpty {
                Text("Пресетов нет. Добавьте быстрый промпт или задайте вопрос напрямую в HUD.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    }
            } else {
                ForEach($configuration.presets) { $preset in
                    presetCard(preset: $preset)
                }
            }
        }
    }

    private func presetCard(preset: Binding<AIPreset>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Название", text: preset.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5, weight: .medium))

                Picker("Вложения", selection: preset.attachmentMode) {
                    ForEach(AIAttachmentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 170)

                Button(role: .destructive) {
                    configuration.removePreset(id: preset.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Удалить пресет")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Системный промпт")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: preset.systemPrompt)
                    .font(.system(size: 11.5))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 58, maxHeight: 90)
                    .padding(5)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.8))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    }
            }

            HStack(spacing: 5) {
                Image(systemName: preset.wrappedValue.attachmentMode.symbolName)
                    .font(.system(size: 9, weight: .semibold))
                Text("В модель уйдёт: \(preset.wrappedValue.attachmentMode.title.lowercased())")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var storageNote: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "internaldrive")
                .font(.system(size: 10, weight: .medium))
            Text(
                "Настройки и API-ключ хранятся локально в UserDefaults, "
                + "чтобы не запрашивать Keychain при каждой пересборке."
            )
            .font(.system(size: 10))
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.tertiary)
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private func connectionRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            content()
        }
    }

    private var modelBinding: Binding<String> {
        Binding {
            switch configuration.settings.provider {
            case .openAICompatible:
                return configuration.settings.openAIModel
            case .anthropic:
                return configuration.settings.anthropicModel
            }
        } set: { newValue in
            switch configuration.settings.provider {
            case .openAICompatible:
                configuration.settings.openAIModel = newValue
            case .anthropic:
                configuration.settings.anthropicModel = newValue
            }
        }
    }

    private var providerDescription: String {
        switch configuration.settings.provider {
        case .openAICompatible:
            return "OpenAI Chat Completions API или совместимый сервер: OpenAI, OpenRouter, Ollama и другие. Поддерживается стриминг и изображения."
        case .anthropic:
            return "Anthropic Messages API с блоками изображения и текста. Поддерживается стриминг SSE."
        }
    }
}
