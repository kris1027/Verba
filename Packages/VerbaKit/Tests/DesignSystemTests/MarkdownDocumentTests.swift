import DesignSystem
import Foundation
import Testing

struct MarkdownDocumentTests {
    @Test func paragraphsAndHeadingsBecomeSeparateBlocks() {
        let document = MarkdownDocument(markdown: "# Ser\n\nFirst paragraph.\n\nSecond **bold** one.")
        #expect(document.blocks.count == 3)
        #expect(document.blocks[0] == .heading(level: 1, text: AttributedString("Ser")))
        #expect(document.blocks[1].plainText == "First paragraph.")
        #expect(document.blocks[2].plainText == "Second bold one.")
    }

    @Test func inlineStylingStaysInTheText() throws {
        let document = MarkdownDocument(markdown: "Use **soy** and *estoy* and `es`.")
        guard case .paragraph(let text) = try #require(document.blocks.first) else {
            Issue.record("Expected a paragraph")
            return
        }
        let intents = text.runs.compactMap(\.inlinePresentationIntent)
        #expect(intents.contains(.stronglyEmphasized))
        #expect(intents.contains(.emphasized))
        #expect(intents.contains(.code))
    }

    @Test func nestedListFlattensWithDepthAndMarkers() throws {
        let markdown = """
            1. Zawód
               - Soy profesora.
               - Soy de Polonia.
            2. Cechy
            """
        let document = MarkdownDocument(markdown: markdown)
        #expect(document.blocks.count == 1)
        guard case .list(let items) = try #require(document.blocks.first) else {
            Issue.record("Expected a list")
            return
        }
        #expect(items.map(\.depth) == [1, 2, 2, 1])
        #expect(items.map(\.marker) == ["1.", "◦", "◦", "2."])
        #expect(items.map { String($0.text.characters) } == ["Zawód", "Soy profesora.", "Soy de Polonia.", "Cechy"])
    }

    @Test func tableKeepsHeaderRowsAndAlignments() throws {
        let markdown = """
            | Osoba | ser | estar |
            |:--|:-:|--:|
            | yo | soy | estoy |
            | tú | eres | estás |
            """
        let document = MarkdownDocument(markdown: markdown)
        guard case .table(let table) = try #require(document.blocks.first) else {
            Issue.record("Expected a table")
            return
        }
        #expect(table.alignments == [.leading, .center, .trailing])
        #expect(table.header.map { String($0.characters) } == ["Osoba", "ser", "estar"])
        #expect(
            table.rows.map { $0.map { String($0.characters) } } == [["yo", "soy", "estoy"], ["tú", "eres", "estás"]])
        #expect(table.columnCount == 3)
    }

    @Test func codeBlockKeepsItsTextWithoutTheTrailingLineBreak() {
        let document = MarkdownDocument(markdown: "```\nser   → soy\nestar → estoy\n```")
        #expect(document.blocks == [.code("ser   → soy\nestar → estoy")])
    }

    @Test func blockQuoteKeepsEachParagraph() {
        let document = MarkdownDocument(markdown: "> one\n>\n> two")
        #expect(document.blocks.count == 1)
        #expect(document.blocks.first?.plainText == "one\ntwo")
        guard case .quote(let paragraphs) = document.blocks.first else {
            Issue.record("Expected a quote")
            return
        }
        #expect(paragraphs.count == 2)
    }

    @Test func htmlAndThematicBreakShowAsPlainText() {
        let document = MarkdownDocument(markdown: "Intro.\n\n<div>To jest HTML.</div>\n\n---\n\nEnd.")
        #expect(document.blocks.count == 4)
        guard case .plain(let html) = document.blocks[1], case .plain(let rule) = document.blocks[2] else {
            Issue.record("Expected plain blocks for HTML and the thematic break, got \(document.blocks)")
            return
        }
        #expect(html.contains("To jest HTML."))
        #expect(!rule.isEmpty)
        #expect(document.blocks[3].plainText == "End.")
    }

    @Test(arguments: ["*unclosed emphasis", "| broken | table\n|--", "[link](", "```\nnever closed", "<<<>>>"])
    func malformedInputNeverGivesAnEmptyResult(markdown: String) {
        let document = MarkdownDocument(markdown: markdown)
        #expect(!document.blocks.isEmpty)
        #expect(document.blocks.allSatisfy { !$0.plainText.isEmpty })
    }

    @Test func blankInputGivesNoBlocks() {
        #expect(MarkdownDocument(markdown: "  \n\n ").blocks.isEmpty)
    }

    @Test func sampleLessonHasEveryBlockKindTheGalleryShows() {
        let blocks = MarkdownDocument(markdown: SampleLesson.explanation).blocks
        #expect(blocks.contains { if case .table = $0 { true } else { false } })
        #expect(blocks.contains { if case .list(let items) = $0 { items.contains { $0.depth == 2 } } else { false } })
        #expect(blocks.contains { if case .quote = $0 { true } else { false } })
        #expect(blocks.contains { if case .code = $0 { true } else { false } })
    }
}
