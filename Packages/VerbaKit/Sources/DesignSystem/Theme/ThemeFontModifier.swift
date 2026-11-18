import SwiftUI

extension View {
    /// Applies a type token scaled by the current text size, with its line spacing, tracking,
    /// and case. This is the only way a `DesignSystem` component sets a font.
    public func themeFont(_ font: ThemeFont) -> some View {
        modifier(ThemeFontModifier(themeFont: font))
    }

    /// Sets the base font of a content area to the scaled `ui` token, so plain `Text` and native
    /// control labels inside it follow the text size, and steps native controls up a size at
    /// large text. The sidebar, toolbar, and menus never get it, so they keep system sizes.
    public func verbaContentFont() -> some View {
        modifier(ContentFontModifier())
    }
}

private struct ThemeFontModifier: ViewModifier {
    let themeFont: ThemeFont
    @Environment(\.textSize) private var textSize

    func body(content: Content) -> some View {
        content
            .font(themeFont.font(for: textSize))
            .lineSpacing(themeFont.lineSpacing(for: textSize))
            .tracking(themeFont.tracking)
            .textCase(themeFont.isUppercase ? .uppercase : nil)
    }
}

private struct ContentFontModifier: ViewModifier {
    @Environment(\.textSize) private var textSize

    func body(content: Content) -> some View {
        content
            .font(ThemeFont.ui.font(for: textSize))
            .controlSize(textSize.usesLargeControls ? .large : .regular)
    }
}
