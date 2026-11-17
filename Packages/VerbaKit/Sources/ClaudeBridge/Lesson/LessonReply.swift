import Foundation

/// The shape of a `lesson-v1` reply, matching `lesson-v1.schema.json` field for field.
/// The kind is a private four case enum, so a kind outside the four (such as `translate`) fails to decode.
struct LessonReply: Codable, Sendable, Hashable {
    var title: String
    var topic: String
    var explanation: String
    var exercises: [Exercise]

    struct Exercise: Codable, Sendable, Hashable {
        var kind: Kind
        var prompt: String
        var explanation: String
        var choices: [Choice]?
        var answers: [String]?
        var tokens: [String]?
        var pairs: [Pair]?
    }

    enum Kind: String, Codable, Sendable, Hashable {
        case choice, fillBlank, reorder, match
    }

    struct Choice: Codable, Sendable, Hashable {
        var text: String
        var isCorrect: Bool
    }

    struct Pair: Codable, Sendable, Hashable {
        var left: String
        var right: String
    }

    /// The limits the mapper enforces itself, because the CLI's schema check is not relied on for them.
    /// The schema file carries the same numbers (a test keeps them in step).
    enum Limits {
        static let title = 80
        static let topic = 40
        static let explanation = 3000
        static let prompt = 500
        static let exerciseExplanation = 1000
        static let part = 200
        static let exercises = 4...6
        static let choices = 3...4
    }
}
