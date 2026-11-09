import Core
import Foundation
import GRDB

extension AppDatabase: LessonStore {
    /// Saves a generated lesson and the Claude call behind it, all or nothing, in the `ready` state.
    public func saveGeneratedLesson(
        _ lesson: NewLesson, generation: NewGeneration
    ) async throws(StoreError) -> LessonDetail {
        try await write { db, now in
            try lesson.validate()
            guard let course = try CourseRow.fetchOne(db, key: lesson.courseID.text) else {
                throw StoreError.notFound
            }
            guard course.archivedAt == nil else { throw StoreError.archived }
            try Self.insert(generation, courseId: course.id, db, now: now)
            try Self.insert(lesson, generationId: generation.id.text, db, now: now)
            guard let detail = try Self.fetchDetail(db, id: lesson.id.text) else { throw StoreError.notFound }
            return detail
        }
    }

    /// Reads a lesson by id, archived or not.
    public func lesson(_ id: LessonID) async throws(StoreError) -> LessonDetail {
        try await read { db in
            guard let detail = try Self.fetchDetail(db, id: id.text) else { throw StoreError.notFound }
            return detail
        }
    }

    /// The lesson now, then again after every change. Finishes at once if the id is missing, or on a database error.
    public func observeLesson(_ id: LessonID) async -> AsyncStream<LessonDetail> {
        liveStream { db in try Self.fetchDetail(db, id: id.text) }
    }

    /// The course's unarchived lessons, newest first, then again after every change. Finishes on a database error.
    public func observeLessons(course: CourseID) async -> AsyncStream<[LessonSummary]> {
        liveStream { db in try Self.fetchSummaries(db, courseId: course.text) }
    }

    /// Saves an exercise's shuffled option order, once. A second save throws and keeps the stored order.
    public func saveDisplayOrder(_ order: [ExercisePartID], for exercise: ExerciseID) async throws(StoreError) {
        try await write { db, _ in
            guard let row = try ExerciseRow.fetchOne(db, key: exercise.text) else { throw StoreError.notFound }
            let parts = try Self.fetchParts(db, exerciseId: row.id)
            guard parts.allSatisfy({ $0.displayPosition == nil }) else { throw StoreError.displayOrderAlreadySet }
            try OptionShuffler.validate(order: order, kind: try row.toCore().kind, parts: parts)
            for (position, partID) in order.enumerated() {
                try db.execute(
                    sql: "UPDATE exercisePart SET displayPosition = ? WHERE id = ?",
                    arguments: [position, partID.text])
            }
        }
    }

    /// Saves an answer, numbers it, and moves the lesson forward.
    public func recordAttempt(_ attempt: NewAttempt) async throws(StoreError) -> Attempt {
        try await write { db, now in
            guard let exercise = try ExerciseRow.fetchOne(db, key: attempt.exerciseID.text),
                var lesson = try LessonRow.fetchOne(db, key: exercise.lessonId)
            else { throw StoreError.notFound }
            guard lesson.archivedAt == nil else { throw StoreError.archived }

            let parts = try Self.fetchParts(db, exerciseId: exercise.id)
            try Grader.validate(attempt.response, kind: try exercise.toCore().kind, parts: parts)

            let lastNumber = try Int.fetchOne(
                db, sql: "SELECT MAX(attemptNumber) FROM attempt WHERE exerciseId = ?", arguments: [exercise.id])
            let row = AttemptRow(
                id: attempt.id.text, exerciseId: exercise.id, attemptNumber: (lastNumber ?? 0) + 1,
                response: attempt.response, grade: attempt.grade.rawValue, feedback: attempt.feedback,
                gradedBy: attempt.gradedBy.rawValue, answeredAt: now)
            try row.insert(db)
            try Self.advance(&lesson, db, answeredAt: now)
            return try row.toCore()
        }
    }

    /// Hides a lesson from lists. Does nothing if it is already archived.
    public func archiveLesson(_ id: LessonID) async throws(StoreError) {
        try await write { db, now in
            guard var row = try LessonRow.fetchOne(db, key: id.text) else { throw StoreError.notFound }
            guard row.archivedAt == nil else { return }
            row.archivedAt = now
            try row.update(db)
        }
    }

    // MARK: Writes

    private static func insert(_ generation: NewGeneration, courseId: String, _ db: Database, now: Date) throws {
        try GenerationRow(
            id: generation.id.text, courseId: courseId, kind: generation.kind.rawValue, model: generation.model,
            promptVersion: generation.promptVersion, rawReply: generation.rawReply, durationMs: generation.durationMs,
            createdAt: now
        ).insert(db)
    }

    private static func insert(_ lesson: NewLesson, generationId: String, _ db: Database, now: Date) throws {
        try LessonRow(
            id: lesson.id.text, courseId: lesson.courseID.text, generationId: generationId,
            kind: lesson.kind.rawValue, title: lesson.title, topic: lesson.topic, explanation: lesson.explanation,
            state: LessonState.ready.rawValue, createdAt: now, startedAt: nil, completedAt: nil, archivedAt: nil
        ).insert(db)

        for (position, exercise) in lesson.exercises.enumerated() {
            try ExerciseRow(
                id: exercise.id.text, lessonId: lesson.id.text, position: position, kind: exercise.kind.rawValue,
                prompt: exercise.prompt, explanation: exercise.explanation
            ).insert(db)

            for (sourcePosition, part) in exercise.parts.enumerated() {
                try ExercisePartRow(
                    id: part.id.text, exerciseId: exercise.id.text, sourcePosition: sourcePosition, text: part.text,
                    displayPosition: nil, isCorrect: part.isCorrect, correctPosition: part.correctPosition,
                    matchKey: part.matchKey
                ).insert(db)
            }
        }
    }

    /// Moves the lesson forward after an attempt. Both timestamps copy the attempt's time.
    private static func advance(_ lesson: inout LessonRow, _ db: Database, answeredAt: Date) throws {
        let exerciseCount = try Int.fetchOne(
            db, sql: "SELECT COUNT(*) FROM exercise WHERE lessonId = ?", arguments: [lesson.id])
        let answeredCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(DISTINCT attempt.exerciseId) FROM attempt
                JOIN exercise ON exercise.id = attempt.exerciseId
                WHERE exercise.lessonId = ?
                """,
            arguments: [lesson.id])

        let current = try lesson.toCore().state
        let next = current.advanced(exerciseCount: exerciseCount ?? 0, answeredCount: answeredCount ?? 0)
        guard next != current else { return }
        lesson.state = next.rawValue
        lesson.startedAt = lesson.startedAt ?? answeredAt
        if next == .completed {
            lesson.completedAt = answeredAt
        }
        try lesson.update(db)
    }

    // MARK: Reads

    private static func fetchParts(_ db: Database, exerciseId: String) throws -> [ExercisePart] {
        try ExercisePartRow.fetchAll(
            db,
            sql: "SELECT * FROM exercisePart WHERE exerciseId = ? ORDER BY COALESCE(displayPosition, sourcePosition)",
            arguments: [exerciseId]
        ).map { try $0.toCore() }
    }

    private static func fetchDetail(_ db: Database, id: String) throws -> LessonDetail? {
        guard let lesson = try LessonRow.fetchOne(db, key: id) else { return nil }
        let generation = try lesson.generationId.flatMap { try GenerationRow.fetchOne(db, key: $0) }
        let exerciseRows = try ExerciseRow.fetchAll(
            db, sql: "SELECT * FROM exercise WHERE lessonId = ? ORDER BY position", arguments: [id])
        let exercises = try exerciseRows.map { row in
            let attempts = try AttemptRow.fetchAll(
                db, sql: "SELECT * FROM attempt WHERE exerciseId = ? ORDER BY attemptNumber", arguments: [row.id])
            return ExerciseDetail(
                exercise: try row.toCore(), parts: try fetchParts(db, exerciseId: row.id),
                attempts: try attempts.map { try $0.toCore() })
        }
        return LessonDetail(lesson: try lesson.toCore(), generation: try generation?.toCore(), exercises: exercises)
    }

    private static func fetchSummaries(_ db: Database, courseId: String) throws -> [LessonSummary] {
        let lessons = try LessonRow.fetchAll(
            db,
            sql: "SELECT * FROM lesson WHERE courseId = ? AND archivedAt IS NULL ORDER BY createdAt DESC, rowid DESC",
            arguments: [courseId])
        let exercises = try ExerciseRow.fetchAll(
            db,
            sql:
                "SELECT exercise.* FROM exercise JOIN lesson ON lesson.id = exercise.lessonId WHERE lesson.courseId = ?",
            arguments: [courseId])
        let attempts = try AttemptRow.fetchAll(
            db,
            sql: """
                SELECT attempt.* FROM attempt
                JOIN exercise ON exercise.id = attempt.exerciseId
                JOIN lesson ON lesson.id = exercise.lessonId
                WHERE lesson.courseId = ?
                """,
            arguments: [courseId])

        let attemptsByExercise = try Dictionary(grouping: attempts.map { try $0.toCore() }, by: \.exerciseID)
        let exercisesByLesson = Dictionary(grouping: exercises, by: \.lessonId)
        return try lessons.map { row in
            let scored = try (exercisesByLesson[row.id] ?? []).map { exercise in
                let id = try ExerciseID(text: exercise.id)
                return (id, attemptsByExercise[id] ?? [])
            }
            let lesson = try row.toCore()
            return LessonSummary(
                id: lesson.id, title: lesson.title, topic: lesson.topic, state: lesson.state,
                createdAt: lesson.createdAt, completedAt: lesson.completedAt, score: LessonScore(exercises: scored))
        }
    }
}
