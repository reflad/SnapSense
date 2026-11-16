import AppKit
import SwiftUI

struct MenuBarContent: View {
    var body: some View {
        Button {
            AppCoordinator.shared.beginCapture()
        } label: {
            Label("Захватить область", systemImage: "viewfinder")
        }
        .keyboardShortcut("2", modifiers: [.command, .shift])

        Divider()

        Button {
            AppCoordinator.shared.showPermissionSettings()
        } label: {
            Label("Доступ к экрану…", systemImage: "lock.shield")
        }

        Divider()

        Button {
            AppCoordinator.shared.showSettings()
        } label: {
            Label("Настройки…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Выйти из SnapSense", systemImage: "power")
        }
        .keyboardShortcut("q")
    }
}
