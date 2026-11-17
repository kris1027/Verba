import Core
import Foundation
import Observation

/// Drives the Claude section of Settings: the status check, Check again, and the test prompt.
/// It only orchestrates `ClaudeConnection` calls; the bridge owns every rule.
@Observable
public final class ClaudeSettingsModel {
    /// What the status line shows.
    public enum StatusState: Equatable {
        /// A check is running.
        case checking
        /// Claude Code is ready at this path.
        case ready(version: String, path: URL)
        /// Something has to be fixed; the message says what.
        case problem(message: String)
    }

    /// What the test prompt area shows.
    public enum TestState: Equatable {
        /// No test has run yet.
        case idle
        /// A test is running; the button is disabled.
        case running
        /// The test passed, with the line to show.
        case succeeded(message: String)
        /// The test failed, with the error message to show.
        case failed(message: String)
    }

    /// The status line's state.
    public private(set) var status: StatusState = .checking
    /// The test prompt's state.
    public private(set) var test: TestState = .idle

    private let connection: any ClaudeConnection
    /// Only the latest check may update the status line.
    private var latestCheck = 0

    /// Creates the model for a connection.
    public init(connection: any ClaudeConnection) {
        self.connection = connection
    }

    /// The status line text, such as `Ready, Claude Code 2.1.325`.
    public var statusText: String {
        switch status {
        case .checking: "Checking Claude Code…"
        case .ready(let version, _): "Ready, Claude Code \(version)"
        case .problem(let message): message
        }
    }

    /// The `claude` path in use, when the status is ready.
    public var pathInUse: String? {
        guard case .ready(_, let path) = status else { return nil }
        return path.path(percentEncoded: false)
    }

    /// Whether a test prompt is running.
    public var isTesting: Bool {
        test == .running
    }

    /// Runs the status check, reusing a cached `ready`. Called when the section appears.
    public func loadStatus() async {
        await checkStatus(refresh: false)
    }

    /// Clears the cache and checks again. Called by **Check again** and when the saved path changes.
    public func checkAgain() async {
        await checkStatus(refresh: true)
    }

    private func checkStatus(refresh: Bool) async {
        latestCheck += 1
        let check = latestCheck
        status = .checking
        let result = await connection.status(refresh: refresh)
        guard check == latestCheck else { return }
        switch result {
        case .ready(let version, let path): status = .ready(version: version, path: path)
        case .problem(let error): status = .problem(message: Self.message(for: error))
        }
    }

    /// Sends one test prompt. Does nothing while a test is already running.
    public func sendTestPrompt() async {
        guard !isTesting else { return }
        test = .running
        do {
            let reply = try await connection.sendTestPrompt()
            test = .succeeded(message: Self.successMessage(for: reply))
        } catch {
            test = .failed(message: Self.message(for: error))
            Log.ui.error("Test prompt failed: \(error.caseLabel, privacy: .public)")
        }
    }

    /// `Reply received in <seconds> s from <model>`, with one decimal.
    static func successMessage(for reply: TestReply) -> String {
        let seconds = (Double(reply.durationMs) / 1000).formatted(.number.precision(.fractionLength(1)))
        return "Reply received in \(seconds) s from \(reply.model)"
    }

    static func message(for error: ClaudeError) -> String {
        error.errorDescription ?? "Claude Code stopped with an error."
    }
}

extension ClaudeError {
    /// A label with no learner content, safe to log as public.
    fileprivate var caseLabel: String {
        String(describing: self).prefix { $0 != "(" }.description
    }
}
