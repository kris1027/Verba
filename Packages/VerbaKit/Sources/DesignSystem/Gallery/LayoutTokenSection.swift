import SwiftUI

/// Gallery section: spacing, shape, focus, motion, and the text size scale table.
struct LayoutTokenSection: View {
    @Environment(\.textSize) private var textSize

    private static let spacing: [(name: String, value: Double)] = [
        ("xs", Theme.Spacing.xs), ("s", Theme.Spacing.s), ("m", Theme.Spacing.m),
        ("l", Theme.Spacing.l), ("xl", Theme.Spacing.xl), ("xxl", Theme.Spacing.xxl),
    ]

    var body: some View {
        GallerySection(title: "Spacing, shape, and motion") {
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.s) {
                ForEach(Self.spacing, id: \.name) { item in
                    GridRow {
                        Text(verbatim: item.name).themeFont(.code)
                        Text(item.value, format: .number).themeFont(.code)
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: item.value, height: Theme.Spacing.s)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            HStack(spacing: Theme.Spacing.xl) {
                shapeSample(label: "Pane · radius 2 · hairline", border: Theme.hairline, width: Theme.Shape.borderWidth)
                shapeSample(label: "Control · border 1", border: Theme.controlBorder, width: Theme.Shape.borderWidth)
                shapeSample(label: "Focused · sage 2", border: Theme.accent, width: Theme.Shape.focusBorderWidth)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TerminalLabel("Motion")
                Text("Feedback reveal: ease out, 0.15 s, fade and 4 pt rise. Cursor blink: 1 s period.")
                Text("Both are off when Reduce Motion is on.")
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TerminalLabel("Text size steps · View › Bigger ⌘+ · Smaller ⌘− · Actual Size ⌘0")
                Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.xs) {
                    GridRow {
                        Text("Step")
                        Text("Scale")
                        Text("Reading width")
                    }
                    .themeFont(.label)
                    .foregroundStyle(Theme.textSecondary)
                    ForEach(TextSize.allCases, id: \.self) { size in
                        GridRow {
                            Text(verbatim: (size == textSize ? "› " : "  ") + size.name)
                            Text(size.scale, format: .number)
                            Text(Theme.readingWidth(for: size), format: .number.precision(.fractionLength(0)))
                        }
                        .themeFont(.code)
                        .foregroundStyle(size == textSize ? Theme.accent : Theme.text)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(size == textSize ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func shapeSample(label: String, border: ThemeColor, width: Double) -> some View {
        Text(verbatim: label)
            .themeFont(.label)
            .foregroundStyle(Theme.textSecondary)
            .padding(Theme.Spacing.m)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .strokeBorder(border, lineWidth: width)
            }
    }
}
