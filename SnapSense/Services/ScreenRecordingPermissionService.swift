import AppKit
import CoreGraphics

struct ScreenRecordingPermissionService {
    var hasAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system TCC prompt the first time it is called for this app.
    /// Returns whether access is available immediately after the request.
    @discardableResult
    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
