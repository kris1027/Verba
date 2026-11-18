import SwiftUI

/// The lesson page container: a vertical scroll view with a centered reading column, 680 points
/// wide at default text size and widening with the text size, on the palette background.
public struct ReadingColumn<Content: View>: View {
    private let content: Content

    /// Creates a reading column around its content.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// The scrolling column.
    public var body: some View {
        ScrollView {
            content
                .readingColumnWidth()
                .padding(.vertical, Theme.Spacing.xxl)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .verbaContentFont()
    }
}

extension View {
    /// Limits content to the reading width for the current text size, centered, with the
    /// column's side padding. At large sizes the column simply fills the window.
    func readingColumnWidth() -> some View {
        modifier(ReadingColumnWidth())
    }
}

private struct ReadingColumnWidth: ViewModifier {
    @Environment(\.textSize) private var textSize

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Theme.readingWidth(for: textSize), alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: .infinity)
    }
}
