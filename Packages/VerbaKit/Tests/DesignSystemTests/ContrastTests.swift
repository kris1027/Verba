import DesignSystem
import Testing

/// One row of the spec's *Contrast pairs* table, applied to one palette.
struct ContrastPair: CustomTestStringConvertible, Sendable {
    let palette: Palette
    let foreground: ColorToken
    let background: ColorToken
    let threshold: Double

    var testDescription: String {
        "\(palette.name): \(foreground.rawValue) on \(background.rawValue) ≥ \(threshold)"
    }
}

/// Every pair AC-3 requires, for the standard, Increase Contrast, and print palettes.
let contrastPairs: [ContrastPair] = {
    var pairs: [ContrastPair] = []
    func add(_ palette: Palette, _ foregrounds: [ColorToken], on backgrounds: [ColorToken], _ threshold: Double) {
        for foreground in foregrounds {
            for background in backgrounds {
                pairs.append(
                    ContrastPair(palette: palette, foreground: foreground, background: background, threshold: threshold)
                )
            }
        }
    }
    let grounds: [ColorToken] = [.background, .surface, .raised]
    for palette in [Palette.standard, .increasedContrast] {
        let readingThreshold = palette.name == Palette.increasedContrast.name ? 7.0 : 4.5
        add(palette, [.text, .textSecondary], on: grounds, readingThreshold)
        add(palette, [.textTertiary], on: grounds, 4.5)
        add(palette, [.correct, .partly, .wrong], on: [.surface, .raised], 4.5)
        add(palette, [.accent], on: grounds, 3.0)
        add(palette, [.onAccent], on: [.accent], 4.5)
        add(palette, [.controlBorder], on: grounds, 3.0)
    }
    add(.print, [.text, .textSecondary, .textTertiary, .correct, .partly, .wrong], on: [.background], 4.5)
    add(.print, [.controlBorder], on: [.background], 3.0)
    return pairs
}()

struct ContrastTests {
    @Test(arguments: contrastPairs)
    func pairMeetsItsThreshold(pair: ContrastPair) throws {
        let foreground = try #require(pair.palette[pair.foreground])
        let background = try #require(pair.palette[pair.background])
        #expect(Contrast.ratio(foreground, background) >= pair.threshold)
    }

    @Test func blackOnWhiteIsTwentyOne() {
        let ratio = Contrast.ratio(RGB(hex: 0x000000), RGB(hex: 0xFFFFFF))
        #expect(abs(ratio - 21) < 0.001)
    }

    @Test func ratioIgnoresArgumentOrder() {
        let first = RGB(hex: 0xA3B899)
        let second = RGB(hex: 0x151816)
        #expect(Contrast.ratio(first, second) == Contrast.ratio(second, first))
    }

    @Test func screenPalettesFillEveryToken() {
        for palette in [Palette.standard, .increasedContrast] {
            #expect(ColorToken.allCases.allSatisfy { palette[$0] != nil }, "\(palette.name)")
        }
    }

    @Test func printPaletteHasNoAccent() {
        #expect(Palette.print[.accent] == nil)
        #expect(Palette.print[.onAccent] == nil)
    }

    @Test func hexStringRoundTrips() {
        #expect(RGB(hex: 0x0E100F).hexString == "#0E100F")
    }
}
