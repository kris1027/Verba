import SwiftUI

/// The top of a lesson page: a monospaced `LESSON · <topic>` label and the serif title.
public struct LessonHeader: View {
    private let topic: String
    private let title: String

    /// Creates a header from the lesson's topic and title, shown as written.
    public init(topic: String, title: String) {
        self.topic = topic
        self.title = title
    }

    /// The label line and the title.
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TerminalLabel("Lesson · \(topic)")
            Text(verbatim: title)
                .themeFont(.readingTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LessonHeader(topic: "ser and estar", title: "Ser i estar: dwa czasowniki „być”")
        .padding()
        .background(Theme.background)
}
