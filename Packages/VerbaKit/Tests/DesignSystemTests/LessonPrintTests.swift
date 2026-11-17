import AppKit
import DesignSystem
import Testing

@MainActor
struct LessonPrintTests {
    private func printed(_ document: LessonPrintDocument = .sample) -> NSAttributedString {
        LessonPrinter.attributedString(for: document)
    }

    @Test func usesOnlyPrintPaletteColorsAndNoBackground() throws {
        let text = printed()
        let allowed = Set(ColorToken.allCases.compactMap { Palette.print[$0] })
        var seen = Set<RGB>()
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            #expect(attributes[.backgroundColor] == nil)
            let color = attributes[.foregroundColor] as? NSColor
            guard let srgb = color?.usingColorSpace(.sRGB) else {
                Issue.record("No foreground color at \(range)")
                return
            }
            let hex =
                UInt32((srgb.redComponent * 255).rounded()) << 16
                | UInt32((srgb.greenComponent * 255).rounded()) << 8
                | UInt32((srgb.blueComponent * 255).rounded())
            seen.insert(RGB(hex: hex))
        }
        #expect(seen.isSubset(of: allowed))
        #expect(seen.contains(Palette.print[.text]!))
    }

    @Test func containsTitleTopicExplanationAndEveryExercise() {
        let string = printed().string
        #expect(string.hasPrefix(SampleLesson.title))
        #expect(string.contains(SampleLesson.topic.uppercased()))
        #expect(string.contains("Kiedy używamy ser"))
        #expect(string.contains("yo\tsoy\testoy"))
        for exercise in LessonPrintDocument.sample.exercises {
            #expect(string.contains("0\(exercise.number) · \(exercise.kindLabel.uppercased())"))
            #expect(string.contains(exercise.prompt))
        }
    }

    @Test func everyGradeShowsGlyphAndWord() {
        let string = printed().string
        for tone in FeedbackTone.allCases {
            #expect(string.contains(tone.title))
        }
    }

    @Test func missingAnswerPrintsNotAnswered() {
        let document = LessonPrintDocument(
            title: "T", topic: "t", explanationMarkdown: "x",
            exercises: [
                PrintedExercise(
                    number: 1, kindLabel: "Choice", prompt: "P", answer: nil, tone: nil, correctAnswer: "es",
                    explanation: "E")
            ])
        let string = printed(document).string
        #expect(string.contains("Not answered"))
        #expect(string.contains("Answer: es"))
        #expect(!string.contains("Your answer"))
    }

    @Test func correctAnswerIsLeftOutWhenTheGradeIsCorrect() {
        let document = LessonPrintDocument(
            title: "T", topic: "t", explanationMarkdown: "x",
            exercises: [
                PrintedExercise(
                    number: 1, kindLabel: "Choice", prompt: "P", answer: "es", tone: .correct, correctAnswer: "es",
                    explanation: nil)
            ])
        let string = printed(document).string
        #expect(string.contains("Your answer: es"))
        #expect(!string.contains("Answer: es\n"))
    }
}
