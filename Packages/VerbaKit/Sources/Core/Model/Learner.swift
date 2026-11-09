import Foundation

/// The one person using the app.
public struct Learner: Sendable, Hashable, Identifiable {
    /// The learner's identity.
    public let id: LearnerID
    /// An optional name Claude may address the learner by.
    public let displayName: String?
    /// When the learner was created.
    public let createdAt: Date

    /// Creates a learner value.
    public init(id: LearnerID, displayName: String?, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

/// One language being learned, with the native language it is taught in.
public struct Course: Sendable, Hashable, Identifiable {
    /// The course's identity.
    public let id: CourseID
    /// The learner who owns the course.
    public let learnerID: LearnerID
    /// The language being learned.
    public let targetLanguage: LanguageTag
    /// The language lessons and explanations are written in.
    public let nativeLanguage: LanguageTag
    /// When the course was created.
    public let createdAt: Date
    /// When the course was archived, or nil while it is active.
    public let archivedAt: Date?

    /// Creates a course value.
    public init(
        id: CourseID, learnerID: LearnerID, targetLanguage: LanguageTag, nativeLanguage: LanguageTag, createdAt: Date,
        archivedAt: Date?
    ) {
        self.id = id
        self.learnerID = learnerID
        self.targetLanguage = targetLanguage
        self.nativeLanguage = nativeLanguage
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    /// Checks the rule every new course follows: you cannot learn a language through itself.
    /// - Throws: `ValidationError.sameLanguage` when both languages are the same.
    public static func validateLanguages(target: LanguageTag, native: LanguageTag) throws(ValidationError) {
        guard target != native else { throw .sameLanguage }
    }
}
