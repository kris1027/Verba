import DesignSystem
import Testing

struct TextSizeTests {
    @Test func stepsRunFromXSmallToAccessibility3() {
        #expect(TextSize.allCases.first == .xSmall)
        #expect(TextSize.allCases.last == .accessibility3)
        #expect(TextSize.allCases.map(\.rawValue) == Array(0...9))
    }

    @Test func scaleTableMatchesTheSpec() {
        let expected = [0.82, 0.88, 0.94, 1.0, 1.12, 1.24, 1.35, 1.65, 1.94, 2.35]
        #expect(TextSize.allCases.map(\.scale) == expected)
    }

    @Test func scaleRisesStrictlyAndLargeIsOne() {
        let scales = TextSize.allCases.map(\.scale)
        #expect(zip(scales, scales.dropFirst()).allSatisfy { $0 < $1 })
        #expect(TextSize.large.scale == 1.0)
        #expect(TextSize.defaultSize == .large)
    }

    @Test func biggerAndSmallerStopAtTheEnds() {
        #expect(TextSize.accessibility3.bigger == nil)
        #expect(TextSize.xSmall.smaller == nil)
        #expect(TextSize.large.bigger == .xLarge)
        #expect(TextSize.large.smaller == .medium)
    }

    @Test(arguments: [nil, -1, 10, 99])
    func unknownStoredValueFallsBackToLarge(stored: Int?) {
        #expect(TextSize(storedValue: stored) == .large)
    }

    @Test func knownStoredValueIsKept() {
        #expect(TextSize(storedValue: 9) == .accessibility3)
        #expect(TextSize(storedValue: 0) == .xSmall)
    }

    @Test func largeControlsStartAtXXXLarge() {
        #expect(
            TextSize.allCases.filter(\.usesLargeControls) == [
                .xxxLarge, .accessibility1, .accessibility2, .accessibility3,
            ])
    }

    @Test(arguments: [(TextSize.xSmall, 557.6), (.large, 680.0), (.accessibility3, 1598.0)])
    func readingWidthGrowsWithTheScale(size: TextSize, width: Double) {
        #expect(abs(Theme.readingWidth(for: size) - width) < 0.001)
    }
}

struct ThemeFontTests {
    @Test func onlyReadingBodyHasLineSpacingAndItScales() {
        #expect(ThemeFont.readingBody.lineSpacing(for: .large) == Theme.Spacing.xs)
        #expect(abs(ThemeFont.readingBody.lineSpacing(for: .accessibility3) - Theme.Spacing.xs * 2.35) < 0.001)
        for font in ThemeFont.allCases where font != .readingBody {
            #expect(font.lineSpacing(for: .accessibility3) == 0, "\(font.name)")
        }
    }

    @Test func onlyLabelsAreUppercaseAndTracked() {
        #expect(ThemeFont.allCases.filter(\.isUppercase) == [.label])
        #expect(ThemeFont.allCases.filter { $0.tracking != 0 } == [.label])
        #expect(ThemeFont.label.tracking == 0.5)
    }

    @Test func spacingFollowsTheFourPointGrid() {
        let steps = [
            Theme.Spacing.xs, Theme.Spacing.s, Theme.Spacing.m, Theme.Spacing.l, Theme.Spacing.xl, Theme.Spacing.xxl,
        ]
        #expect(steps == [4, 8, 12, 16, 24, 40])
        #expect(steps.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
    }

    @Test func feedbackRevealIsOffUnderReduceMotion() {
        #expect(Theme.Motion.feedbackReveal(reduceMotion: true) == nil)
        #expect(Theme.Motion.feedbackReveal(reduceMotion: false) != nil)
    }
}
