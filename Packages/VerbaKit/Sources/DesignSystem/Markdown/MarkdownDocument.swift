import Foundation

/// A lesson explanation parsed from Markdown into blocks.
///
/// Parsing never fails and never loses text: if Foundation cannot parse the Markdown, or the
/// parse yields nothing for non blank input, the whole text becomes one `.plain` block.
nonisolated public struct MarkdownDocument: Equatable, Sendable {
    /// The blocks in reading order.
    public let blocks: [MarkdownBlock]

    /// Parses Markdown text. Blank text gives no blocks.
    public init(markdown: String) {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            blocks = []
            return
        }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            blocks = [.plain(markdown)]
            return
        }
        let parsedBlocks = MarkdownBlockBuilder(source: parsed).blocks()
        blocks = parsedBlocks.isEmpty ? [.plain(markdown)] : parsedBlocks
    }
}

/// A run of text with one presentation intent (the block structure it belongs to).
nonisolated private struct IntentRun {
    let components: [PresentationIntent.IntentType]
    let text: AttributedString

    /// Identity of the outermost block, which decides the top level block this run belongs to.
    var outerIdentity: Int? { components.last?.identity }

    /// The innermost component whose kind matches.
    func innermost(where matches: (PresentationIntent.Kind) -> Bool) -> PresentationIntent.IntentType? {
        components.first { matches($0.kind) }
    }
}

/// Turns the presentation intents Foundation attaches to a parsed `AttributedString` into blocks.
nonisolated private struct MarkdownBlockBuilder {
    let source: AttributedString

    func blocks() -> [MarkdownBlock] {
        let runs = source.runs[\.presentationIntent].map { intent, range in
            IntentRun(components: intent?.components ?? [], text: AttributedString(source[range]))
        }
        return grouped(runs, by: \.outerIdentity).compactMap(block(for:))
    }

    private func block(for runs: [IntentRun]) -> MarkdownBlock? {
        guard let outer = runs.first?.components.last else {
            return .plain(runs.map { String($0.text.characters) }.joined())
        }
        switch outer.kind {
        case .paragraph:
            return .paragraph(joinedParagraphs(runs))
        case .header(let level):
            return .heading(level: level, text: joinedParagraphs(runs))
        case .orderedList, .unorderedList:
            return .list(listItems(runs))
        case .blockQuote:
            let paragraphs = grouped(runs) { $0.components.first?.identity }.map(joinedText)
            return .quote(paragraphs)
        case .codeBlock:
            let code = runs.map { String($0.text.characters) }.joined()
            return .code(code.hasSuffix("\n") ? String(code.dropLast()) : code)
        case .table(let columns):
            return .table(table(runs, columns: columns))
        default:
            return .plain(runs.map { String($0.text.characters) }.joined())
        }
    }

    private func listItems(_ runs: [IntentRun]) -> [MarkdownListItem] {
        let itemGroups = grouped(runs) { run in
            run.innermost { if case .listItem = $0 { true } else { false } }?.identity
        }
        return itemGroups.compactMap { itemRuns in
            guard let components = itemRuns.first?.components,
                let itemIndex = components.firstIndex(where: { if case .listItem = $0.kind { true } else { false } })
            else { return nil }
            let depth = components.filter(\.kind.isList).count
            let marker: String
            if case .listItem(let ordinal) = components[itemIndex].kind,
                components.indices.contains(itemIndex + 1),
                case .orderedList = components[itemIndex + 1].kind
            {
                marker = "\(ordinal)."
            } else {
                marker = depth > 1 ? "◦" : "•"
            }
            return MarkdownListItem(depth: depth, marker: marker, text: joinedParagraphs(itemRuns))
        }
    }

    private func table(_ runs: [IntentRun], columns: [PresentationIntent.TableColumn]) -> MarkdownTable {
        let alignments: [MarkdownTable.Alignment] = columns.map {
            switch $0.alignment {
            case .center: .center
            case .right: .trailing
            default: .leading
            }
        }
        var header: [AttributedString] = []
        var rows: [[AttributedString]] = []
        let rowGroups = grouped(runs) { run in
            run.innermost { kind in
                switch kind {
                case .tableHeaderRow, .tableRow: true
                default: false
                }
            }?.identity
        }
        for rowRuns in rowGroups {
            let cells = tableCells(rowRuns, columnCount: columns.count)
            let isHeader = rowRuns.first?.components.contains {
                if case .tableHeaderRow = $0.kind { true } else { false }
            }
            if isHeader == true, header.isEmpty {
                header = cells
            } else {
                rows.append(cells)
            }
        }
        return MarkdownTable(alignments: alignments, header: header, rows: rows)
    }

    /// The cells of one table row, padded so a short row still has one entry per column.
    private func tableCells(_ rowRuns: [IntentRun], columnCount: Int) -> [AttributedString] {
        var cells = Array(repeating: AttributedString(), count: columnCount)
        for run in rowRuns {
            guard case .tableCell(let column)? = run.innermost(where: \.isTableCell)?.kind else { continue }
            if column >= cells.count {
                cells.append(contentsOf: Array(repeating: AttributedString(), count: column - cells.count + 1))
            }
            cells[column].append(run.text)
        }
        return cells
    }

    /// Joins runs into one text, putting a line break where one paragraph ends and the next begins.
    private func joinedParagraphs(_ runs: [IntentRun]) -> AttributedString {
        let paragraphs = grouped(runs) { run in
            run.innermost { if case .paragraph = $0 { true } else { false } }?.identity
                ?? run.components.first?.identity
        }
        var result = AttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            result.append(joinedText(paragraph))
        }
        return result
    }

    private func joinedText(_ runs: [IntentRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs { result.append(run.text) }
        result.presentationIntent = nil
        return result
    }

    /// Splits runs into consecutive groups that share the same key.
    private func grouped<Key: Equatable>(_ runs: [IntentRun], by key: (IntentRun) -> Key) -> [[IntentRun]] {
        var groups: [[IntentRun]] = []
        var currentKey: Key?
        for run in runs {
            let runKey = key(run)
            if let last = groups.indices.last, currentKey == runKey {
                groups[last].append(run)
            } else {
                groups.append([run])
                currentKey = runKey
            }
        }
        return groups
    }
}

nonisolated extension PresentationIntent.Kind {
    fileprivate var isList: Bool {
        switch self {
        case .orderedList, .unorderedList: true
        default: false
        }
    }

    fileprivate var isTableCell: Bool {
        if case .tableCell = self { true } else { false }
    }
}
