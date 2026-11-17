import SwiftUI

/// The Debug menu, shown in debug builds only (the app decides): it opens the Design Gallery.
public struct DebugCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    /// Creates the Debug menu.
    public init() {}

    /// A Debug menu with Design Gallery (⌥⌘D).
    public var body: some Commands {
        CommandMenu("Debug") {
            Button("Design Gallery") {
                openWindow(id: DesignGalleryView.windowID)
            }
            .keyboardShortcut("d", modifiers: [.option, .command])
        }
    }
}
