import Core
import Foundation

/// The one client for the local `claude` CLI. Each request starts the CLI once, isolated in an empty
/// folder with tools, hooks, plugins, and MCP servers off, and asks for a reply matching a JSON schema.
///
/// The actor holds only the status cache: calls run in parallel, and each feature model allows one call
/// of its own at a time.
public actor ClaudeCLI: ClaudeConnection, LessonWriter {
    /// The oldest Claude Code whose flags Verba has verified.
    static let minimumVersion = CLIVersion(major: 2, minor: 1, patch: 325)
    /// The limit for `claude --version` and `claude auth status`.
    static let statusTimeLimit: Duration = .seconds(10)
    /// The limit for each lesson attempt, in seconds.
    static let lessonTimeLimit = 120
    /// The limit for the test prompt, in seconds.
    static let testTimeLimit = 30
    /// Used when the login shell lookup did not run.
    static let fallbackPATH = ["/opt/homebrew/bin", "/usr/local/bin"]

    let paths: AppPaths
    private let runner: any CommandRunner
    private let preferences: @Sendable () -> ClaudePreferences
    private let locator: CLILocator
    let baseEnvironment: [String: String]

    private var cached: ResolvedCLI?
    private var inFlight: Task<Result<ResolvedCLI, ClaudeError>, Never>?
    private var generation = 0

    /// A ready `claude`: where it is, its version, and the login shell `PATH` if the shell found it.
    struct ResolvedCLI: Sendable, Hashable {
        var path: URL
        var version: String
        var loginPATH: String?
    }

    /// Creates the client that runs the real `claude` CLI.
    /// - Parameters:
    ///   - paths: the data folder; every call runs in its `claude-work/`.
    ///   - preferences: read at the start of each call, so a Settings change applies to the next call.
    public init(paths: AppPaths, preferences: @escaping @Sendable () -> ClaudePreferences) {
        let runner = SubprocessRunner()
        let environment = ProcessInfo.processInfo.environment
        self.init(
            paths: paths, runner: runner, preferences: preferences,
            searchPaths: CLILocator.defaultSearchPaths(home: .homeDirectory),
            shellLookup: { await CLILocator.loginShellLookup(runner: runner, environment: environment) },
            baseEnvironment: environment)
    }

    /// Creates a client with its seams replaced. Tests pass their own search list and lookup,
    /// so the developer's real `claude` never leaks in.
    init(
        paths: AppPaths, runner: any CommandRunner, preferences: @escaping @Sendable () -> ClaudePreferences,
        searchPaths: [URL], shellLookup: @escaping @Sendable () async -> ShellLookup?,
        baseEnvironment: [String: String]
    ) {
        self.paths = paths
        self.runner = runner
        self.preferences = preferences
        self.locator = CLILocator(searchPaths: searchPaths, shellLookup: shellLookup)
        self.baseEnvironment = baseEnvironment
    }

    // MARK: - Status

    /// Checks that Claude Code is installed, new enough, and signed in. Only `ready` is cached.
    public func status(refresh: Bool) async -> ClaudeStatus {
        if refresh { invalidate() }
        switch await resolve() {
        case .success(let resolved): return .ready(version: resolved.version, path: resolved.path)
        case .failure(let problem): return .problem(problem)
        }
    }

    /// Forgets the cached status, and stops an in flight check from storing its result.
    func invalidate() {
        generation += 1
        cached = nil
        inFlight = nil
    }

    /// The cached `ready`, or the result of one shared check. A caller's cancellation never cancels it.
    private func resolve() async -> Result<ResolvedCLI, ClaudeError> {
        if let cached { return .success(cached) }
        if let inFlight { return await inFlight.value }
        let started = generation
        let task = Task {
            let result = await self.check()
            self.store(result, startedAt: started)
            return result
        }
        inFlight = task
        return await task.value
    }

    private func store(_ result: Result<ResolvedCLI, ClaudeError>, startedAt started: Int) {
        guard started == generation else { return }
        inFlight = nil
        if case .success(let resolved) = result { cached = resolved }
    }

    private nonisolated func check() async -> Result<ResolvedCLI, ClaudeError> {
        do throws(ClaudeError) {
            let location = try await locator.locate(customPath: preferences().cliPath)
            try prepareWorkFolder()
            let environment = childEnvironment(for: location)
            let version = try await readVersion(location, environment: environment)
            try await requireSignedIn(location, environment: environment)
            Log.bridge.info("Claude Code \(version, privacy: .public) is ready")
            Log.bridge.info("Claude Code path: \(location.url.path(percentEncoded: false), privacy: .private)")
            return .success(ResolvedCLI(path: location.url, version: version, loginPATH: location.loginPATH))
        } catch {
            Log.bridge.error("Claude status check found a problem: \(error.caseName, privacy: .public)")
            return .failure(error)
        }
    }

    private nonisolated func readVersion(
        _ location: CLILocation, environment: [String: String]
    ) async throws(ClaudeError) -> String {
        let output: CommandOutput
        do {
            output = try await runner.run(
                statusCommand(location, ["--version"], environment: environment))
        } catch {
            Log.bridge.error("claude --version did not finish: \(String(describing: error), privacy: .public)")
            throw .versionUnreadable
        }
        guard output.exitStatus == 0,
            let version = CLIVersion(firstMatchIn: String(bytes: output.stdout, encoding: .utf8) ?? "")
        else {
            Log.bridge.error("claude --version exited with status \(output.exitStatus, privacy: .public)")
            throw .versionUnreadable
        }
        guard version >= Self.minimumVersion else {
            throw .versionTooOld(found: version.description, minimum: Self.minimumVersion.description)
        }
        return version.description
    }

    private nonisolated func requireSignedIn(
        _ location: CLILocation, environment: [String: String]
    ) async throws(ClaudeError) {
        let output: CommandOutput
        do {
            output = try await runner.run(
                statusCommand(location, ["auth", "status", "--json"], environment: environment))
        } catch {
            throw .failed(reason: "claude auth status did not finish: \(error)")
        }
        // `loggedIn` is read whenever stdout is JSON, whatever the exit status.
        switch AuthStatus.loggedIn(from: output.stdout) {
        case true?: return
        case false?: throw .notLoggedIn
        case nil:
            Log.bridge.error("claude auth status printed no loggedIn: \(output.stderrText, privacy: .private)")
            throw .failed(reason: "claude auth status printed no loggedIn (exit \(output.exitStatus))")
        }
    }

    private nonisolated func statusCommand(
        _ location: CLILocation, _ arguments: [String], environment: [String: String]
    ) -> Command {
        Command(
            executable: location.url, arguments: arguments, standardInput: nil, workingDirectory: paths.claudeWork,
            environment: environment, timeLimit: Self.statusTimeLimit)
    }

    // MARK: - Calls

    /// Sends "Reply with the word ready." on `haiku` with a 30 second limit.
    public func sendTestPrompt() async throws(ClaudeError) -> TestReply {
        let prompt = try Prompt.load("test-v1")
        let outcome = try await call(prompt, model: .haiku, timeLimitSeconds: Self.testTimeLimit)
        struct Body: Decodable { let reply: String }
        do {
            guard let structured = outcome.result.structuredOutput else { throw ReplyProblem("no structured_output") }
            _ = try structured.decode(Body.self)
        } catch {
            Log.bridge.error("Unusable test reply: \(outcome.result.rawReply, privacy: .private)")
            throw .invalidReply(reason: "test reply: \(error)")
        }
        return TestReply(model: outcome.result.model ?? "Claude", durationMs: outcome.durationMs)
    }

    /// Asks Claude for a lesson and checks it, retrying once if the reply is unusable.
    public func writeLesson(_ request: LessonRequest) async throws(ClaudeError) -> GeneratedLesson {
        let prompt = try LessonPrompt.make(for: request)
        let model = preferences().model
        var lastProblem = ReplyProblem("no attempt")
        for attempt in 1...2 {
            if Task.isCancelled { throw .cancelled }
            let outcome = try await call(prompt, model: model, timeLimitSeconds: Self.lessonTimeLimit)
            switch LessonMapper.map(outcome.result, request: request, prompt: prompt, durationMs: outcome.durationMs) {
            case .success(let mapped):
                for position in mapped.unfairChoicePositions {
                    Log.bridge.warning(
                        "Choice exercise \(position, privacy: .public) has options of very different lengths")
                }
                return mapped.lesson
            case .failure(let problem):
                Log.bridge.error(
                    "Lesson reply attempt \(attempt, privacy: .public) was unusable: \(problem.reason, privacy: .private)"
                )
                Log.bridge.error("Unusable lesson reply: \(outcome.result.rawReply, privacy: .private)")
                lastProblem = problem
            }
        }
        throw .invalidReply(reason: lastProblem.reason)
    }

    struct CallOutcome: Sendable {
        var result: CLIResult
        var durationMs: Int
    }

    /// One structured CLI call with the AC-5 flags, classified in AC-11 order.
    private func call(
        _ prompt: Prompt, model: ClaudeModel, timeLimitSeconds: Int
    ) async throws(ClaudeError) -> CallOutcome {
        if Task.isCancelled { throw .cancelled }
        let resolved = try await resolve().get()
        let usedGeneration = generation
        if Task.isCancelled { throw .cancelled }
        try prepareWorkFolder()
        let command = Command(
            executable: resolved.path,
            arguments: Self.arguments(model: model, prompt: prompt),
            standardInput: prompt.user,
            workingDirectory: paths.claudeWork,
            environment: childEnvironment(for: CLILocation(url: resolved.path, loginPATH: resolved.loginPATH)),
            timeLimit: .seconds(timeLimitSeconds))
        Log.bridge.info(
            "Running claude -p (\(prompt.version, privacy: .public), model \(model.rawValue, privacy: .public))")
        Log.bridge.debug("Prompt: \(prompt.user, privacy: .private)")

        let clock = ContinuousClock()
        let start = clock.now
        let output: CommandOutput
        do {
            output = try await runner.run(command)
        } catch {
            switch error {
            case .cancelled:
                Log.bridge.info("Claude call cancelled")
                throw .cancelled
            case .timedOut:
                Log.bridge.error("Claude call timed out after \(timeLimitSeconds, privacy: .public) s")
                throw .timedOut(seconds: timeLimitSeconds)
            case .launchFailed(let reason):
                throw await failure(reason, stderr: "", usedGeneration: usedGeneration)
            }
        }
        let durationMs = Int((clock.now - start) / .milliseconds(1))
        let result = try await classify(output, durationMs: durationMs, usedGeneration: usedGeneration)
        return CallOutcome(result: result, durationMs: durationMs)
    }

    /// Reads a finished run: over limit or unreadable output, usage limit, then error results (AC-10, AC-11).
    private func classify(
        _ output: CommandOutput, durationMs: Int, usedGeneration: Int
    ) async throws(ClaudeError) -> CLIResult {
        Log.bridge.info(
            "claude exited with status \(output.exitStatus, privacy: .public) after \(durationMs, privacy: .public) ms")
        warnIfWorkFolderIsNotEmpty()

        guard !output.stdoutTruncated else {
            throw await failure(
                "stdout was over its size limit", stderr: output.stderrText, usedGeneration: usedGeneration)
        }
        let result: CLIResult
        do {
            result = try CLIResult.decode(stdout: output.stdout)
        } catch {
            throw await failure(error.description, stderr: output.stderrText, usedGeneration: usedGeneration)
        }
        if result.isUsageLimit(exitStatus: output.exitStatus) {
            Log.bridge.error("Claude usage limit reached (status \(result.apiErrorStatus ?? 0, privacy: .public))")
            throw .usageLimitReached
        }
        guard !result.isError, output.exitStatus == 0 else {
            Log.bridge.error("Claude result text: \(result.result ?? "", privacy: .private)")
            let reason = "is_error \(result.isError), subtype \(result.subtype ?? "none"), exit \(output.exitStatus)"
            throw await failure(reason, stderr: output.stderrText, usedGeneration: usedGeneration)
        }
        Log.bridge.debug("Reply: \(result.rawReply, privacy: .private)")
        return result
    }

    /// AC-11: clears the cache and checks the status once more (shared with concurrent failures).
    /// A problem found there is what the caller sees; otherwise `failed`.
    private func failure(_ reason: String, stderr: String, usedGeneration: Int) async -> ClaudeError {
        Log.bridge.error("Claude call failed: \(reason, privacy: .private)")
        if !stderr.isEmpty {
            Log.bridge.error("claude stderr: \(stderr, privacy: .private)")
        }
        // A concurrent failure that already cleared the cache has started the check this one shares.
        if usedGeneration == generation { invalidate() }
        switch await resolve() {
        case .failure(let problem): return problem
        case .success: return .failed(reason: reason)
        }
    }
}
