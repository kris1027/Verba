/// One complete set of color values for the token roles.
///
/// Verba has three: the dark screen palette, its Increase Contrast variant, and the light print
/// palette. The hex values are deliberate (each was measured for contrast); change them only
/// together with `design.md`, and let the contrast test judge the result.
nonisolated public struct Palette: Sendable {
    /// A short name for the palette, shown in the Design Gallery.
    public let name: String
    private let values: [ColorToken: RGB]

    /// The value for a token, or `nil` when this palette does not use it (the accent in print).
    public subscript(token: ColorToken) -> RGB? {
        values[token]
    }

    /// The dark screen palette.
    public static let standard = Palette(
        name: "Standard",
        values: [
            .background: RGB(hex: 0x0E100F),
            .surface: RGB(hex: 0x151816),
            .raised: RGB(hex: 0x1E2320),
            .text: RGB(hex: 0xE6E8E3),
            .textSecondary: RGB(hex: 0xA6AEA8),
            .textTertiary: RGB(hex: 0x8A938C),
            .accent: RGB(hex: 0xA3B899),
            .onAccent: RGB(hex: 0x0E100F),
            .hairline: RGB(hex: 0x3A413C),
            .controlBorder: RGB(hex: 0x68716B),
            .correct: RGB(hex: 0x5EE0A0),
            .partly: RGB(hex: 0xE5B454),
            .wrong: RGB(hex: 0xF2837A),
        ])

    /// The dark screen palette with Increase Contrast on: brighter secondary text and borders.
    public static let increasedContrast = Palette(
        name: "Increase Contrast",
        values: standard.values.merging(
            [
                .textSecondary: RGB(hex: 0xC9CFCA),
                .textTertiary: RGB(hex: 0xB0B8B2),
                .hairline: RGB(hex: 0x6B756E),
                .controlBorder: RGB(hex: 0x8E9891),
            ],
            uniquingKeysWith: { _, override in override }))

    /// The light, ink friendly palette for printing and Save as PDF. It has no accent.
    public static let print = Palette(
        name: "Print",
        values: [
            .background: RGB(hex: 0xFFFFFF),
            .surface: RGB(hex: 0xFFFFFF),
            .raised: RGB(hex: 0xFFFFFF),
            .text: RGB(hex: 0x111111),
            .textSecondary: RGB(hex: 0x4A4A4A),
            .textTertiary: RGB(hex: 0x4A4A4A),
            .hairline: RGB(hex: 0xBBBBBB),
            .controlBorder: RGB(hex: 0x555555),
            .correct: RGB(hex: 0x555555),
            .partly: RGB(hex: 0x555555),
            .wrong: RGB(hex: 0x555555),
        ])

    /// Every palette, in the order the gallery and `design.md` list them.
    public static let all: [Palette] = [.standard, .increasedContrast, .print]
}
