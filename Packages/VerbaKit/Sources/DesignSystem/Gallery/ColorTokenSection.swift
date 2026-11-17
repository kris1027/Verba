import SwiftUI

/// Gallery section: every color token in every palette, with its hex value and its contrast
/// against the palette's background and surface.
struct ColorTokenSection: View {
    var body: some View {
        GallerySection(title: "Color tokens") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ForEach(Palette.all, id: \.name) { palette in
                    PaletteTable(palette: palette)
                }
            }
        }
    }
}

/// One palette as a table: swatch, token, role, hex, and the two contrast ratios.
private struct PaletteTable: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TerminalLabel(palette.name)
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.s) {
                GridRow {
                    Text("")
                    Text("Token")
                    Text("Hex")
                    Text("On background")
                    Text("On surface")
                    Text("Role")
                }
                .themeFont(.label)
                .foregroundStyle(Theme.textSecondary)
                ForEach(ColorToken.allCases, id: \.self) { token in
                    if let value = palette[token] {
                        TokenRow(token: token, value: value, palette: palette)
                    }
                }
            }
        }
    }
}

private struct TokenRow: View {
    let token: ColorToken
    let value: RGB
    let palette: Palette

    var body: some View {
        GridRow {
            Rectangle()
                .fill(value.color)
                .stroke(Theme.hairline, lineWidth: Theme.Shape.borderWidth)
                .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xl)
                .accessibilityHidden(true)
            Text(token.rawValue)
                .themeFont(.code)
            Text(value.hexString)
                .themeFont(.code)
            ratioText(against: .background)
            ratioText(against: .surface)
            Text(token.role)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func ratioText(against base: ColorToken) -> some View {
        Group {
            if let baseValue = palette[base] {
                Text(Contrast.ratio(value, baseValue), format: .number.precision(.fractionLength(1)))
            } else {
                Text(verbatim: "–")
            }
        }
        .themeFont(.code)
    }
}
