import Foundation

/// Why a call to Claude could not be completed. Every case has a message that says what to do.
public enum ClaudeError: Error, Sendable, Hashable, LocalizedError {
    /// No `claude` program was found.
    case notInstalled
    /// The path saved in Settings is not a program Verba can run.
    case customPathInvalid(path: String)
    /// The installed Claude Code is older than Verba supports.
    case versionTooOld(found: String, minimum: String)
    /// `claude --version` failed or printed no version.
    case versionUnreadable
    /// Claude Code is not signed in.
    case notLoggedIn
    /// The Claude plan's usage limit was reached.
    case usageLimitReached
    /// Claude did not answer within the time limit.
    case timedOut(seconds: Int)
    /// The calling task was cancelled.
    case cancelled
    /// Claude's reply could not be used. The reason goes to the log only.
    case invalidReply(reason: String)
    /// Claude Code stopped with an error. The reason goes to the log only.
    case failed(reason: String)

    /// A message to show the learner.
    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            "Verba couldn't find Claude Code. Install it from claude.com/claude-code, "
                + "or choose where it is in Settings > Claude."
        case .customPathInvalid:
            "The Claude Code path in Settings isn't a program Verba can run. Choose it again or use automatic."
        case .versionTooOld(let found, let minimum):
            "Claude Code \(found) is too old. Verba needs \(minimum) or newer. Run \"claude update\" in Terminal."
        case .versionUnreadable:
            "Verba couldn't read which version of Claude Code is installed. "
                + "Check that \"claude --version\" works in Terminal."
        case .notLoggedIn:
            "Claude Code isn't signed in. Open Terminal, run \"claude\", and sign in with your Claude account."
        case .usageLimitReached:
            "You've reached your Claude plan's usage limit. Try again later."
        case .timedOut(let seconds):
            "Claude didn't answer within \(seconds) seconds. Try again."
        case .cancelled:
            "The request to Claude was stopped."
        case .invalidReply:
            "Claude sent a reply Verba couldn't use. Try again."
        case .failed:
            "Claude Code stopped with an error. Try again, or use Check again in Settings > Claude."
        }
    }
}
