import Foundation

// swiftlint:disable type_name
/// A typed identifier, so a `LessonID` can never be passed where an `ExerciseID` is expected.
public struct ID<Entity>: Sendable, Hashable, Codable {
    /// The underlying UUID.
    public let rawValue: UUID

    /// Creates an identifier from an existing UUID, or a new one when none is given.
    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    /// Decodes the identifier as a bare UUID.
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UUID.self)
    }

    /// Encodes the identifier as a bare UUID.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// swiftlint:enable type_name

/// Identifies a `Learner`.
public typealias LearnerID = ID<Learner>
/// Identifies a `Course`.
public typealias CourseID = ID<Course>
/// Identifies a `Lesson`.
public typealias LessonID = ID<Lesson>
/// Identifies an `Exercise`.
public typealias ExerciseID = ID<Exercise>
/// Identifies an `ExercisePart`.
public typealias ExercisePartID = ID<ExercisePart>
/// Identifies an `Attempt`.
public typealias AttemptID = ID<Attempt>
/// Identifies a `Generation`.
public typealias GenerationID = ID<Generation>
