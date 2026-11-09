/// A lesson's score: exercises right on the first try, out of all its exercises.
public struct LessonScore: Sendable, Hashable {
    /// The exercises whose first attempt was graded `correct`.
    public let firstTryCorrect: Int
    /// The number of exercises in the lesson.
    public let exerciseCount: Int

    /// Derives the score from each exercise's attempts. A later correct attempt never changes it.
    public init(exercises: [(ExerciseID, [Attempt])]) {
        exerciseCount = exercises.count
        firstTryCorrect = exercises.count { _, attempts in
            attempts.first { $0.attemptNumber == 1 }?.grade == .correct
        }
    }
}
