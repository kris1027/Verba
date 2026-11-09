import Foundation

/// The kinds of exercise a lesson can hold.
public enum ExerciseKind: String, Sendable, Hashable, Codable, CaseIterable {
    /// Pick the right option.
    case choice
    /// Type the missing word.
    case fillBlank
    /// Translate a sentence.
    case translate
    /// Put tokens in the right order.
    case reorder
    /// Pair parts that belong together.
    case match

    /// Whether the learner sees this kind's parts, so the app must shuffle and save their order.
    public var displaysParts: Bool {
        switch self {
        case .choice, .reorder, .match: true
        case .fillBlank, .translate: false
        }
    }
}

/// One exercise in a lesson.
public struct Exercise: Sendable, Hashable, Identifiable {
    /// The exercise's identity.
    public let id: ExerciseID
    /// The lesson it belongs to.
    public let lessonID: LessonID
    /// Its order in the lesson, from 0.
    public let position: Int
    /// The kind of exercise.
    public let kind: ExerciseKind
    /// What the learner sees.
    public let prompt: String
    /// Why the answer is right, shown after answering.
    public let explanation: String?

    /// Creates an exercise value.
    public init(
        id: ExerciseID, lessonID: LessonID, position: Int, kind: ExerciseKind, prompt: String, explanation: String?
    ) {
        self.id = id
        self.lessonID = lessonID
        self.position = position
        self.kind = kind
        self.prompt = prompt
        self.explanation = explanation
    }
}

/// One option, token, pair side, or accepted answer of an exercise.
public struct ExercisePart: Sendable, Hashable, Identifiable {
    /// The part's identity.
    public let id: ExercisePartID
    /// The exercise it belongs to.
    public let exerciseID: ExerciseID
    /// The order Claude wrote it in, from 0. Never used as the display order.
    public let sourcePosition: Int
    /// The part's text.
    public let text: String
    /// The app's saved shuffle, from 0, or nil until shown.
    public let displayPosition: Int?
    /// For `choice`, a right option; for `fillBlank` and `translate`, an accepted answer.
    public let isCorrect: Bool?
    /// For `reorder`, where this token belongs.
    public let correctPosition: Int?
    /// For `match`, the key this part shares with its pair.
    public let matchKey: String?

    /// Creates an exercise part value.
    public init(
        id: ExercisePartID, exerciseID: ExerciseID, sourcePosition: Int, text: String, displayPosition: Int?,
        isCorrect: Bool?, correctPosition: Int?, matchKey: String?
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.sourcePosition = sourcePosition
        self.text = text
        self.displayPosition = displayPosition
        self.isCorrect = isCorrect
        self.correctPosition = correctPosition
        self.matchKey = matchKey
    }
}
