import AppKit
import SwiftUI

@MainActor
final class ScreenRecordingPermissionWindowController: NSWindowController {
    private let model: ScreenRecordingPermissionViewModel

    init(permissionService: ScreenRecordingPermissionService) {
        let model = ScreenRecordingPermissionViewModel(
            permissionService: permissionService
        )
        self.model = model

        let hostingController = NSHostingController(
            rootView: ScreenRecordingPermissionView(model: model)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SnapSense — доступ к экрану"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 548, height: 410))
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
