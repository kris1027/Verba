import Core
import Foundation
import GRDB
import Testing

@testable import Persistence

struct AppDatabaseTests {
    @Test func realPoolMigratesInWALMode() async throws {
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)

            #expect(FileManager.default.fileExists(atPath: paths.database.path(percentEncoded: false)))
            let journalMode = try await database.writer.read { db throws in
                try String.fetchOne(db, sql: "PRAGMA journal_mode")
            }
            #expect(journalMode == "wal")
        }
    }

    @Test func reopeningAnExistingFileKeepsItsHistory() async throws {
        try await withTemporaryPaths { paths in
            try AppDatabase.open(paths).close()
            let reopened = try AppDatabase.open(paths)

            let completed = try await reopened.writer.read { db throws in
                try AppDatabase.migrator.hasCompletedMigrations(db)
            }
            #expect(completed)
        }
    }

    @Test func inMemoryDatabaseUsesTheSameMigrations() throws {
        let database = try AppDatabase.inMemory()
        let applied = try database.writer.unsafeReentrantRead { db in
            try AppDatabase.migrator.appliedIdentifiers(db)
        }
        #expect(applied == ["v0_scaffold", "v1_core"])
    }

    @Test func storedDatesReadBackExactly() throws {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<50_000 {
            let seconds = Double.random(in: 1_700_000_000...2_200_000_000, using: &generator)
            let date = Date(timeIntervalSince1970: seconds).roundedToMillisecond
            let reread = Date.fromDatabaseValue(date.databaseValue)?.roundedToMillisecond
            #expect(reread == date)
        }
    }

    @Test func aDatabaseFailureNeverShowsTheEnginesTextToTheLearner() {
        let engineText = "no such table: exercisePart"
        let mapped = AppDatabase.mapError(DatabaseError(resultCode: .SQLITE_ERROR, message: engineText))

        guard case .unavailable = mapped else {
            Issue.record("Expected unavailable, got \(mapped)")
            return
        }
        #expect(mapped.errorDescription?.contains(engineText) == false)
    }
}

/// AC-1: `v1_core` creates exactly the designed schema.
struct SchemaTests {
    private struct ForeignKey {
        let table: String
        let column: String
        let parent: String

        init(_ table: String, _ column: String, _ parent: String) {
            self.table = table
            self.column = column
            self.parent = parent
        }
    }

    /// A PRAGMA doesn't reload a schema that changed since this connection last ran a statement, so run one first.
    private func refreshSchema(_ db: Database) throws {
        _ = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master")
    }

    private func migratedFromScaffold(_ paths: AppPaths) throws -> AppDatabase {
        try paths.seedDatabase(upTo: "v0_scaffold")
        return try AppDatabase.open(paths)
    }

    @Test func migratingFromScaffoldKeepsHistoryAndEnforcesForeignKeys() async throws {
        try await withTemporaryPaths { paths in
            let database = try migratedFromScaffold(paths)
            try await database.writer.read { db throws in
                #expect(try AppDatabase.migrator.appliedIdentifiers(db) == ["v0_scaffold", "v1_core"])
                #expect(try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1)
            }
        }
    }

    @Test func tablesAndColumnsMatchTheSpec() async throws {
        let expected: [String: [String]] = [
            "learner": ["id", "displayName", "createdAt"],
            "course": ["id", "learnerId", "targetLanguage", "nativeLanguage", "createdAt", "archivedAt"],
            "generation": ["id", "courseId", "kind", "model", "promptVersion", "rawReply", "durationMs", "createdAt"],
            "lesson": [
                "id", "courseId", "generationId", "kind", "title", "topic", "explanation", "state", "createdAt",
                "startedAt", "completedAt", "archivedAt",
            ],
            "exercise": ["id", "lessonId", "position", "kind", "prompt", "explanation"],
            "exercisePart": [
                "id", "exerciseId", "sourcePosition", "text", "displayPosition", "isCorrect", "correctPosition",
                "matchKey",
            ],
            "attempt": [
                "id", "exerciseId", "attemptNumber", "response", "grade", "feedback", "gradedBy", "answeredAt",
            ],
        ]
        try await withTemporaryPaths { paths in
            let database = try migratedFromScaffold(paths)
            try await database.writer.read { db throws in
                let tables = try String.fetchAll(
                    db,
                    sql: """
                        SELECT name FROM sqlite_master
                        WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                        """)
                #expect(Set(tables) == Set(expected.keys))
                for (table, columns) in expected {
                    #expect(try db.columns(in: table).map(\.name) == columns, "\(table)")
                }
            }
        }
    }

    @Test func foreignKeysRestrictDeletesAndAreIndexed() async throws {
        let foreignKeys: [ForeignKey] = [
            ForeignKey("course", "learnerId", "learner"), ForeignKey("generation", "courseId", "course"),
            ForeignKey("lesson", "courseId", "course"),
            ForeignKey("lesson", "generationId", "generation"), ForeignKey("exercise", "lessonId", "lesson"),
            ForeignKey("exercisePart", "exerciseId", "exercise"), ForeignKey("attempt", "exerciseId", "exercise"),
        ]
        try await withTemporaryPaths { paths in
            let database = try migratedFromScaffold(paths)
            try await database.writer.read { db throws in
                try refreshSchema(db)
                for key in foreignKeys {
                    let rows = try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(\(key.table))")
                    let row = rows.first { $0["from"] == key.column }
                    #expect(row?["table"] == key.parent, "\(key.table).\(key.column)")
                    #expect(row?["on_delete"] == "RESTRICT", "\(key.table).\(key.column)")
                    let isIndexed = try db.indexes(on: key.table).contains { $0.columns.first == key.column }
                    #expect(isIndexed, "\(key.table).\(key.column) needs an index")
                }
            }
        }
    }

    @Test func expectedUniqueIndexesExist() async throws {
        let unique: [(table: String, columns: [String])] = [
            ("course", ["learnerId", "targetLanguage"]), ("exercise", ["lessonId", "position"]),
            ("exercisePart", ["exerciseId", "sourcePosition"]), ("attempt", ["exerciseId", "attemptNumber"]),
            ("exercisePart", ["exerciseId", "displayPosition"]),
        ]
        try await withTemporaryPaths { paths in
            let database = try migratedFromScaffold(paths)
            try await database.writer.read { db throws in
                try refreshSchema(db)
                for key in unique {
                    let found = try db.indexes(on: key.table).contains { $0.isUnique && $0.columns == key.columns }
                    #expect(found, "\(key.table) \(key.columns)")
                }
                let partial = try String.fetchOne(
                    db, sql: "SELECT sql FROM sqlite_master WHERE name = 'exercisePart_on_exerciseId_displayPosition'")
                #expect(partial?.contains("WHERE displayPosition IS NOT NULL") == true)
            }
        }
    }

    @Test(arguments: [
        "INSERT INTO learner VALUES ('NOT-A-LOWERCASE-UUID', NULL, '2026-01-01 00:00:00.000')",
        """
        INSERT INTO lesson (id, courseId, kind, title, topic, explanation, state, createdAt)
        VALUES ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000002', 'regular', 't', 't', 'e',
        'inProgress', '2026-01-01 00:00:00.000')
        """,
        """
        INSERT INTO lesson (id, courseId, kind, title, topic, explanation, state, createdAt, startedAt)
        VALUES ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000002', 'regular', 't', 't', 'e',
        'done', '2026-01-01 00:00:00.000', '2026-01-01 00:00:00.000')
        """,
        """
        INSERT INTO lesson (id, courseId, kind, title, topic, explanation, state, createdAt, startedAt)
        VALUES ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000002', 'regular', 't', 't', 'e',
        'completed', '2026-01-01 00:00:00.000', '2026-01-01 00:00:00.000')
        """,
        """
        INSERT INTO course VALUES ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
        'pl', 'pl', '2026-01-01 00:00:00.000', NULL)
        """,
    ])
    func checksRejectBadRows(sql: String) async throws {
        let database = try AppDatabase.inMemory()
        try await database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO learner VALUES ('00000000-0000-0000-0000-000000000001', NULL, '2026-01-01 00:00:00.000');
                    INSERT INTO course VALUES ('00000000-0000-0000-0000-000000000002',
                    '00000000-0000-0000-0000-000000000001', 'es', 'pl', '2026-01-01 00:00:00.000', NULL);
                    """)
        }
        await #expect(throws: DatabaseError.self) {
            try await database.writer.write { db in try db.execute(sql: sql) }
        }
    }
}

/// AC-11 and AC-12: back up before migrating, and fail without losing data.
struct OpenAndBackupTests {
    @Test func aPendingMigrationMakesABackupOfTheOldFile() async throws {
        try await withTemporaryPaths { paths in
            try paths.seedDatabase(upTo: "v0_scaffold")
            _ = try AppDatabase.open(paths)

            let names = try paths.backupNames()
            #expect(names.count == 1)
            #expect(names[0].hasPrefix("verba-") && names[0].hasSuffix("Z.sqlite"))

            let backup = try DatabaseQueue(path: paths.backups.appending(path: names[0]).path(percentEncoded: false))
            let applied = try await backup.read { db in try AppDatabase.migrator.appliedIdentifiers(db) }
            #expect(applied == ["v0_scaffold"])
        }
    }

    @Test func aNewFileMakesNoBackup() async throws {
        try await withTemporaryPaths { paths in
            _ = try AppDatabase.open(paths)
            #expect(try paths.backupNames().isEmpty)
        }
    }

    @Test func aFileWithNothingPendingMakesNoBackup() async throws {
        try await withTemporaryPaths { paths in
            try AppDatabase.open(paths).close()
            _ = try AppDatabase.open(paths)
            #expect(try paths.backupNames().isEmpty)
        }
    }

    @Test func onlyTheNewestThreeBackupsAreKeptAndOtherFilesAreLeftAlone() async throws {
        try await withTemporaryPaths { paths in
            let old = [
                "verba-2020-01-01T00-00-00Z.sqlite", "verba-2021-01-01T00-00-00Z.sqlite",
                "verba-2022-01-01T00-00-00Z.sqlite",
            ]
            for name in old + ["notes.txt"] {
                try Data().write(to: paths.backups.appending(path: name))
            }
            try paths.seedDatabase(upTo: "v0_scaffold")

            _ = try AppDatabase.open(paths)

            let names = try paths.backupNames()
            #expect(!names.contains(old[0]))
            #expect(names.contains(old[1]) && names.contains(old[2]) && names.contains("notes.txt"))
            #expect(names.filter { $0.hasPrefix("verba-") }.count == 3)
        }
    }

    @Test func pruningRanksBackupsFromTheSameSecondByTheirClashNumber() async throws {
        try await withTemporaryPaths { paths in
            let stamp = "verba-2027-01-15T08-00-00Z"
            let names = ["", "-2", "-3", "-10"].map { "\(stamp)\($0).sqlite" }
            for name in names {
                try Data().write(to: paths.backups.appending(path: name))
            }

            BackupFolder(url: paths.backups).prune()

            #expect(try Set(paths.backupNames()) == Set(names.dropFirst()))
        }
    }

    @Test func aNameClashGetsASuffix() async throws {
        try await withTemporaryPaths { paths in
            let folder = BackupFolder(url: paths.backups)
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let first = folder.nextBackupURL(now: now)
            #expect(first.lastPathComponent == "verba-2027-01-15T08-00-00Z.sqlite")
            try Data().write(to: first)
            #expect(folder.nextBackupURL(now: now).lastPathComponent == "verba-2027-01-15T08-00-00Z-2.sqlite")
        }
    }

    @Test func aFailedBackupRunsNoMigration() async throws {
        try await withTemporaryPaths { paths in
            try paths.seedDatabase(upTo: "v0_scaffold")
            let missingFolder = paths.root.appending(path: "no-such-folder", directoryHint: .isDirectory)

            #expect(throws: Persistence.PersistenceError.backupFailed) {
                try AppDatabase.open(at: paths.database, backupsFolder: missingFolder)
            }

            let pool = try DatabasePool(path: paths.database.path(percentEncoded: false))
            let applied = try await pool.read { db in try AppDatabase.migrator.appliedIdentifiers(db) }
            #expect(applied == ["v0_scaffold"])
        }
    }

    @Test func aCorruptFileThrowsAndKeepsItsBytes() async throws {
        try await withTemporaryPaths { paths in
            let garbage = Data((0..<8192).map { _ in UInt8.random(in: 0...255) })
            try garbage.write(to: paths.database)

            #expect(throws: Persistence.PersistenceError.openFailed) {
                try AppDatabase.open(paths)
            }

            #expect(try Data(contentsOf: paths.database) == garbage)
            #expect(try paths.backupNames().isEmpty)
        }
    }

    @Test func aFailedMigrationRollsBackAndKeepsTheLastGoodOne() async throws {
        struct Boom: Error {}
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)
            let course = try await Sample.course(in: database)
            try database.close()

            var failing = AppDatabase.migrator
            failing.registerMigration("v2_boom") { db in
                try db.execute(sql: "CREATE TABLE boom (id INTEGER PRIMARY KEY)")
                throw Boom()
            }
            #expect(throws: Persistence.PersistenceError.migrationFailed) {
                try AppDatabase.open(at: paths.database, backupsFolder: paths.backups, migrator: failing)
            }

            let reopened = try AppDatabase.open(paths)
            try await reopened.writer.read { db throws in
                #expect(try AppDatabase.migrator.appliedIdentifiers(db) == ["v0_scaffold", "v1_core"])
                #expect(try db.tableExists("boom") == false)
            }
            #expect(try await reopened.courses().map(\.id) == [course.id])
        }
    }

    @Test func launchingAHealthyFolderIsReady() async throws {
        try await withTemporaryPaths { paths in
            guard case .ready = AppDatabase.launch(paths: paths) else {
                Issue.record("Expected ready")
                return
            }
        }
    }

    @Test func launchingACorruptFileFailsWithItsMessageAndPointsAtTheFile() async throws {
        try await withTemporaryPaths { paths in
            try Data((0..<8192).map { _ in UInt8.random(in: 0...255) }).write(to: paths.database)

            guard case .failed(let message, let databaseURL) = AppDatabase.launch(paths: paths) else {
                Issue.record("Expected failed")
                return
            }
            #expect(message == Persistence.PersistenceError.openFailed.errorDescription)
            #expect(databaseURL == paths.database)
        }
    }

    @Test func launchingWhenFoldersCantBeMadeFailsAndPointsAtTheDataFolder() async throws {
        try await withTemporaryPaths { paths in
            let blocked = paths.root.appending(path: "blocked", directoryHint: .notDirectory)
            try Data("not a folder".utf8).write(to: blocked)
            let blockedPaths = AppPaths(root: blocked)

            guard case .failed(let message, let databaseURL) = AppDatabase.launch(paths: blockedPaths) else {
                Issue.record("Expected failed")
                return
            }
            #expect(message == AppPathsError.foldersUnavailable.errorDescription)
            #expect(databaseURL == blocked)
        }
    }

    @Test(arguments: [Persistence.PersistenceError.openFailed, .backupFailed, .migrationFailed])
    func everyErrorHasAMessage(error: Persistence.PersistenceError) {
        #expect(error.errorDescription?.isEmpty == false)
    }
}
