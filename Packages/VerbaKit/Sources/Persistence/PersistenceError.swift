import Foundation

/// The database could not be made ready at launch.
public enum PersistenceError: Error, Sendable, Hashable, LocalizedError {
    /// The file could not be opened, for example because it is damaged.
    case openFailed
    /// The safety copy made before updating could not be written, so nothing was updated.
    case backupFailed
    /// An update to the file failed and was rolled back.
    case migrationFailed

    /// A message to show the learner.
    public var errorDescription: String? {
        switch self {
        case .openFailed:
            "Verba couldn't open your saved data. The file may be damaged. It hasn't been changed."
        case .backupFailed:
            "Verba couldn't make a safety copy of your data, so it didn't update it. "
                + "Check that your disk has free space, then open Verba again."
        case .migrationFailed:
            "Verba couldn't update your saved data. The update was undone, so nothing was lost."
        }
    }
}
