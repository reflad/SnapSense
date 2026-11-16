import SwiftUI

struct AIPromptPopover: View {
    @ObservedObject var configuration: AIConfigurationStore
    let onRun: (AIPromptRequest) -> Void

    @State private var question = ""
    @FocusState private var isQuestionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if configuration.presets.isEmpty {
                emptyPresets
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(configuration.presets) { preset in
                            AIPresetRow(preset: preset) {
                                onRun(AIPromptRequest(preset: preset))
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 252)
            }

            Divider()

            customQuestionField

            HStack(spacing: 5) {
                Text("Enter — отправить")
                Spacer()
                Text("Скриншот + OCR")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 352)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isQuestionFocused = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.85), .blue.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ИИ-ассистент")
                    .font(.system(size: 13, weight: .semibold))
                Text("Действие для выделенной области")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var emptyPresets: some View {
        Text("Быстрых промптов пока нет. Добавьте их в настройках SnapSense.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
    }

    private var customQuestionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Свой вопрос по области…", text: $question)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isQuestionFocused)
                .onSubmit(sendCustomQuestion)

            Button(action: sendCustomQuestion) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(
                        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary.opacity(0.45)
                        : Color.accentColor
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Отправить вопрос (Enter)")
        }
        .padding(.horizontal, 9)
        .frame(height: 34)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isQuestionFocused
                    ? Color.accentColor.opacity(0.55)
                    : Color.primary.opacity(0.09),
                    lineWidth: 1
                )
        }
    }

    private func sendCustomQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRun(.custom(question: trimmed))
    }
}

private struct AIPresetRow: View {
    let preset: AIPreset
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 27, height: 27)
                    Image(systemName: preset.attachmentMode.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name.isEmpty ? "Без названия" : preset.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(preset.attachmentMode.shortTitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0.035))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
