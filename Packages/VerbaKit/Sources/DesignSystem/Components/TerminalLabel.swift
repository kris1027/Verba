import SwiftUI

/// A small monospaced, uppercase label in tertiary text: kind labels, counters, status lines,
/// and key hints.
public struct TerminalLabel: View {
    private let text: String

    /// Creates a label. The text is shown in capitals; pass it as written.
    public init(_ text: String) {
        self.text = text
    }

    /// The label text.
    public var body: some View {
        Text(verbatim: text)
            .themeFont(.label)
            .foregroundStyle(Theme.textTertiary)
    }
}

#Preview {
    TerminalLabel("Exercise · 03/08")
        .padding()
        .background(Theme.background)
}
