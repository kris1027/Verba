import SwiftUI

/// Verba's design tokens. Every view takes its colors, fonts, spacing, and shapes from here.
public enum Theme {
    /// The screen palette for a contrast setting: Increase Contrast picks the brighter one.
    nonisolated public static func screenPalette(for contrast: ColorSchemeContrast) -> Palette {
        contrast == .increased ? .increasedContrast : .standard
    }

    /// Window content area.
    public static let background = ThemeColor(.background)
    /// Cards and exercise panes.
    public static let surface = ThemeColor(.surface)
    /// Input fields and the selected row fill.
    public static let raised = ThemeColor(.raised)
    /// Primary text.
    public static let text = ThemeColor(.text)
    /// Metadata and hints.
    public static let textSecondary = ThemeColor(.textSecondary)
    /// Labels and counters.
    public static let textTertiary = ThemeColor(.textTertiary)
    /// Sage: focus border, primary button fill, selection marker.
    public static let accent = ThemeColor(.accent)
    /// Text drawn on the accent.
    public static let onAccent = ThemeColor(.onAccent)
    /// Decorative pane borders.
    public static let hairline = ThemeColor(.hairline)
    /// Borders of option rows, fields, and tokens.
    public static let controlBorder = ThemeColor(.controlBorder)
    /// The correct grade tone.
    public static let correct = ThemeColor(.correct)
    /// The partly correct grade tone.
    public static let partly = ThemeColor(.partly)
    /// The wrong grade tone.
    public static let wrong = ThemeColor(.wrong)
}
