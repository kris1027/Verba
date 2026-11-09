import Foundation

/// What a saved Claude call produced. New kinds can appear without a schema change.
public enum GenerationKind: String, Sendable, Hashable, Codable {
    /// A lesson.
    case lesson
    /// A grade for an answer.
    case grade
    /// A chat reply.
    case chatTurn
    /// A placement check.
    case placement
}

/// One Claude call whose reply is kept.
public struct Generation: Sendable, Hashable, Identifiable {
    /// The generation's identity.
    public let id: GenerationID
    /// The course it was made for.
    public let courseID: CourseID
    /// What the call produced.
    public let kind: GenerationKind
    /// The model name the CLI reported, if any.
    public let model: String?
    /// The version of the prompt that was sent.
    public let promptVersion: String
    /// Claude's reply exactly as received. Learner content.
    public let rawReply: String
    /// How long the call took, in milliseconds.
    public let durationMs: Int
    /// When the reply was saved.
    public let createdAt: Date

    /// Creates a generation value.
    public init(
        id: GenerationID, courseID: CourseID, kind: GenerationKind, model: String?, promptVersion: String,
        rawReply: String, durationMs: Int, createdAt: Date
    ) {
        self.id = id
        self.courseID = courseID
        self.kind = kind
        self.model = model
        self.promptVersion = promptVersion
        self.rawReply = rawReply
        self.durationMs = durationMs
        self.createdAt = createdAt
    }
}

/// The details of a Claude call to save alongside what it produced.
public struct NewGeneration: Sendable, Hashable {
    /// The new generation's identity.
    public let id: GenerationID
    /// What the call produced.
    public let kind: GenerationKind
    /// The model name the CLI reported, if any.
    public let model: String?
    /// The version of the prompt that was sent.
    public let promptVersion: String
    /// Claude's reply exactly as received.
    public let rawReply: String
    /// How long the call took, in milliseconds.
    public let durationMs: Int

    /// Creates the details of a Claude call.
    public init(
        id: GenerationID = GenerationID(), kind: GenerationKind, model: String?, promptVersion: String,
        rawReply: String, durationMs: Int
    ) {
        self.id = id
        self.kind = kind
        self.model = model
        self.promptVersion = promptVersion
        self.rawReply = rawReply
        self.durationMs = durationMs
    }
}
