import Foundation

/// Every on disk location the app uses, derived from one root folder.
///
/// The app target picks the root (release or dev data folder); tests pass a
/// temporary folder. Packages never check the build type themselves.
public struct AppPaths: Sendable, Equatable {
    /// The data folder every other path is derived from.
    public let root: URL

    /// Creates the paths for a data folder. Nothing is created on disk until `prepareFolders()`.
    public init(root: URL) {
        self.root = root
    }

    /// The single SQLite file that holds everything the app remembers.
    public var database: URL {
        root.appending(path: "verba.sqlite", directoryHint: .notDirectory)
    }

    /// The empty folder every `claude` CLI call runs in, so lessons never touch your files.
    public var claudeWork: URL {
        root.appending(path: "claude-work", directoryHint: .isDirectory)
    }

    /// Where the app keeps a copy of the database from before each migration.
    public var backups: URL {
        root.appending(path: "backups", directoryHint: .isDirectory)
    }

    /// Creates the root, an empty `claude-work/`, and `backups/`. Safe to call on every launch.
    /// - Throws: `AppPathsError.foldersUnavailable` when a folder can't be created.
    public func prepareFolders() throws(AppPathsError) {
        do {
            try FileManager.default.createDirectory(at: claudeWork, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        } catch {
            Log.app.error("Creating the data folders failed: \(String(describing: error), privacy: .private)")
            throw .foldersUnavailable
        }
    }
}

/// The app's folders could not be made ready.
public enum AppPathsError: Error, Sendable, Hashable, LocalizedError {
    /// A folder could not be created, for example because the disk is full.
    case foldersUnavailable

    /// A message to show the learner.
    public var errorDescription: String? {
        switch self {
        case .foldersUnavailable:
            "Verba couldn't create the folders it keeps your data in. "
                + "Check that your disk has free space, then open Verba again."
        }
    }
}
