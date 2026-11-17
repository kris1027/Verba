import SwiftUI

/// File › Print… (⌘P): prints the lesson the focused window offers, and is disabled when the
/// focused window offers none.
public struct PrintCommands: Commands {
    @FocusedValue(\.lessonPrintAction) private var printAction

    /// Creates the print command.
    public init() {}

    /// Print… in place of the system print item.
    public var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print…") { printAction?() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(printAction == nil)
        }
    }
}
