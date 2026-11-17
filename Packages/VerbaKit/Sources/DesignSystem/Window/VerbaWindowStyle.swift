import SwiftUI

extension View {
    /// The styling every Verba window root applies: dark color scheme, sage tinted controls, the
    /// saved text size in the environment, and ⌘= as a second key for View › Bigger. It changes
    /// no font itself, so the native sidebar keeps its system size; content areas opt in with
    /// `.verbaContentFont()`.
    public func verbaWindowStyle() -> some View {
        modifier(VerbaWindowStyle())
    }
}

private struct VerbaWindowStyle: ViewModifier {
    @AppStorage(TextSize.storageKey) private var storedTextSize = TextSize.defaultSize.rawValue

    func body(content: Content) -> some View {
        content
            .environment(\.textSize, TextSize(storedValue: storedTextSize))
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .background { biggerWithoutShift }
    }

    /// ⌘= also runs View › Bigger. The menu item is ⌘+, which on most layouts needs Shift, and
    /// people expect the unshifted key to work as it does in Safari and Xcode.
    private var biggerWithoutShift: some View {
        Button("Bigger") {
            if let bigger = TextSize(storedValue: storedTextSize).bigger {
                storedTextSize = bigger.rawValue
            }
        }
        .keyboardShortcut("=", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
