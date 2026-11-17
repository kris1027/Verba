import SwiftUI
import Testing

@testable import DesignSystem

@MainActor
struct ExerciseComponentTests {
    @Test(arguments: [(0, 8, "01/08"), (2, 8, "03/08"), (9, 12, "10/12")])
    func counterShowsTwoDigitPositionAndCount(position: Int, count: Int, expected: String) {
        #expect(ExerciseCard<EmptyViewStub>.counter(position: position, count: count) == expected)
    }

    @Test func toneGlyphsAndWordsMatchTheSpec() {
        #expect(FeedbackTone.correct.title == "✓ Correct")
        #expect(FeedbackTone.partlyCorrect.title == "~ Partly correct")
        #expect(FeedbackTone.wrong.title == "✗ Not quite")
    }

    @Test func tonesUseThreeDistinctColorsNoneOfThemTheAccent() {
        let tokens = FeedbackTone.allCases.map(\.colorToken)
        #expect(Set(tokens).count == 3)
        #expect(!tokens.contains(.accent))
        let colors = tokens.compactMap { Palette.standard[$0] }
        #expect(Set(colors).count == 3)
    }

    @Test func actionTitles() {
        #expect(ExerciseAction.check {}.title == "Check")
        #expect(ExerciseAction.next {}.title == "Next")
        #expect(ExerciseAction.disabled.title == "Check")
    }

    @Test func feedbackPhaseDropsTheActions() {
        #expect(FeedbackState.hidden.phase == .hidden)
        #expect(FeedbackState.checking(cancel: {}).phase == .checking)
        #expect(FeedbackState.failed(message: "x", retry: {}).phase == .failed)
        #expect(FeedbackState.result(tone: .wrong, correctAnswer: "es", explanation: nil).phase == .result(.wrong))
    }

    @Test func matchPairLettersFollowLeftRows() {
        #expect(MatchBoard.letter(forLeft: 0) == "A")
        #expect(MatchBoard.letter(forLeft: 3) == "D")
        #expect(MatchBoard.letter(forLeft: 30) == "31")
    }

    @Test func sampleLessonHasAllFiveKindsAndEveryGrade() {
        let exercises = SampleLesson.exercises
        #expect(exercises.map(\.kindLabel) == ["Choice", "Fill in", "Translate", "Order", "Match"])
        #expect(Set(exercises.compactMap(\.sampleTone)) == Set(FeedbackTone.allCases))
        #expect(exercises.contains { $0.sampleAnswer == nil })
    }
}

/// A stand in input type so the generic card's static helper can be named.
private struct EmptyViewStub: View {
    var body: some View { EmptyView() }
}
