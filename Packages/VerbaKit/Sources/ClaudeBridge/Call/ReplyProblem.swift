import Core

/// Why a reply could not be used. The reason goes to the private log and `invalidReply`.
struct ReplyProblem: Error, Sendable, Hashable {
    var reason: String

    init(_ reason: String) {
        self.reason = reason
    }
}

extension ClaudeError {
    /// The case name alone, safe to log as public.
    var caseName: String {
        switch self {
        case .notInstalled: "notInstalled"
        case .customPathInvalid: "customPathInvalid"
        case .versionTooOld: "versionTooOld"
        case .versionUnreadable: "versionUnreadable"
        case .notLoggedIn: "notLoggedIn"
        case .usageLimitReached: "usageLimitReached"
        case .timedOut: "timedOut"
        case .cancelled: "cancelled"
        case .invalidReply: "invalidReply"
        case .failed: "failed"
        }
    }
}
