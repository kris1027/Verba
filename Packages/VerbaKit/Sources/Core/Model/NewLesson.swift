import Foundation

/// One part of an exercise to save. Its order in the array becomes its source position.
public struct NewExercisePart: Sendable, Hashable {
    /// The new part's identity.
    public let id: ExercisePartID
    /// The part's text.
    public let text: String
    /// For `choice`, a right option; for `fillBlank` and `translate`, an accepted answer.
    public let isCorrect: Bool?
    /// For `reorder`, where this token belongs.
    public let correctPosition: Int?
    /// For `match`, the key this part shares with its pair.
    public let matchKey: String?

    /// Creates a part to save.
    public init(
        id: ExercisePartID = ExercisePartID(), text: String, isCorrect: Bool? = nil, correctPosition: Int? = nil,
        matchKey: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isCorrect = isCorrect
        self.correctPosition = correctPosition
        self.matchKey = matchKey
    }
}

/// One exercise to save. Its order in the array becomes its position in the lesson.
public struct NewExercise: Sendable, Hashable {
    /// The new exercise's identity.
    public let id: ExerciseID
    /// The kind of exercise.
    public let kind: ExerciseKind
    /// What the learner sees.
    public let prompt: String
    /// Why the answer is right, shown after answering.
    public let explanation: String?
    /// Its parts, in the order Claude wrote them.
    public let parts: [NewExercisePart]

    /// Creates an exercise to save. `NewLesson` checks its parts against the rules of its kind.
    public init(
        id: ExerciseID = ExerciseID(), kind: ExerciseKind, prompt: String, explanation: String? = nil,
        parts: [NewExercisePart]
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.explanation = explanation
        self.parts = parts
    }

    /// The reason the parts break the rules of this kind, or nil when they fit.
    fileprivate var ruleViolation: String? {
        switch kind {
        case .choice:
            guard (2...6).contains(parts.count) else { return "A choice exercise needs 2 to 6 options." }
            guard parts.contains(where: { $0.isCorrect == true }) else { return "No option is marked correct." }
        case .fillBlank, .translate:
            guard !parts.isEmpty else { return "The exercise needs at least one accepted answer." }
            guard parts.allSatisfy({ $0.isCorrect == true }) else { return "Every accepted answer must be correct." }
        case .reorder:
            guard parts.count >= 2 else { return "A reorder exercise needs at least 2 tokens." }
            let positions = parts.compactMap(\.correctPosition)
            guard positions.count == parts.count, Set(positions).count == parts.count else {
                return "Every token needs its own correct position."
            }
        case .match:
            guard !parts.isEmpty, parts.count.isMultiple(of: 2) else { return "A match needs an even number of parts." }
            let keys = Dictionary(grouping: parts, by: \.matchKey)
            guard keys[nil] == nil, keys.values.allSatisfy({ $0.count == 2 }) else {
                return "Every match key must be used exactly twice."
            }
        }
        return nil
    }
}

/// A complete lesson to save, checked against the rules for each exercise kind.
public struct NewLesson: Sendable, Hashable {
    /// The new lesson's identity.
    public let id: LessonID
    /// The course it belongs to.
    public let courseID: CourseID
    /// What the lesson is for.
    public let kind: LessonKind
    /// The lesson's title.
    public let title: String
    /// A short label such as "Past tense".
    public let topic: String
    /// The explain part, as Markdown in the learner's native language.
    public let explanation: String
    /// The exercises, in lesson order.
    public let exercises: [NewExercise]

    /// Creates a lesson to save.
    /// - Throws: `ValidationError.emptyLesson` for no exercises, or `.invalidExercise` when a part rule fails.
    public init(
        id: LessonID = LessonID(), courseID: CourseID, kind: LessonKind = .regular, title: String, topic: String,
        explanation: String, exercises: [NewExercise]
    ) throws(ValidationError) {
        self.init(
            unchecked: id, courseID: courseID, kind: kind, title: title, topic: topic, explanation: explanation,
            exercises: exercises)
        try validate()
    }

    /// Skips validation. For tests only, to inject a lesson only the database can reject.
    init(
        unchecked id: LessonID, courseID: CourseID, kind: LessonKind, title: String, topic: String, explanation: String,
        exercises: [NewExercise]
    ) {
        self.id = id
        self.courseID = courseID
        self.kind = kind
        self.title = title
        self.topic = topic
        self.explanation = explanation
        self.exercises = exercises
    }

    /// Checks the lesson has exercises and that every exercise's parts fit its kind.
    /// - Throws: `ValidationError.emptyLesson` or `.invalidExercise`.
    public func validate() throws(ValidationError) {
        guard !exercises.isEmpty else { throw .emptyLesson }
        for (position, exercise) in exercises.enumerated() {
            if let reason = exercise.ruleViolation {
                throw .invalidExercise(position: position, reason: reason)
            }
        }
    }
}
