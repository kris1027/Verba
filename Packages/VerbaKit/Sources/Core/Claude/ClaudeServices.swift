import Foundation

/// The connection to Claude Code: its status and a test prompt. Used by Settings.
public protocol ClaudeConnection: Sendable {
    /// Checks that Claude Code is installed, new enough, and signed in. Only `ready` is cached.
    /// - Parameter refresh: true clears the cache first.
    func status(refresh: Bool) async -> ClaudeStatus

    /// Sends one short structured prompt to prove the whole connection works.
    /// - Throws: any `ClaudeError`.
    func sendTestPrompt() async throws(ClaudeError) -> TestReply
}

/// Writes one lesson with Claude.
public protocol LessonWriter: Sendable {
    /// Asks Claude for a lesson and checks it, retrying once if the reply is unusable.
    /// The caller saves the result.
    /// - Throws: `invalidReply`, `timedOut`, `usageLimitReached`, `cancelled`, a status problem, or `failed`.
    func writeLesson(_ request: LessonRequest) async throws(ClaudeError) -> GeneratedLesson
}
