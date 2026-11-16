import AppKit
import SwiftUI

@MainActor
final class ScreenRecordingPermissionViewModel: ObservableObject {
    @Published private(set) var isGranted: Bool

    private let permissionService: ScreenRecordingPermissionService

    init(permissionService: ScreenRecordingPermissionService) {
        self.permissionService = permissionService
        self.isGranted = permissionService.hasAccess
    }

    func refresh() {
        isGranted = permissionService.hasAccess
    }

    func requestAccess() {
        _ = permissionService.requestAccess()
        refresh()
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }
}

struct ScreenRecordingPermissionView: View {
    @ObservedObject var model: ScreenRecordingPermissionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            explanation
            statusCard
            Spacer(minLength: 4)
            actionButtons
            restartNote
        }
        .padding(28)
        .frame(width: 548, height: 410)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            model.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.9), .cyan.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: "viewfinder")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("SnapSense")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("Доступ к записи экрана")
                    .font(.system(size: 24, weight: .bold))
            }
        }
    }

    private var explanation: some View {
        Text(
            "Чтобы захватить выделенную область и распознать текст, "
            + "SnapSense нужен доступ к записи экрана. OCR выполняется локально. "
            + "Скриншот отправляется в ИИ только по вашей команде через кнопку «ИИ»."
        )
        .font(.system(size: 13.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(3)
    }

    private var statusCard: some View {
        HStack(spacing: 11) {
            Image(systemName: model.isGranted
                  ? "checkmark.circle.fill"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(model.isGranted ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.isGranted ? "Доступ предоставлен" : "Доступ пока не предоставлен")
                    .font(.system(size: 13, weight: .semibold))

                Text(model.isGranted
                     ? "Можно закрыть окно и нажать ⌘⇧2."
                     : "Включите SnapSense в разделе «Запись экрана».")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button("Открыть системные настройки") {
                model.openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !model.isGranted {
                Button("Запросить доступ") {
                    model.requestAccess()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button("Проверить снова") {
                model.refresh()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
    }

    private var restartNote: some View {
        Text(
            "После выдачи разрешения macOS может попросить перезапустить SnapSense. "
            + "Если доступ выдаётся впервые, системный запрос может появиться отдельно."
        )
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
