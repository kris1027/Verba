import Core
import Foundation

/// Why a reply could not be used (AC-8). `reason` goes to the private log and to `invalidReply`.
enum ReplyProblem: Error, Sendable, Hashable {
    /// The result held no `structured_output`.
    case noStructuredOutput
    /// `structured_output` does not decode into the reply type; the detail is the decoder's message.
    case doesNotDecode(detail: String)
    /// The lesson has fewer than 4 or more than 6 exercises.
    case wrongExerciseCount(Int)
    /// An exercise lacks the field its kind needs.
    case missingField(_ field: String, exercise: Int)
    /// A required string is empty after trimming.
    case emptyText(field: String)
    /// A string is longer than the schema allows.
    case textTooLong(field: String, limit: Int)
    /// A choice exercise has other than 3 or 4 options.
    case wrongOptionCount(_ count: Int, exercise: Int)
    /// A choice exercise has other than exactly one correct option.
    case notOneCorrectOption(exercise: Int)
    /// The lesson breaks a `NewLesson` rule.
    case failsValidation(ValidationError)

    /// A short English description for the private log.
    var reason: String {
        switch self {
        case .noStructuredOutput: "no structured_output"
        case .doesNotDecode(let detail): "does not decode: \(detail)"
        case .wrongExerciseCount(let count): "has \(count) exercises, not 4 to 6"
        case .missingField(let field, let exercise): "exercise \(exercise) has no \(field)"
        case .emptyText(let field): "\(field) is empty"
        case .textTooLong(let field, let limit): "\(field) is over \(limit) characters"
        case .wrongOptionCount(let count, let exercise): "exercise \(exercise) has \(count) options, not 3 or 4"
        case .notOneCorrectOption(let exercise): "exercise \(exercise) does not have exactly one correct option"
        case .failsValidation(let error): "fails validation: \(error.localizedDescription)"
        }
    }
}

extension ReplyProblem {
    /// Why the test reply cannot be used, or nil when it holds a `reply` string.
    init?(testReply result: CLIResult) {
        struct Body: Decodable { let reply: String }
        guard let structured = result.structuredOutput else {
            self = .noStructuredOutput
            return
        }
        do {
            _ = try structured.decode(Body.self)
            return nil
        } catch {
            self = .doesNotDecode(detail: String(describing: error))
        }
    }
}
