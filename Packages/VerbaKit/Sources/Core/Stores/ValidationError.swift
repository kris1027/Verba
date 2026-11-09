import Foundation

/// A value broke one of the domain's rules.
public enum ValidationError: Error, Sendable, Hashable, LocalizedError {
    /// The string is not a valid language tag.
    case invalidLanguageTag
    /// The target language is the same as the native language.
    case sameLanguage
    /// The lesson has no exercises.
    case emptyLesson
    /// An exercise's parts break the rules of its kind.
    case invalidExercise(position: Int, reason: String)
    /// A display order is not exactly the exercise's displayed parts.
    case invalidDisplayOrder
    /// A response does not fit the exercise.
    case invalidResponse

    /// A message to show the learner.
    public var errorDescription: String? {
        switch self {
        case .invalidLanguageTag: "That isn't a language Verba recognizes."
        case .sameLanguage: "Pick a language to learn that is different from your native language."
        case .emptyLesson: "This lesson came back with no exercises."
        case .invalidExercise(let position, let reason): "Exercise \(position + 1) can't be used. \(reason)"
        case .invalidDisplayOrder: "The order of this exercise's options isn't valid."
        case .invalidResponse: "That answer doesn't fit this exercise."
        }
    }
}
