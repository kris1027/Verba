import Foundation

/// An exercise with its parts and every attempt at it.
public struct ExerciseDetail: Sendable, Hashable, Identifiable {
    /// The exercise.
    public let exercise: Exercise
    /// Its parts, by display position once set, else by source position.
    public let parts: [ExercisePart]
    /// Its attempts, by attempt number.
    public let attempts: [Attempt]

    /// The exercise's identity.
    public var id: ExerciseID { exercise.id }

    /// Creates an exercise detail value.
    public init(exercise: Exercise, parts: [ExercisePart], attempts: [Attempt]) {
        self.exercise = exercise
        self.parts = parts
        self.attempts = attempts
    }
}

/// A whole lesson as saved, enough to reopen it exactly as the learner saw it.
public struct LessonDetail: Sendable, Hashable, Identifiable {
    /// The lesson.
    public let lesson: Lesson
    /// The Claude call that wrote it, or nil if Claude did not write it.
    public let generation: Generation?
    /// The exercises, by position.
    public let exercises: [ExerciseDetail]
    /// The score, derived from the attempts.
    public let score: LessonScore

    /// The lesson's identity.
    public var id: LessonID { lesson.id }

    /// Creates a lesson detail and derives its score.
    public init(lesson: Lesson, generation: Generation?, exercises: [ExerciseDetail]) {
        self.lesson = lesson
        self.generation = generation
        self.exercises = exercises
        self.score = LessonScore(exercises: exercises.map { ($0.id, $0.attempts) })
    }
}

/// One row of a lesson list.
public struct LessonSummary: Sendable, Hashable, Identifiable {
    /// The lesson's identity.
    public let id: LessonID
    /// The lesson's title.
    public let title: String
    /// A short label such as "Past tense".
    public let topic: String
    /// How far the lesson has progressed.
    public let state: LessonState
    /// When the lesson was saved.
    public let createdAt: Date
    /// When the lesson was finished, if it was.
    public let completedAt: Date?
    /// The score, derived from the attempts.
    public let score: LessonScore

    /// Creates a lesson summary value.
    public init(
        id: LessonID, title: String, topic: String, state: LessonState, createdAt: Date, completedAt: Date?,
        score: LessonScore
    ) {
        self.id = id
        self.title = title
        self.topic = topic
        self.state = state
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.score = score
    }
}
