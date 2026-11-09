import Core
import Foundation
import GRDB

/// The one database the app opens, and the only writer. `open` applies every migration before any screen reads.
public struct AppDatabase: Sendable {
    /// Kept internal so GRDB types never leave this module.
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) {
        self.writer = writer
    }

    /// Opens (or creates) the database file as a `DatabasePool` in WAL mode, copying it to
    /// `backupsFolder` first when an existing file has migrations to apply.
    /// - Throws: `PersistenceError`; on any failure the file keeps its last good migration.
    public static func open(at url: URL, backupsFolder: URL) throws(PersistenceError) -> AppDatabase {
        try open(at: url, backupsFolder: backupsFolder, migrator: migrator)
    }

    /// `open` with a chosen migrator, so tests can run a migration that fails.
    static func open(
        at url: URL, backupsFolder: URL, migrator: DatabaseMigrator
    ) throws(PersistenceError) -> AppDatabase {
        let path = url.path(percentEncoded: false)
        let fileExisted = FileManager.default.fileExists(atPath: path)

        let pool: DatabasePool
        let hasPendingMigrations: Bool
        do {
            pool = try DatabasePool(path: path)
            hasPendingMigrations = try fileExisted && pool.read { try !migrator.hasCompletedMigrations($0) }
        } catch {
            Log.store.error("Database open failed: \(String(describing: error), privacy: .public)")
            throw .openFailed
        }

        if hasPendingMigrations {
            try BackupFolder(url: backupsFolder).writeBackup(of: pool)
        }
        BackupFolder(url: backupsFolder).prune()

        do {
            try migrator.migrate(pool)
        } catch {
            Log.store.error("Migration failed: \(String(describing: error), privacy: .public)")
            throw .migrationFailed
        }
        Log.store.info("Database open, migrations applied")
        return AppDatabase(pool)
    }

    /// An in memory database with the same migrations, for tests.
    /// - Throws: `PersistenceError.openFailed` when it can't be created or migrated.
    public static func inMemory() throws(PersistenceError) -> AppDatabase {
        do {
            let queue = try DatabaseQueue()
            try migrator.migrate(queue)
            return AppDatabase(queue)
        } catch {
            Log.store.error("In memory database failed: \(String(describing: error), privacy: .public)")
            throw .openFailed
        }
    }
}
