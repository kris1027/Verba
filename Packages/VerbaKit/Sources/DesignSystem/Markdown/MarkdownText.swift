import SwiftUI

/// A lesson explanation rendered from Markdown with the reading fonts: paragraphs, headings,
/// lists (nested ones indented), block quotes, code blocks, and tables. Anything else shows as
/// plain text, so an explanation is never blank and never an error.
public struct MarkdownText: View {
    private let document: MarkdownDocument

    /// Parses and shows Markdown text.
    public init(markdown: String) {
        document = MarkdownDocument(markdown: markdown)
    }

    /// Shows an already parsed document.
    public init(document: MarkdownDocument) {
        self.document = document
    }

    /// The blocks, top to bottom.
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ForEach(document.blocks.indices, id: \.self) { index in
                MarkdownBlockView(block: document.blocks[index])
            }
        }
        .foregroundStyle(Theme.text)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    @Environment(\.textSize) private var textSize

    var body: some View {
        switch block {
        case .paragraph(let text):
            reading(text, as: .readingBody)
        case .heading(_, let text):
            reading(text, as: .readingHeading)
                .accessibilityAddTraits(.isHeader)
        case .list(let items):
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(items.indices, id: \.self) { index in
                    listRow(items[index])
                }
            }
        case .quote(let paragraphs):
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: Theme.Shape.focusBorderWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(paragraphs.indices, id: \.self) { index in
                        reading(paragraphs[index], as: .readingBody)
                    }
                }
                .foregroundStyle(Theme.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let code):
            ScrollView(.horizontal) {
                Text(verbatim: code)
                    .themeFont(.code)
                    .padding(Theme.Spacing.m)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
        case .table(let table):
            MarkdownTableView(table: table)
        case .plain(let text):
            Text(verbatim: text)
                .themeFont(.readingBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reading(_ text: AttributedString, as font: ThemeFont) -> some View {
        Text(text.styledInline(base: font, size: textSize))
            .themeFont(font)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func listRow(_ item: MarkdownListItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(verbatim: item.marker)
                .themeFont(.readingBody)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(item.marker == "•" || item.marker == "◦")
            reading(item.text, as: .readingBody)
        }
        .padding(.leading, Double(item.depth - 1) * Theme.Spacing.xl)
    }
}

/// A Markdown table as a grid: bold header, a hairline under it, and the column alignments.
/// It sits in a horizontal scroll view, so a table wider than the column scrolls instead of clipping.
private struct MarkdownTableView: View {
    let table: MarkdownTable
    @Environment(\.textSize) private var textSize

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.xl, verticalSpacing: Theme.Spacing.s) {
                if !table.header.isEmpty {
                    GridRow {
                        ForEach(0..<table.columnCount, id: \.self) { column in
                            cell(table.header, column: column, font: .readingHeading)
                                .gridColumnAlignment(alignment(of: column))
                        }
                    }
                    .accessibilityAddTraits(.isHeader)
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: Theme.Shape.borderWidth)
                        .gridCellUnsizedAxes(.horizontal)
                        .accessibilityHidden(true)
                }
                ForEach(table.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(0..<table.columnCount, id: \.self) { column in
                            cell(table.rows[row], column: column, font: .readingBody)
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .scrollIndicators(.automatic)
    }

    private func cell(_ cells: [AttributedString], column: Int, font: ThemeFont) -> some View {
        let text = cells.indices.contains(column) ? cells[column] : AttributedString()
        return Text(text.styledInline(base: font, size: textSize))
            .themeFont(font)
            .fixedSize()
    }

    private func alignment(of column: Int) -> HorizontalAlignment {
        guard table.alignments.indices.contains(column) else { return .leading }
        switch table.alignments[column] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

extension AttributedString {
    /// Maps inline Markdown styling to theme fonts at the current text size: strong to bold,
    /// emphasis to italic, inline code to the `code` font. Unstyled runs keep no font of their
    /// own, so they take the font of the surrounding `.themeFont(_:)`.
    func styledInline(base: ThemeFont, size: TextSize) -> AttributedString {
        var result = self
        for run in result.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.code) {
                result[run.range].font = ThemeFont.code.font(for: size)
                continue
            }
            var font = base.font(for: size)
            if intent.contains(.stronglyEmphasized) { font = font.bold() }
            if intent.contains(.emphasized) { font = font.italic() }
            if intent.contains(.stronglyEmphasized) || intent.contains(.emphasized) {
                result[run.range].font = font
            }
        }
        return result
    }
}
