import AppKit
import SwiftUI

enum AIResponsePhase: Equatable {
    case loading
    case streaming
    case finished
    case stopped
    case failed
}

struct AIResponseFailure: Equatable {
    let title: String
    let message: String
    let offersSettings: Bool
}

@MainActor
final class AIResponseViewModel: ObservableObject {
    let requestTitle: String
    let providerLabel: String
    let modelName: String

    @Published private(set) var text = ""
    @Published var phase: AIResponsePhase = .loading
    @Published var failure: AIResponseFailure?

    init(requestTitle: String, providerLabel: String, modelName: String) {
        self.requestTitle = requestTitle
        self.providerLabel = providerLabel
        self.modelName = modelName
    }

    var isGenerating: Bool {
        phase == .loading || phase == .streaming
    }

    func append(_ token: String) {
        guard !token.isEmpty, isGenerating else { return }
        if phase == .loading {
            phase = .streaming
        }
        text += token
    }

    func finish() {
        phase = .finished
        failure = nil
    }

    func stop() {
        guard isGenerating else { return }
        phase = .stopped
    }

    func fail(with failure: AIResponseFailure) {
        phase = .failed
        self.failure = failure
    }
}

struct AIResponsePanelView: View {
    @ObservedObject var model: AIResponseViewModel
    let onStop: () -> Void
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    @State private var showCopiedToast = false
    @State private var copyToastTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Divider()
                responseContent
                Divider()
                footer
            }
            .frame(minWidth: 420, minHeight: 320)
            .background(Color(nsColor: .windowBackgroundColor))

            if showCopiedToast {
                copiedToast
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onDisappear {
            copyToastTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.85), .blue.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(model.requestTitle.isEmpty ? "ИИ-ассистент" : model.requestTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(model.providerLabel) · \(model.modelName)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if model.isGenerating {
                Button(action: onStop) {
                    Label("Остановить", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                copyResponse()
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.text.isEmpty)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Закрыть (Esc)")
            .accessibilityLabel("Закрыть окно ответа")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var responseContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.text.isEmpty {
                        emptyState
                    } else {
                        MarkdownMessageView(
                            markdown: model.text,
                            isStreaming: model.phase == .streaming
                        )

                        if let failure = model.failure {
                            failureCard(failure)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("ai-response-bottom")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.text) { _, _ in
                withAnimation(.linear(duration: 0.08)) {
                    proxy.scrollTo("ai-response-bottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.phase {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Запрашиваю ответ…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .failed:
            if let failure = model.failure {
                failureCard(failure)
            }

        case .finished:
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Модель вернула пустой ответ.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .stopped:
            Text("Генерация остановлена.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)

        case .streaming:
            EmptyView()
        }
    }

    private func failureCard(_ failure: AIResponseFailure) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(failure.title)
                    .font(.system(size: 12.5, weight: .semibold))
            }

            Text(failure.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if failure.offersSettings {
                Button("Открыть настройки", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.075))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Esc — закрыть")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            switch model.phase {
            case .streaming:
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Генерирую…")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            case .stopped:
                Label("Остановлено", systemImage: "stop.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

            case .finished:
                Label("Готово", systemImage: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

            case .failed:
                Label("Ошибка", systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

            case .loading:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Скопировано")
                .font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 4)
    }

    private func copyResponse() {
        guard !model.text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(model.text, forType: .string)

        copyToastTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            showCopiedToast = true
        }

        copyToastTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                showCopiedToast = false
            }
        }
    }
}
