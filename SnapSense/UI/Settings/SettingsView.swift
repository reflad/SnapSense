import SwiftUI

struct SettingsView: View {
    @ObservedObject var configuration: AIConfigurationStore

    var body: some View {
        AISettingsView(configuration: configuration)
            .frame(minWidth: 680, minHeight: 560)
    }
}
