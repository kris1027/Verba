import DesignSystem
import SwiftUI

/// The empty state of a sidebar section that a later slice fills, or of the app when no section
/// is selected. It uses Verba's type tokens, so it follows the text size like every content area text.
struct SectionPlaceholder: View {
    /// The section to stand in for; `nil` shows Verba itself.
    let item: SidebarItem?

    private var title: String { item?.title ?? "Verba" }
    private var systemImage: String { item?.systemImage ?? "character.book.closed" }

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
    SectionPlaceholder(item: .lessons)
        .background(Theme.background)
}
