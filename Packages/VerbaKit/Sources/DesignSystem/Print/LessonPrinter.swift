import AppKit

/// Prints a lesson in the light print style: white page, print palette ink, New York body text,
/// no backgrounds. Paper sizes do not follow the screen text size. The standard print panel
/// offers Save as PDF, which keeps the text selectable.
public enum LessonPrinter {
    /// Shows the print panel for a lesson.
    public static func print(_ document: LessonPrintDocument) {
        guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
        printInfo.topMargin = Theme.Print.margin
        printInfo.bottomMargin = Theme.Print.margin
        printInfo.leftMargin = Theme.Print.margin
        printInfo.rightMargin = Theme.Print.margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isVerticallyCentered = false

        let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        textView.appearance = NSAppearance(named: .aqua)
        textView.backgroundColor = Palette.print.rgb(.background).nsColor
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.textStorage?.setAttributedString(attributedString(for: document))
        if let container = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: container)
        }
        textView.sizeToFit()

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.jobTitle = document.title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    /// The whole lesson as print styled text: title, topic, explanation, then every exercise.
    public static func attributedString(for document: LessonPrintDocument) -> NSAttributedString {
        var builder = PrintTextBuilder()
        builder.add(document.title, font: .serif(Theme.Print.title, bold: true), color: .text, spaceAfter: 4)
        builder.add(document.topic.uppercased(), font: .mono(Theme.Print.label), color: .textSecondary, spaceAfter: 14)
        for block in MarkdownDocument(markdown: document.explanationMarkdown).blocks {
            builder.add(block)
        }
        builder.add(
            "Exercises", font: .serif(Theme.Print.heading, bold: true), color: .text, spaceBefore: 10, spaceAfter: 6)
        for exercise in document.exercises {
            builder.add(exercise)
        }
        return builder.result
    }
}

/// Appends paragraphs in the print style. Every run gets an explicit print palette color and
/// no background.
private struct PrintTextBuilder {
    private(set) var result = NSMutableAttributedString()

    mutating func add(
        _ text: String,
        font: NSFont,
        color: ColorToken,
        indent: Double = 0,
        spaceBefore: Double = 0,
        spaceAfter: Double = 6,
        tabStops: [Double] = []
    ) {
        add(
            NSAttributedString(string: text), font: font, color: color, indent: indent, spaceBefore: spaceBefore,
            spaceAfter: spaceAfter, tabStops: tabStops)
    }

    mutating func add(
        _ text: NSAttributedString,
        font: NSFont,
        color: ColorToken,
        indent: Double = 0,
        spaceBefore: Double = 0,
        spaceAfter: Double = 6,
        tabStops: [Double] = []
    ) {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = spaceBefore
        style.paragraphSpacing = spaceAfter
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        style.lineHeightMultiple = 1.15
        style.tabStops = tabStops.map { NSTextTab(textAlignment: .left, location: $0) }
        let paragraph = NSMutableAttributedString(attributedString: text)
        paragraph.append(NSAttributedString(string: "\n"))
        let whole = NSRange(location: 0, length: paragraph.length)
        paragraph.addAttributes(
            [.foregroundColor: Palette.print.rgb(color).nsColor, .paragraphStyle: style], range: whole)
        paragraph.enumerateAttribute(.font, in: whole) { value, range, _ in
            if value == nil { paragraph.addAttribute(.font, value: font, range: range) }
        }
        result.append(paragraph)
    }

    mutating func add(_ block: MarkdownBlock) {
        let body = NSFont.serif(Theme.Print.body)
        switch block {
        case .paragraph(let text):
            add(inline(text, base: body), font: body, color: .text)
        case .heading(_, let text):
            let heading = NSFont.serif(Theme.Print.heading, bold: true)
            add(inline(text, base: heading), font: heading, color: .text, spaceBefore: 8, spaceAfter: 4)
        case .list(let items):
            for item in items {
                let indent = Double(item.depth) * 14
                let line = NSMutableAttributedString(string: item.marker + "\t")
                line.append(inline(item.text, base: body))
                add(line, font: body, color: .text, indent: indent, spaceAfter: 2, tabStops: [indent + 14])
            }
            addBlankLine(font: body)
        case .quote(let paragraphs):
            for paragraph in paragraphs {
                add(inline(paragraph, base: body), font: body, color: .textSecondary, indent: 14)
            }
        case .code(let code):
            add(code, font: .mono(Theme.Print.code), color: .text, indent: 14)
        case .table(let table):
            addTable(table, font: body)
        case .plain(let text):
            add(text, font: body, color: .text)
        }
    }

    mutating func add(_ exercise: PrintedExercise) {
        let body = NSFont.serif(Theme.Print.body)
        let label = NSFont.mono(Theme.Print.label)
        let number = exercise.number < 10 ? "0\(exercise.number)" : "\(exercise.number)"
        add(
            "\(number) · \(exercise.kindLabel.uppercased())", font: label, color: .textSecondary, spaceBefore: 10,
            spaceAfter: 2)
        add(exercise.prompt, font: body, color: .text, spaceAfter: 4)
        if let answer = exercise.answer {
            add("Your answer: \(answer)", font: body, color: .text, spaceAfter: 2)
        } else {
            add("Not answered", font: body, color: .textSecondary, spaceAfter: 2)
        }
        if let tone = exercise.tone {
            add(tone.title, font: .serif(Theme.Print.body, bold: true), color: tone.colorToken, spaceAfter: 2)
        }
        if exercise.tone != .correct, let correctAnswer = exercise.correctAnswer {
            add("Answer: \(correctAnswer)", font: body, color: .text, spaceAfter: 2)
        }
        if let explanation = exercise.explanation, !explanation.isEmpty {
            add(explanation, font: body, color: .text)
        }
    }

    private mutating func addBlankLine(font: NSFont) {
        result.append(
            NSAttributedString(
                string: "\n", attributes: [.font: font, .foregroundColor: Palette.print.rgb(.text).nsColor]))
    }

    /// A table as tab stopped rows: columns as wide as their widest cell, a rule under the header.
    private mutating func addTable(_ table: MarkdownTable, font: NSFont) {
        let bold = NSFont.serif(Theme.Print.body, bold: true)
        let gap = 16.0
        var widths = Array(repeating: 0.0, count: table.columnCount)
        for (row, rowFont) in [(table.header, bold)] + table.rows.map({ ($0, font) }) {
            for (column, cell) in row.enumerated() where column < widths.count {
                let width = (String(cell.characters) as NSString).size(withAttributes: [.font: rowFont]).width
                widths[column] = max(widths[column], width)
            }
        }
        var stops: [Double] = []
        var position = 0.0
        for width in widths.dropLast() {
            position += width + gap
            stops.append(position)
        }
        func line(_ cells: [AttributedString], font: NSFont) -> NSAttributedString {
            let line = NSMutableAttributedString()
            for (index, cell) in cells.enumerated() {
                if index > 0 { line.append(NSAttributedString(string: "\t")) }
                line.append(inline(cell, base: font))
            }
            return line
        }
        if !table.header.isEmpty {
            let header = NSMutableAttributedString(attributedString: line(table.header, font: bold))
            header.addAttribute(
                .underlineStyle, value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: header.length))
            add(header, font: bold, color: .text, spaceAfter: 3, tabStops: stops)
        }
        for row in table.rows {
            add(line(row, font: font), font: font, color: .text, spaceAfter: 2, tabStops: stops)
        }
        addBlankLine(font: font)
    }

    /// Maps inline Markdown styling to print fonts: strong to bold, emphasis to italic, code to mono.
    private func inline(_ text: AttributedString, base: NSFont) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for run in text.runs {
            let string = String(text[run.range].characters)
            var font = base
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    font = .mono(Theme.Print.code)
                } else {
                    var traits = base.fontDescriptor.symbolicTraits
                    if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                    if intent.contains(.emphasized) { traits.insert(.italic) }
                    font =
                        NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits), size: base.pointSize) ?? base
                }
            }
            output.append(NSAttributedString(string: string, attributes: [.font: font]))
        }
        return output
    }
}

extension NSFont {
    /// New York (the system serif) at a fixed print size.
    fileprivate static func serif(_ size: Double, bold: Bool = false) -> NSFont {
        let system = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        guard let descriptor = system.fontDescriptor.withDesign(.serif) else { return system }
        return NSFont(descriptor: descriptor, size: size) ?? system
    }

    /// SF Mono at a fixed print size.
    fileprivate static func mono(_ size: Double) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

nonisolated extension RGB {
    /// The AppKit color for this value in the sRGB color space (the print path uses AppKit).
    var nsColor: NSColor {
        NSColor(srgbRed: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: 1)
    }
}
