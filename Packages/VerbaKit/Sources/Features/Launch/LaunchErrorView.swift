import DesignSystem
import SwiftUI

/// Shown instead of the app when the saved data can't be opened, so a launch failure is never a crash.
/// Its text follows Verba's text size like every content area.
public struct LaunchErrorView: View {
    private let message: String
    private let showDatabase: () -> Void
    private let quit: () -> Void

    /// Creates the screen. The actions come from the app target, so this module needs only SwiftUI.
    public init(message: String, showDatabase: @escaping () -> Void, quit: @escaping () -> Void) {
        self.message = message
        self.showDatabase = showDatabase
        self.quit = quit
    }

    /// The problem, what it means, and the two ways forward.
    public var body: some View {
        ContentUnavailableView {
            Label("Verba Can't Open Your Data", systemImage: "exclamationmark.triangle")
                .themeFont(.readingHeading)
        } description: {
            Text(message)
                .themeFont(.readingBody)
        } actions: {
            Button("Show Database in Finder", action: showDatabase)
                .accessibilityHint("Opens Finder with your saved data selected.")
            Button("Quit", action: quit)
                .accessibilityHint("Closes Verba.")
        }
        .verbaContentFont()
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    LaunchErrorView(message: "Verba couldn't open your saved data.", showDatabase: {}, quit: {})
}
