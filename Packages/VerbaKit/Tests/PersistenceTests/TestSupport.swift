import Foundation
import GRDB

@testable import Core
@testable import Persistence

/// Runs a test against a fresh data folder that is removed afterwards.
func withTemporaryPaths(_ body: (AppPaths) async throws -> Void) async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "VerbaTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = AppPaths(root: root)
    try paths.prepareFolders()
    try await body(paths)
}

extension AppDatabase {
    static func open(_ paths: AppPaths) throws -> AppDatabase {
        try open(at: paths.database, backupsFolder: paths.backups)
    }

    /// Really closes the file, so a following open proves the data was on disk.
    func close() throws {
        try (writer as? DatabasePool)?.close()
    }
}

extension AppPaths {
    /// Creates a database file that has only the given migrations applied.
    func seedDatabase(upTo migration: String) throws {
        let pool = try DatabasePool(path: database.path(percentEncoded: false))
        try AppDatabase.migrator.migrate(pool, upTo: migration)
        try pool.close()
    }

    func backupNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: backups.path(percentEncoded: false)).sorted()
    }
}

enum Sample {
    static let generation = NewGeneration(
        kind: .lesson, model: "claude-test", promptVersion: "v1", rawReply: #"{"title":"raw"}"#, durationMs: 1200)

    /// One exercise of each kind.
    static func exercises() -> [NewExercise] {
        [
            NewExercise(
                kind: .choice, prompt: "Pick", explanation: "Because.",
                parts: [
                    NewExercisePart(text: "right", isCorrect: true), NewExercisePart(text: "no", isCorrect: false),
                    NewExercisePart(text: "nope", isCorrect: false),
                ]),
            NewExercise(kind: .fillBlank, prompt: "Fill", parts: [NewExercisePart(text: "word", isCorrect: true)]),
            NewExercise(kind: .translate, prompt: "Say", parts: [NewExercisePart(text: "hola", isCorrect: true)]),
            NewExercise(
                kind: .reorder, prompt: "Order",
                parts: [NewExercisePart(text: "b", correctPosition: 1), NewExercisePart(text: "a", correctPosition: 0)]),
            NewExercise(
                kind: .match, prompt: "Match",
                parts: [
                    NewExercisePart(text: "one", matchKey: "1"), NewExercisePart(text: "uno", matchKey: "1"),
                    NewExercisePart(text: "two", matchKey: "2"), NewExercisePart(text: "dos", matchKey: "2"),
                ]),
        ]
    }

    static func lesson(courseID: CourseID, exercises: [NewExercise] = exercises()) throws -> NewLesson {
        try NewLesson(
            courseID: courseID, title: "Greetings", topic: "Hello", explanation: "**Say** hello.", exercises: exercises)
    }

    static func oneChoiceExercise() -> [NewExercise] {
        [
            NewExercise(
                kind: .choice, prompt: "Pick",
                parts: [NewExercisePart(text: "yes", isCorrect: true), NewExercisePart(text: "no", isCorrect: false)])
        ]
    }

    static func answer(_ exercise: ExerciseDetail, grade: Grade = .correct) -> NewAttempt {
        NewAttempt(
            exerciseID: exercise.id, response: response(for: exercise), grade: grade, feedback: "Explained.",
            gradedBy: .app)
    }

    /// A response of the right shape for the exercise's kind.
    static func response(for exercise: ExerciseDetail) -> AttemptResponse {
        let ids = exercise.parts.map(\.id)
        switch exercise.exercise.kind {
        case .choice: return .choice(ids[0])
        case .fillBlank, .translate: return .text("answer")
        case .reorder: return .order(ids)
        case .match: return .pairs(stride(from: 0, to: ids.count, by: 2).map { [ids[$0], ids[$0 + 1]] })
        }
    }

    static func course(in store: AppDatabase) async throws -> Course {
        try await store.addCourse(target: LanguageTag("es"), native: LanguageTag("pl"))
    }

    static func savedLesson(in store: AppDatabase, exercises: [NewExercise] = exercises()) async throws -> LessonDetail
    {
        let course = try await course(in: store)
        return try await store.saveGeneratedLesson(
            lesson(courseID: course.id, exercises: exercises), generation: generation)
    }

    /// Waits until a live read delivers a value that passes the check. GRDB may merge writes, so counts are never asserted.
    static func firstValue<Value: Sendable>(
        from stream: AsyncStream<Value>, where check: (Value) -> Bool
    ) async -> Value? {
        for await value in stream where check(value) {
            return value
        }
        return nil
    }
}
