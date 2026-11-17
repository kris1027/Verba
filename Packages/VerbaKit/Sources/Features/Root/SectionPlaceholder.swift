import DesignSystem
import SwiftUI

/// The empty state of a sidebar section that a later slice fills. It uses Verba's type tokens,
/// so it follows the text size like every content area text.
struct SectionPlaceholder: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .themeFont(.readingTitle)
                .foregroundStyle(Theme.textTertiary)
                .accessibilityHidden(true)
            Text(title)
                .themeFont(.readingHeading)
                .foregroundStyle(Theme.text)
            TerminalLabel("Coming in a later slice")
        }
        .multilineTextAlignment(.center)
        .padding(Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SectionPlaceholder(title: "Lessons", systemImage: "book")
        .background(Theme.background)
}
