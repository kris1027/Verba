import SwiftUI

extension View {
    /// The styling every Verba window root applies: dark color scheme, sage tinted controls, and
    /// the saved text size in the environment. It changes no font itself, so the native sidebar
    /// keeps its system size; content areas opt in with `.verbaContentFont()`.
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
    }
}
