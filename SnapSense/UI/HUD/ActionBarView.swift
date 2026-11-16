import SwiftUI

enum ActionBarState {
    case loading
    case ready(OCRResult)
    case failure(String)
}

@MainActor
final class ActionBarModel: ObservableObject {
    @Published var state: ActionBarState = .loading
    @Published var isAIPopoverPresented = false
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?
    var onAIRequest: ((AIPromptRequest) -> Void)?
}

struct ActionBarView: View {
    @ObservedObject var model: ActionBarModel
    @ObservedObject var configuration: AIConfigurationStore

    @State private var showsAIPopover = false

    private let barWidth: CGFloat = 468
    private let barHeight: CGFloat = 60

    var body: some View {
        HStack(spacing: 11) {
            leadingIcon
            textContent
            Spacer(minLength: 4)
            trailingActions
            closeButton
        }
        .padding(.horizontal, 12)
        .frame(width: barWidth, height: barHeight)
        .background {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 8)
        .preferredColorScheme(.dark)
        .onChange(of: showsAIPopover) { _, isPresented in
            model.isAIPopoverPresented = isPresented
        }
        .onDisappear {
            model.isAIPopoverPresented = false
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 34, height: 34)
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var trailingActions: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.85))
                .frame(width: 34, height: 28)

        case .ready(let result):
            if !result.isEmpty {
                Button {
                    model.onCopy?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                        Text("Текст")
                    }
                }
                .buttonStyle(HUDActionButtonStyle())
                .help("Скопировать распознанный текст")
                .accessibilityLabel("Скопировать текст")
            }

            aiButton

        case .failure:
            EmptyView()
        }
    }

    private var aiButton: some View {
        Button {
            showsAIPopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                Text("ИИ")
            }
        }
        .buttonStyle(HUDActionButtonStyle(accented: true))
        .help("Спросить ИИ о выделенной области")
        .accessibilityLabel("ИИ-ассистент")
        .popover(isPresented: $showsAIPopover, arrowEdge: .bottom) {
            AIPromptPopover(configuration: configuration) { request in
                showsAIPopover = false
                model.isAIPopoverPresented = false
                model.onAIRequest?(request)
            }
        }
    }

    private var closeButton: some View {
        Button {
            model.onClose?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Закрыть (Esc)")
        .accessibilityLabel("Закрыть")
    }

    private var iconName: String {
        switch model.state {
        case .loading:
            return "viewfinder"
        case .ready(let result):
            return result.isEmpty ? "text.magnifyingglass" : "text.viewfinder"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch model.state {
        case .loading:
            return .white.opacity(0.92)
        case .ready(let result):
            return result.isEmpty ? .orange : .green
        case .failure:
            return .orange
        }
    }

    private var title: String {
        switch model.state {
        case .loading:
            return "Распознаю текст…"
        case .ready(let result):
            return result.isEmpty ? "Текст не найден" : "Текст распознан"
        case .failure:
            return "Не удалось обработать область"
        }
    }

    private var subtitle: String {
        switch model.state {
        case .loading:
            return "Локальный OCR через Apple Vision"
        case .ready(let result):
            if result.isEmpty {
                return "Попробуйте выделить область с текстом"
            }
            let blocks = result.blocks.count
            let characters = result.characterCount
            return "\(blocks) фрагм. · \(characters) симв. · OCR на устройстве"
        case .failure(let message):
            return message
        }
    }
}

private struct HUDActionButtonStyle: ButtonStyle {
    var accented = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(
                        accented
                        ? Color.purple.opacity(configuration.isPressed ? 0.72 : 0.52)
                        : Color.white.opacity(configuration.isPressed ? 0.22 : 0.13)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        accented
                        ? Color.purple.opacity(0.55)
                        : Color.white.opacity(0.16),
                        lineWidth: 1
                    )
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
