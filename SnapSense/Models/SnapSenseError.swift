import Foundation

enum SnapSenseError: LocalizedError {
    case screenRecordingPermissionDenied
    case displayUnavailable
    case emptySelection
    case screenCaptureFailed(String)
    case imageCroppingFailed
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Нет доступа к записи экрана. Разрешите его в системных настройках."
        case .displayUnavailable:
            return "Не удалось найти выбранный монитор."
        case .emptySelection:
            return "Выделенная область слишком мала."
        case .screenCaptureFailed(let reason):
            return "Не удалось захватить экран: \(reason)"
        case .imageCroppingFailed:
            return "Не удалось вырезать выделенную область."
        case .ocrFailed(let reason):
            return "Vision не смог распознать текст: \(reason)"
        }
    }
}
