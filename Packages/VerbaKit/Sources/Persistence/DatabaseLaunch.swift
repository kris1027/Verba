import Core
import Foundation

/// What making the data folder and database ready produced.
public enum DatabaseLaunch: Sendable {
    /// The migrated database, ready for the stores.
    case ready(AppDatabase)
    /// The message to show, and the file (or the data folder when the file is missing) to reveal in Finder.
    case failed(message: String, databaseURL: URL)
}

extension AppDatabase {
    /// Creates the data folders and opens the migrated database. Any failure becomes `failed`, never a crash.
    public static func launch(paths: AppPaths) -> DatabaseLaunch {
        do {
            try paths.prepareFolders()
            return .ready(try open(at: paths.database, backupsFolder: paths.backups))
        } catch {
            Log.app.fault("Launch failed: \(String(describing: error), privacy: .public)")
            let fileExists = FileManager.default.fileExists(atPath: paths.database.path(percentEncoded: false))
            return .failed(message: error.localizedDescription, databaseURL: fileExists ? paths.database : paths.root)
        }
    }
}
