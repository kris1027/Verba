import SwiftUI

/// The debug Design Gallery: every token and component in every state, using sample data,
/// so the design system can be checked before a real screen uses it.
public struct DesignGalleryView: View {
    /// The window identifier the app declares the gallery under and `DebugCommands` opens.
    public static let windowID = "design-gallery"

    /// Creates the gallery.
    public init() {}

    /// The gallery sections in one scrolling page.
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                BaseComponentSection()
                TypeSection()
                LayoutTokenSection()
                ColorTokenSection()
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .verbaContentFont()
        .frame(minWidth: 720, minHeight: 520)
        .navigationTitle("Design Gallery")
    }
}

#Preview {
    DesignGalleryView()
}
