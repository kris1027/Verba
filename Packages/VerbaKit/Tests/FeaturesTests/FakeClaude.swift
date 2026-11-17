import Core
import Foundation

/// A scripted `ClaudeConnection` for feature model tests. Keeps the real contract:
/// only `ready` is cached, and `refresh` clears the cache first.
actor FakeClaudeConnection: ClaudeConnection {
    private var statuses: [ClaudeStatus]
    private var cached: ClaudeStatus?
    private var testResult: Result<TestReply, ClaudeError>
    private var testGate: CheckedContinuation<Void, Never>?
    private var holdsTestPrompt = false
    private(set) var statusChecks = 0
    private(set) var testPrompts = 0

    /// Each status check returns the next status; the last one repeats.
    init(statuses: [ClaudeStatus], testResult: Result<TestReply, ClaudeError> = .failure(.cancelled)) {
        precondition(!statuses.isEmpty, "A fake connection needs at least one status")
        self.statuses = statuses
        self.testResult = testResult
    }

    func status(refresh: Bool) -> ClaudeStatus {
        if refresh { cached = nil }
        if let cached { return cached }
        statusChecks += 1
        let next = statuses.count > 1 ? statuses.removeFirst() : statuses[0]
        if case .ready = next { cached = next }
        return next
    }

    /// Makes the next test prompt wait until `releaseTestPrompt()`.
    func holdTestPrompt() {
        holdsTestPrompt = true
    }

    /// Lets a held test prompt finish.
    func releaseTestPrompt() {
        holdsTestPrompt = false
        testGate?.resume()
        testGate = nil
    }

    func sendTestPrompt() async throws(ClaudeError) -> TestReply {
        testPrompts += 1
        if holdsTestPrompt {
            await withCheckedContinuation { testGate = $0 }
        }
        return try testResult.get()
    }
}

/// A scripted `LessonWriter` for feature model tests. Returns its results in order; the last one repeats.
actor FakeLessonWriter: LessonWriter {
    private var results: [Result<GeneratedLesson, ClaudeError>]
    private(set) var requests: [LessonRequest] = []

    init(results: [Result<GeneratedLesson, ClaudeError>]) {
        precondition(!results.isEmpty, "A fake writer needs at least one result")
        self.results = results
    }

    func writeLesson(_ request: LessonRequest) throws(ClaudeError) -> GeneratedLesson {
        requests.append(request)
        let next = results.count > 1 ? results.removeFirst() : results[0]
        return try next.get()
    }
}
