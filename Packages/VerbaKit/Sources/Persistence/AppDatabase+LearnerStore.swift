import Core
import Foundation
import GRDB

extension AppDatabase: LearnerStore {
    /// Returns the one learner, creating it on the first call.
    public func loadOrCreateLearner() async throws(StoreError) -> Learner {
        try await write { db, now in try Self.loadOrInsertLearner(db, now: now).toCore() }
    }

    /// Sets the learner's name. The name is trimmed, and an empty name becomes nil.
    public func setDisplayName(_ name: String?) async throws(StoreError) -> Learner {
        try await write { db, _ in
            guard var row = try Self.firstLearner(db) else { throw StoreError.notFound }
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            row.displayName = trimmed?.isEmpty == true ? nil : trimmed
            try row.update(db)
            return try row.toCore()
        }
    }

    /// Adds a course for a language, creating the learner first if needed.
    public func addCourse(target: LanguageTag, native: LanguageTag) async throws(StoreError) -> Course {
        try await write { db, now in
            try Course.validateLanguages(target: target, native: native)
            let learner = try Self.loadOrInsertLearner(db, now: now)
            let row = CourseRow(
                id: CourseID().text, learnerId: learner.id, targetLanguage: target.rawValue,
                nativeLanguage: native.rawValue, createdAt: now, archivedAt: nil)
            do {
                try row.insert(db)
            } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE {
                // The id is freshly generated, so only the one course per language index can reject this row.
                throw StoreError.duplicateCourse
            }
            return try row.toCore()
        }
    }

    /// The learner's courses, oldest first.
    public func courses(includeArchived: Bool) async throws(StoreError) -> [Course] {
        try await read { db in try Self.fetchCourses(db, includeArchived: includeArchived) }
    }

    /// The unarchived courses now, then again after every change. Finishes on a database error.
    public func observeCourses() async -> AsyncStream<[Course]> {
        liveStream { db in try Self.fetchCourses(db, includeArchived: false) }
    }

    /// Hides a course from lists. Does nothing if it is already archived.
    public func archiveCourse(_ id: CourseID) async throws(StoreError) {
        try await write { db, now in
            guard var row = try CourseRow.fetchOne(db, key: id.text) else { throw StoreError.notFound }
            guard row.archivedAt == nil else { return }
            row.archivedAt = now
            try row.update(db)
        }
    }

    /// Brings an archived course back. Does nothing if it is not archived.
    public func unarchiveCourse(_ id: CourseID) async throws(StoreError) -> Course {
        try await write { db, _ in
            guard var row = try CourseRow.fetchOne(db, key: id.text) else { throw StoreError.notFound }
            if row.archivedAt != nil {
                row.archivedAt = nil
                try row.update(db)
            }
            return try row.toCore()
        }
    }

    private static func firstLearner(_ db: Database) throws -> LearnerRow? {
        try LearnerRow.fetchOne(db, sql: "SELECT * FROM learner ORDER BY createdAt, rowid LIMIT 1")
    }

    private static func loadOrInsertLearner(_ db: Database, now: Date) throws -> LearnerRow {
        if let existing = try firstLearner(db) {
            return existing
        }
        let row = LearnerRow(id: LearnerID().text, displayName: nil, createdAt: now)
        try row.insert(db)
        return row
    }

    private static func fetchCourses(_ db: Database, includeArchived: Bool) throws -> [Course] {
        let filter = includeArchived ? "" : "WHERE archivedAt IS NULL"
        return try CourseRow.fetchAll(db, sql: "SELECT * FROM course \(filter) ORDER BY createdAt, rowid")
            .map { try $0.toCore() }
    }
}
