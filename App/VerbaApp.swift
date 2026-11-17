import AppKit
import DesignSystem
import Features
import SwiftUI

@main
struct VerbaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    /// Built once at launch: prepares the data folder and opens the database
    /// before any screen reads from it.
    private let launchResult = AppEnvironment.launch()

    private var environment: AppEnvironment? {
        if case .ready(let environment) = launchResult { return environment }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            Group {
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
            .verbaWindowStyle()
        }
        .commands {
            if AppEnvironment.showsDebugMenu {
                DebugCommands()
            }
        }

        // Declared in every build so `#if DEBUG` stays in AppEnvironment; only the Debug menu opens it.
        Window("Design Gallery", id: DesignGalleryView.windowID) {
            DesignGalleryView()
                .verbaWindowStyle()
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView()
                .environment(\.claudeConnection, environment?.claude)
                .verbaWindowStyle()
        }
    }
}
