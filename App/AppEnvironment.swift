import Core
import Foundation
import Persistence

/// What launching produced: a working app, or the reason the data could not be opened.
enum LaunchResult {
    case ready(AppEnvironment)
    case failed(message: String, databaseURL: URL)
}

/// The composition root. It is the only place that knows the build type,
/// picks the data folder, and builds the real services that feature models
/// receive later.
final class AppEnvironment {
    let paths: AppPaths
    let learnerStore: any LearnerStore
    let lessonStore: any LessonStore

    private init(paths: AppPaths, database: AppDatabase) {
        self.paths = paths
        self.learnerStore = database
        self.lessonStore = database
    }

    /// Creates the data folder and opens the migrated database, backing it up first when
    /// it has migrations to apply. A failure becomes `failed`, which shows the error screen.
    static func launch() -> LaunchResult {
        let paths = AppPaths(root: dataRoot)
        switch AppDatabase.launch(paths: paths) {
        case .ready(let database):
            Log.app.info("Data folder ready at \(paths.root.path(percentEncoded: false), privacy: .private)")
            return .ready(AppEnvironment(paths: paths, database: database))
        case .failed(let message, let databaseURL):
            return .failed(message: message, databaseURL: databaseURL)
        }
    }

    /// Debug builds keep their data apart so development never touches real progress.
    /// `#if DEBUG` is reliable here (the app target), not inside the Swift package.
    private static var dataRoot: URL {
        #if DEBUG
        let folderName = "Verba-Dev"
        #else
        let folderName = "Verba"
        #endif
        return URL.applicationSupportDirectory.appending(path: folderName, directoryHint: .isDirectory)
    }
}
