import Foundation

/// One block of a lesson explanation, ready to show on screen or in print.
///
/// Inline styling (bold, italic, inline code, links) stays inside the `AttributedString` of each
/// block; the view and the print builder map it to their own fonts.
nonisolated public enum MarkdownBlock: Equatable, Sendable {
    /// A paragraph of running text.
    case paragraph(AttributedString)
    /// A heading; `level` is 1 for `#`, 2 for `##`, and so on.
    case heading(level: Int, text: AttributedString)
    /// A list, nested lists flattened into one list of items that each carry their depth.
    case list([MarkdownListItem])
    /// A block quote, one entry per paragraph inside it.
    case quote([AttributedString])
    /// A fenced or indented code block, without its trailing line break.
    case code(String)
    /// A table with its column alignments, header row, and body rows.
    case table(MarkdownTable)
    /// Anything the renderer does not know (HTML, a thematic break), shown as its raw characters.
    case plain(String)

    /// The block's text without styling: list items and quote paragraphs one per line, table
    /// cells separated by tabs. Tests and accessibility use it.
    public var plainText: String {
        switch self {
        case .paragraph(let text), .heading(_, let text):
            String(text.characters)
        case .list(let items):
            items.map { $0.marker + " " + String($0.text.characters) }.joined(separator: "\n")
        case .quote(let paragraphs):
            paragraphs.map { String($0.characters) }.joined(separator: "\n")
        case .code(let code), .plain(let code):
            code
        case .table(let table):
            ([table.header] + table.rows)
                .map { row in row.map { String($0.characters) }.joined(separator: "\t") }
                .joined(separator: "\n")
        }
    }
}

/// One item of a Markdown list.
nonisolated public struct MarkdownListItem: Equatable, Sendable {
    /// How deep the item sits: 1 for a top level item, 2 for an item in a nested list.
    public let depth: Int
    /// The marker shown before the item: `3.` in an ordered list, a bullet otherwise.
    public let marker: String
    /// The item's text; several paragraphs are joined by line breaks.
    public let text: AttributedString

    /// Creates a list item.
    public init(depth: Int, marker: String, text: AttributedString) {
        self.depth = depth
        self.marker = marker
        self.text = text
    }
}

/// A Markdown table.
nonisolated public struct MarkdownTable: Equatable, Sendable {
    /// How a column's cells line up.
    public enum Alignment: Equatable, Sendable {
        /// Left aligned (also the default when the Markdown sets none).
        case leading
        /// Centered.
        case center
        /// Right aligned.
        case trailing
    }

    /// One alignment per column.
    public let alignments: [Alignment]
    /// The header row's cells.
    public let header: [AttributedString]
    /// The body rows, each with one entry per cell.
    public let rows: [[AttributedString]]

    /// Creates a table.
    public init(alignments: [Alignment], header: [AttributedString], rows: [[AttributedString]]) {
        self.alignments = alignments
        self.header = header
        self.rows = rows
    }

    /// The number of columns: the widest of the alignments, the header, and every row.
    public var columnCount: Int {
        ([alignments.count, header.count] + rows.map(\.count)).max() ?? 0
    }
}
