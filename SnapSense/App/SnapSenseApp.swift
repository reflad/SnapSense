import SwiftUI

@main
struct SnapSenseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(systemName: "viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}
