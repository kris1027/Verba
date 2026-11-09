import Core
import Foundation
import GRDB

extension ID {
    /// How ids are stored: a lowercase UUID string.
    var text: String { rawValue.uuidString.lowercased() }

    init(text: String) throws {
        guard let uuid = UUID(uuidString: text) else {
            throw StoreError.unavailable(reason: "A saved identifier is damaged.")
        }
        self.init(uuid)
    }
}

extension Date {
    /// Stored dates have millisecond precision, so every date is rounded before it is stored and returned.
    var roundedToMillisecond: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1000).rounded() / 1000)
    }
}

/// Turns a stored open set value into its enum. An unknown value is an error, never a crash.
private func decoded<Value: RawRepresentable>(_ raw: String) throws -> Value where Value.RawValue == String {
    guard let value = Value(rawValue: raw) else {
        Log.store.error("Unrecognized saved value: \(raw, privacy: .private)")
        throw StoreError.unavailable(reason: "A saved value isn't recognized.")
    }
    return value
}

struct LearnerRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "learner"

    var id: String
    var displayName: String?
    var createdAt: Date

    func toCore() throws -> Learner {
        Learner(id: try LearnerID(text: id), displayName: displayName, createdAt: createdAt.roundedToMillisecond)
    }
}

struct CourseRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "course"

    var id: String
    var learnerId: String
    var targetLanguage: String
    var nativeLanguage: String
    var createdAt: Date
    var archivedAt: Date?

    func toCore() throws -> Course {
        Course(
            id: try CourseID(text: id), learnerID: try LearnerID(text: learnerId),
            targetLanguage: try LanguageTag(targetLanguage), nativeLanguage: try LanguageTag(nativeLanguage),
            createdAt: createdAt.roundedToMillisecond, archivedAt: archivedAt?.roundedToMillisecond)
    }
}

struct GenerationRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "generation"

    var id: String
    var courseId: String
    var kind: String
    var model: String?
    var promptVersion: String
    var rawReply: String
    var durationMs: Int
    var createdAt: Date

    func toCore() throws -> Generation {
        Generation(
            id: try GenerationID(text: id), courseID: try CourseID(text: courseId), kind: try decoded(kind),
            model: model, promptVersion: promptVersion, rawReply: rawReply, durationMs: durationMs,
            createdAt: createdAt.roundedToMillisecond)
    }
}

struct LessonRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "lesson"

    var id: String
    var courseId: String
    var generationId: String?
    var kind: String
    var title: String
    var topic: String
    var explanation: String
    var state: String
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var archivedAt: Date?

    func toCore() throws -> Lesson {
        Lesson(
            id: try LessonID(text: id), courseID: try CourseID(text: courseId),
            generationID: try generationId.map { try GenerationID(text: $0) }, kind: try decoded(kind), title: title,
            topic: topic, explanation: explanation, state: try decoded(state),
            createdAt: createdAt.roundedToMillisecond, startedAt: startedAt?.roundedToMillisecond,
            completedAt: completedAt?.roundedToMillisecond, archivedAt: archivedAt?.roundedToMillisecond)
    }
}

struct ExerciseRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercise"

    var id: String
    var lessonId: String
    var position: Int
    var kind: String
    var prompt: String
    var explanation: String?

    func toCore() throws -> Exercise {
        Exercise(
            id: try ExerciseID(text: id), lessonID: try LessonID(text: lessonId), position: position,
            kind: try decoded(kind), prompt: prompt, explanation: explanation)
    }
}

struct ExercisePartRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercisePart"

    var id: String
    var exerciseId: String
    var sourcePosition: Int
    var text: String
    var displayPosition: Int?
    var isCorrect: Bool?
    var correctPosition: Int?
    var matchKey: String?

    func toCore() throws -> ExercisePart {
        ExercisePart(
            id: try ExercisePartID(text: id), exerciseID: try ExerciseID(text: exerciseId),
            sourcePosition: sourcePosition, text: text, displayPosition: displayPosition, isCorrect: isCorrect,
            correctPosition: correctPosition, matchKey: matchKey)
    }
}

struct AttemptRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "attempt"

    var id: String
    var exerciseId: String
    var attemptNumber: Int
    /// GRDB stores this as JSON text.
    var response: AttemptResponse
    var grade: String
    var feedback: String
    var gradedBy: String
    var answeredAt: Date

    func toCore() throws -> Attempt {
        Attempt(
            id: try AttemptID(text: id), exerciseID: try ExerciseID(text: exerciseId), attemptNumber: attemptNumber,
            response: response, grade: try decoded(grade), feedback: feedback, gradedBy: try decoded(gradedBy),
            answeredAt: answeredAt.roundedToMillisecond)
    }
}

/// A row that is hidden from lists rather than deleted.
protocol ArchivableRow: FetchableRecord, PersistableRecord, SendableMetatype {
    var archivedAt: Date? { get set }
}

extension CourseRow: ArchivableRow {}
extension LessonRow: ArchivableRow {}

// MARK: Mapping new Core values to rows

extension GenerationRow {
    init(new generation: NewGeneration, courseId: String, createdAt: Date) {
        self.init(
            id: generation.id.text, courseId: courseId, kind: generation.kind.rawValue, model: generation.model,
            promptVersion: generation.promptVersion, rawReply: generation.rawReply, durationMs: generation.durationMs,
            createdAt: createdAt)
    }
}

extension LessonRow {
    /// A new lesson starts out `ready`.
    init(new lesson: NewLesson, generationId: String, createdAt: Date) {
        self.init(
            id: lesson.id.text, courseId: lesson.courseID.text, generationId: generationId,
            kind: lesson.kind.rawValue, title: lesson.title, topic: lesson.topic, explanation: lesson.explanation,
            state: LessonState.ready.rawValue, createdAt: createdAt, startedAt: nil, completedAt: nil, archivedAt: nil)
    }
}

extension ExerciseRow {
    init(new exercise: NewExercise, lessonId: String, position: Int) {
        self.init(
            id: exercise.id.text, lessonId: lessonId, position: position, kind: exercise.kind.rawValue,
            prompt: exercise.prompt, explanation: exercise.explanation)
    }
}

extension ExercisePartRow {
    init(new part: NewExercisePart, exerciseId: String, sourcePosition: Int) {
        self.init(
            id: part.id.text, exerciseId: exerciseId, sourcePosition: sourcePosition, text: part.text,
            displayPosition: nil, isCorrect: part.isCorrect, correctPosition: part.correctPosition,
            matchKey: part.matchKey)
    }
}
