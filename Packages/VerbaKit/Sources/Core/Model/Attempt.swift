import Foundation

/// What the learner answered, in the shape the exercise kind expects.
public enum AttemptResponse: Sendable, Hashable, Codable {
    /// Typed text, for `fillBlank` and `translate`.
    case text(String)
    /// The chosen option, for `choice`.
    case choice(ExercisePartID)
    /// The parts in the order the learner put them, for `reorder`.
    case order([ExercisePartID])
    /// The pairs the learner made, for `match`.
    case pairs([[ExercisePartID]])
}

/// How an attempt was graded.
public enum Grade: String, Sendable, Hashable, Codable {
    /// Fully right.
    case correct
    /// Partly right. Counts as not correct for the score.
    case partlyCorrect
    /// Wrong.
    case wrong
}

/// Who graded an attempt.
public enum GradedBy: String, Sendable, Hashable, Codable {
    /// The app's own `Grader`.
    case app
    /// Claude.
    case claude
}

/// One saved answer to an exercise. Every attempt is kept.
public struct Attempt: Sendable, Hashable, Identifiable {
    /// The attempt's identity.
    public let id: AttemptID
    /// The exercise it answers.
    public let exerciseID: ExerciseID
    /// The attempt's number for this exercise, from 1.
    public let attemptNumber: Int
    /// What the learner answered.
    public let response: AttemptResponse
    /// The grade given.
    public let grade: Grade
    /// The explanation, in the learner's native language.
    public let feedback: String
    /// Who graded it.
    public let gradedBy: GradedBy
    /// When the attempt was saved.
    public let answeredAt: Date

    /// Creates an attempt value.
    public init(
        id: AttemptID, exerciseID: ExerciseID, attemptNumber: Int, response: AttemptResponse, grade: Grade,
        feedback: String, gradedBy: GradedBy, answeredAt: Date
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.attemptNumber = attemptNumber
        self.response = response
        self.grade = grade
        self.feedback = feedback
        self.gradedBy = gradedBy
        self.answeredAt = answeredAt
    }
}

/// An answer to save. The store assigns its number and time.
public struct NewAttempt: Sendable, Hashable {
    /// The new attempt's identity.
    public let id: AttemptID
    /// The exercise it answers.
    public let exerciseID: ExerciseID
    /// What the learner answered.
    public let response: AttemptResponse
    /// The grade given.
    public let grade: Grade
    /// The explanation, in the learner's native language.
    public let feedback: String
    /// Who graded it.
    public let gradedBy: GradedBy

    /// Creates an answer to save.
    public init(
        id: AttemptID = AttemptID(), exerciseID: ExerciseID, response: AttemptResponse, grade: Grade, feedback: String,
        gradedBy: GradedBy
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.response = response
        self.grade = grade
        self.feedback = feedback
        self.gradedBy = gradedBy
    }
}
