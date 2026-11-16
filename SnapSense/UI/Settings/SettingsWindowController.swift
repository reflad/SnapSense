import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(configuration: AIConfigurationStore) {
        let rootView = SettingsView(configuration: configuration)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Настройки SnapSense"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 760, height: 720))
        window.minSize = NSSize(width: 660, height: 520)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
