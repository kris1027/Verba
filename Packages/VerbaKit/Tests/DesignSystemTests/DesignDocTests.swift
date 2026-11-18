import DesignSystem
import Foundation
import Testing

/// Keeps the root `design.md` honest: its palette table must list every token with the same hex
/// values as the code, and its print style must state the code's print sizes.
struct DesignDocTests {
    private struct Row {
        let standard: String
        let increasedContrast: String
        let print: String?
    }

    private static let designDoc = URL(filePath: #filePath)
        .deletingLastPathComponent()  // DesignSystemTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // VerbaKit
        .deletingLastPathComponent()  // Packages
        .deletingLastPathComponent()  // repository root
        .appending(path: "design.md")

    /// Parses `| \`token\` | role | \`#HEX\` | \`#HEX\` or same | \`#HEX\` or not used |` rows.
    private static func paletteRows() throws -> [String: Row] {
        let text = try String(contentsOf: designDoc, encoding: .utf8)
        var rows: [String: Row] = [:]
        for line in text.split(separator: "\n") where line.hasPrefix("| `") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 5 else { continue }
            func value(_ cell: String) -> String? {
                cell.hasPrefix("`#") ? cell.trimmingCharacters(in: CharacterSet(charactersIn: "`")) : nil
            }
            guard let standard = value(cells[2]) else { continue }
            let token = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            let increased = cells[3] == "same" ? standard : (value(cells[3]) ?? cells[3])
            rows[token] = Row(standard: standard, increasedContrast: increased, print: value(cells[4]))
        }
        return rows
    }

    @Test func paletteTableListsEveryToken() throws {
        let rows = try Self.paletteRows()
        #expect(Set(rows.keys) == Set(ColorToken.allCases.map(\.rawValue)))
    }

    @Test(arguments: ColorToken.allCases)
    func paletteHexValuesMatchTheCode(token: ColorToken) throws {
        let row = try #require(try Self.paletteRows()[token.rawValue], "design.md has no row for \(token)")
        #expect(row.standard == Palette.standard[token]?.hexString)
        #expect(row.increasedContrast == Palette.increasedContrast[token]?.hexString)
        #expect(row.print == Palette.print[token]?.hexString)
    }

    @Test func printSizesMatchTheCode() throws {
        let text = try String(contentsOf: Self.designDoc, encoding: .utf8)
        func points(_ value: Double) -> String { String(Int(value)) }
        let expected = [
            "\(points(Theme.Print.margin)) point margins",
            "title \(points(Theme.Print.title)) pt",
            "headings \(points(Theme.Print.heading)) pt",
            "body \(points(Theme.Print.body)) pt",
            "code \(points(Theme.Print.code)) pt",
            "labels \(points(Theme.Print.label)) pt",
        ]
        for phrase in expected {
            #expect(text.contains(phrase), "design.md does not say \"\(phrase)\"")
        }
    }
}
