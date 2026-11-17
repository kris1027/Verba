import Foundation

/// Whether Claude Code can be used right now.
public enum ClaudeStatus: Sendable, Hashable {
    /// Claude Code is installed, new enough, and signed in.
    case ready(version: String, path: URL)
    /// Something has to be fixed first.
    case problem(ClaudeError)

    /// The version and path when ready.
    /// - Throws: the problem's `ClaudeError` otherwise.
    public func requireReady() throws(ClaudeError) -> (version: String, path: URL) {
        switch self {
        case .ready(let version, let path): (version, path)
        case .problem(let error): throw error
        }
    }
}

/// The result of a successful test prompt.
public struct TestReply: Sendable, Hashable {
    /// The model name the CLI reported, or "Claude" when it reported none.
    public let model: String
    /// How long the call took, in milliseconds.
    public let durationMs: Int

    /// Creates a test reply.
    public init(model: String, durationMs: Int) {
        self.model = model
        self.durationMs = durationMs
    }
}
