import SwiftUI

/// A color token as a SwiftUI shape style. It resolves against the view environment, so the
/// Increase Contrast palette takes over by itself when the system setting is on.
nonisolated public struct ThemeColor: ShapeStyle {
    /// The role this style draws.
    public let token: ColorToken

    /// Creates a style for one token.
    public init(_ token: ColorToken) {
        self.token = token
    }

    /// The token's color in the screen palette the environment calls for.
    public func resolve(in environment: EnvironmentValues) -> Color {
        Theme.screenPalette(for: environment.colorSchemeContrast).rgb(token).color
    }
}

nonisolated extension Palette {
    /// The token's value, falling back to the standard palette for a token this palette leaves out.
    func rgb(_ token: ColorToken) -> RGB {
        self[token] ?? Palette.standard[token] ?? RGB(hex: 0)
    }
}
