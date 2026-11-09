import Foundation

/// A store call could not be completed.
public enum StoreError: Error, Sendable, Hashable, LocalizedError {
    /// A course for that language already exists, active or archived.
    case duplicateCourse
    /// The requested item does not exist.
    case notFound
    /// The item is archived and takes no new content.
    case archived
    /// The exercise's option order was already saved and never changes.
    case displayOrderAlreadySet
    /// The input broke one of the domain's rules.
    case invalid(ValidationError)
    /// The database could not complete the call.
    case unavailable(reason: String)

    /// A message to show the learner.
    public var errorDescription: String? {
        switch self {
        case .duplicateCourse: "You already have a course for that language. It may be archived."
        case .notFound: "That item couldn't be found."
        case .archived: "That item is archived, so it can't be changed."
        case .displayOrderAlreadySet: "The order of this exercise's options is already saved."
        case .invalid(let error): error.errorDescription
        case .unavailable(let reason): "Verba couldn't reach your saved data. \(reason)"
        }
    }
}
