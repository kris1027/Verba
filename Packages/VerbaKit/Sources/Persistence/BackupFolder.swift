import Core
import Foundation
import GRDB

/// The folder holding a copy of the database from before each migration.
/// Pruning here is the one place the app deletes anything.
struct BackupFolder {
    static let keptCount = 3
    private static let prefix = "verba-"
    private static let suffix = ".sqlite"

    let url: URL

    /// Copies the database into a new timestamped file. A partial copy is removed on failure.
    func writeBackup(of pool: DatabasePool) throws(PersistenceError) {
        let backupPath = nextBackupURL(now: .now).path(percentEncoded: false)
        do {
            let queue = try DatabaseQueue(path: backupPath)
            try pool.backup(to: queue)
            try queue.close()
        } catch {
            Log.store.error("Backup failed: \(String(describing: error), privacy: .public)")
            removePartialFile(atPath: backupPath)
            throw .backupFailed
        }
    }

    /// The name for a backup made at `now`, with `-2`, `-3`, and so on if that name is taken.
    func nextBackupURL(now: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        let stem = Self.prefix + formatter.string(from: now)

        var candidate = url.appending(path: stem + Self.suffix, directoryHint: .notDirectory)
        var attempt = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = url.appending(path: "\(stem)-\(attempt)\(Self.suffix)", directoryHint: .notDirectory)
            attempt += 1
        }
        return candidate
    }

    /// Deletes all but the newest backups. A failure only leaves an extra file, so it never blocks launch.
    func prune() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            let backups = try fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false))
                .filter { $0.hasPrefix(Self.prefix) && $0.hasSuffix(Self.suffix) }
                .sorted(by: >)
            for name in backups.dropFirst(Self.keptCount) {
                try fileManager.removeItem(at: url.appending(path: name, directoryHint: .notDirectory))
            }
        } catch {
            Log.store.error("Pruning backups failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func removePartialFile(atPath path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            Log.store.error("Removing a partial backup failed: \(String(describing: error), privacy: .public)")
        }
    }
}
