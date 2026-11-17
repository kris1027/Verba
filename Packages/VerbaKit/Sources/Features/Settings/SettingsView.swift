import Core
import DesignSystem
import SwiftUI

/// The Settings window.
public struct SettingsView: View {
    @Environment(\.claudeConnection) private var claudeConnection

    /// Creates the Settings window content. The Claude connection arrives through `@Environment`.
    public init() {}

    /// The settings form.
    public var body: some View {
        Form {
            if let claudeConnection {
                ClaudeSettingsSection(connection: claudeConnection)
            } else {
                Text("Settings are unavailable because Verba couldn't open your data.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 320, idealHeight: 400)
    }
}

#Preview {
    SettingsView()
}
