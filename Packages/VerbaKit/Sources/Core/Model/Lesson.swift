import Foundation

/// What a lesson is for. New kinds can appear without a schema change.
public enum LessonKind: String, Sendable, Hashable, Codable {
    /// A normal lesson.
    case regular
    /// A placement check (Slice 2).
    case placement
}

/// How far a lesson has progressed. It only ever moves forward.
public enum LessonState: String, Sendable, Hashable, Codable {
    /// Saved from Claude's reply, nothing answered yet.
    case ready
    /// At least one exercise has an attempt.
    case inProgress
    /// Every exercise has at least one attempt.
    case completed

    /// The state after an attempt is saved.
    /// - Parameters:
    ///   - exerciseCount: The number of exercises in the lesson.
    ///   - answeredCount: The exercises with at least one attempt, the new attempt included.
    /// - Returns: The new state, which is never earlier than this one.
    public func advanced(exerciseCount: Int, answeredCount: Int) -> LessonState {
        let next: LessonState
        if answeredCount == exerciseCount {
            next = .completed
        } else if answeredCount > 0 {
            next = .inProgress
        } else {
            next = self
        }
        return next.rank > rank ? next : self
    }

    private var rank: Int {
        switch self {
        case .ready: 0
        case .inProgress: 1
        case .completed: 2
        }
    }
}

/// A saved lesson: an explanation followed by exercises.
public struct Lesson: Sendable, Hashable, Identifiable {
    /// The lesson's identity.
    public let id: LessonID
    /// The course the lesson belongs to.
    public let courseID: CourseID
    /// The Claude call that wrote the lesson, or nil if Claude did not write it.
    public let generationID: GenerationID?
    /// What the lesson is for.
    public let kind: LessonKind
    /// The lesson's title.
    public let title: String
    /// A short label such as "Past tense".
    public let topic: String
    /// The explain part, as Markdown in the learner's native language.
    public let explanation: String
    /// How far the lesson has progressed.
    public let state: LessonState
    /// When the lesson was saved.
    public let createdAt: Date
    /// The time of the first attempt, or nil while `ready`.
    public let startedAt: Date?
    /// The time of the attempt that finished the lesson, or nil until `completed`.
    public let completedAt: Date?
    /// When the lesson was archived, or nil while it is active.
    public let archivedAt: Date?

    /// Creates a lesson value.
    public init(
        id: LessonID, courseID: CourseID, generationID: GenerationID?, kind: LessonKind, title: String, topic: String,
        explanation: String, state: LessonState, createdAt: Date, startedAt: Date?, completedAt: Date?,
        archivedAt: Date?
    ) {
        self.id = id
        self.courseID = courseID
        self.generationID = generationID
        self.kind = kind
        self.title = title
        self.topic = topic
        self.explanation = explanation
        self.state = state
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.archivedAt = archivedAt
    }
}
