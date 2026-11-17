/// Everything a printed lesson shows, as plain values: the feature maps its lesson and the
/// learner's last answers into this, and `LessonPrinter` turns it into pages.
nonisolated public struct LessonPrintDocument: Equatable, Sendable {
    /// The lesson title.
    public let title: String
    /// The lesson topic, printed as a label.
    public let topic: String
    /// The explanation in Markdown.
    public let explanationMarkdown: String
    /// The exercises in lesson order.
    public let exercises: [PrintedExercise]

    /// Creates a print document.
    public init(title: String, topic: String, explanationMarkdown: String, exercises: [PrintedExercise]) {
        self.title = title
        self.topic = topic
        self.explanationMarkdown = explanationMarkdown
        self.exercises = exercises
    }

    /// The sample lesson with its sample answers, which the Design Gallery prints.
    public static var sample: LessonPrintDocument {
        LessonPrintDocument(
            title: SampleLesson.title,
            topic: SampleLesson.topic,
            explanationMarkdown: SampleLesson.explanation,
            exercises: SampleLesson.exercises.map { exercise in
                PrintedExercise(
                    number: exercise.position + 1,
                    kindLabel: exercise.kindLabel,
                    prompt: exercise.prompt,
                    answer: exercise.sampleAnswer,
                    tone: exercise.sampleTone,
                    correctAnswer: exercise.correctAnswer,
                    explanation: exercise.explanation
                )
            }
        )
    }
}

/// One exercise as printed: prompt, the learner's last answer, its grade, and the explanation.
nonisolated public struct PrintedExercise: Equatable, Sendable {
    /// The 1 based exercise number.
    public let number: Int
    /// The kind in words, such as `Translate`; printed in capitals.
    public let kindLabel: String
    /// The prompt, as written.
    public let prompt: String
    /// The learner's last answer as text, or `nil` (prints "Not answered").
    public let answer: String?
    /// The grade of that answer, or `nil` when there is none.
    public let tone: FeedbackTone?
    /// The correct answer, printed when the grade is not correct.
    public let correctAnswer: String?
    /// The explanation.
    public let explanation: String?

    /// Creates a printed exercise.
    public init(
        number: Int,
        kindLabel: String,
        prompt: String,
        answer: String?,
        tone: FeedbackTone?,
        correctAnswer: String?,
        explanation: String?
    ) {
        self.number = number
        self.kindLabel = kindLabel
        self.prompt = prompt
        self.answer = answer
        self.tone = tone
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
}
