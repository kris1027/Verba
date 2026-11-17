import SwiftUI

/// Bigger (⌘+), Smaller (⌘−), and Actual Size (⌘0) in the View menu. They step Verba's own text
/// size and save it, so it survives a relaunch.
public struct TextSizeCommands: Commands {
    @AppStorage(TextSize.storageKey) private var storedTextSize = TextSize.defaultSize.rawValue

    /// Creates the text size menu items.
    public init() {}

    /// The three items, placed after the toolbar items of the View menu.
    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Section {
                Button("Bigger") { step(to: current.bigger) }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(current.bigger == nil)
                Button("Smaller") { step(to: current.smaller) }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(current.smaller == nil)
                Button("Actual Size") { storedTextSize = TextSize.defaultSize.rawValue }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(current == .defaultSize)
            }
        }
    }

    private var current: TextSize {
        TextSize(storedValue: storedTextSize)
    }

    private func step(to size: TextSize?) {
        guard let size else { return }
        storedTextSize = size.rawValue
    }
}
