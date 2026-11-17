import AppKit
import Features
import SwiftUI

@main
struct VerbaApp: App {
    /// Built once at launch: prepares the data folder and opens the database
    /// before any screen reads from it.
    private let launchResult = AppEnvironment.launch()

    private var environment: AppEnvironment? {
        if case .ready(let environment) = launchResult { return environment }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            switch launchResult {
            case .ready:
                RootView()
            case .failed(let message, let databaseURL):
                LaunchErrorView(
                    message: message,
                    showDatabase: { NSWorkspace.shared.activateFileViewerSelecting([databaseURL]) },
                    quit: { NSApplication.shared.terminate(nil) }
                )
            }
        }

        Settings {
            SettingsView()
                .environment(\.claudeConnection, environment?.claude)
        }
    }
}
