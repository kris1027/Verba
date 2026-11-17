import Core
import Foundation

/// Builds the `lesson-v1` prompt for one request.
enum LessonPrompt {
    static let version = "lesson-v1"

    static func make(for request: LessonRequest) throws(ClaudeError) -> Prompt {
        try Prompt.load(
            version,
            values: [
                "nativeLanguage": languageName(request.nativeLanguage),
                "targetLanguage": languageName(request.targetLanguage),
                "topicLine": topicLine(request.topicHint),
            ])
    }

    /// The English name plus the tag, such as `Polish (pl)`, or the tag alone when it has no name.
    static func languageName(_ tag: LanguageTag) -> String {
        guard let name = Locale(identifier: "en").localizedString(forIdentifier: tag.rawValue) else {
            return tag.rawValue
        }
        return "\(name) (\(tag.rawValue))"
    }

    /// The hint framed as a topic, with `"` turned into `'` so it stays inside its quotes.
    static func topicLine(_ hint: String?) -> String {
        guard let hint else { return "Choose a useful topic for a beginner." }
        return "Topic requested by the learner: \"\(hint.replacing("\"", with: "'"))\""
    }
}
