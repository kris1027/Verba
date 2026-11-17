import SwiftUI

/// Gallery section: every color token in every palette, with its hex value and its contrast
/// against the palette's background and surface.
struct ColorTokenSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Color tokens")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(Palette.all, id: \.name) { palette in
                PaletteTable(palette: palette)
            }
        }
    }
}

/// One palette as a table: swatch, token, role, hex, and the two contrast ratios.
private struct PaletteTable: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(palette.name.uppercased())
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Token")
                    Text("Hex")
                    Text("On background")
                    Text("On surface")
                    Text("Role")
                }
                .font(.system(.callout, design: .monospaced))
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
                .stroke(Theme.hairline, lineWidth: 1)
                .frame(width: 32, height: 20)
                .accessibilityHidden(true)
            Text(token.rawValue)
                .font(.system(.body, design: .monospaced))
            Text(value.hexString)
                .font(.system(.body, design: .monospaced))
            ratioText(against: .background)
            ratioText(against: .surface)
            Text(token.role)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func ratioText(against base: ColorToken) -> Text {
        guard let baseValue = palette[base] else { return Text("–") }
        let ratio = Contrast.ratio(value, baseValue)
        return Text(ratio, format: .number.precision(.fractionLength(1)))
            .font(.system(.body, design: .monospaced))
    }
}
