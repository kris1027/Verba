import Foundation

/// What to ask Claude for when writing a lesson.
public struct LessonRequest: Sendable, Hashable {
    /// The longest topic hint, in characters.
    public static let topicHintLimit = 200

    /// The course the lesson belongs to.
    public let courseID: CourseID
    /// The language every explanation and instruction is written in.
    public let nativeLanguage: LanguageTag
    /// The language being taught.
    public let targetLanguage: LanguageTag
    /// What you asked to learn about, trimmed, or nil to let Claude choose.
    public let topicHint: String?

    /// Creates a request. The hint is trimmed, and an empty hint becomes nil.
    /// - Throws: `ValidationError.invalidTopicHint` for a hint over 200 characters or with a line break.
    public init(
        courseID: CourseID, nativeLanguage: LanguageTag, targetLanguage: LanguageTag, topicHint: String? = nil
    ) throws(ValidationError) {
        let hint = topicHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hint, hint.count > Self.topicHintLimit || hint.contains(where: \.isNewline) {
            throw .invalidTopicHint
        }
        self.courseID = courseID
        self.nativeLanguage = nativeLanguage
        self.targetLanguage = targetLanguage
        self.topicHint = hint?.isEmpty == false ? hint : nil
    }
}

/// A lesson Claude wrote, with the details of the call to save beside it.
public struct GeneratedLesson: Sendable, Hashable {
    /// The lesson, already checked by `NewLesson.validate()`.
    public let lesson: NewLesson
    /// The call that produced it.
    public let generation: NewGeneration

    /// Creates a generated lesson.
    public init(lesson: NewLesson, generation: NewGeneration) {
        self.lesson = lesson
        self.generation = generation
    }
}
