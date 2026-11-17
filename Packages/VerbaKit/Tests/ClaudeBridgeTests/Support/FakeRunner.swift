import Core
import Foundation

@testable import ClaudeBridge

/// A `CommandRunner` that returns canned output without starting a process, and records every command.
actor FakeRunner: CommandRunner {
    var versionOutput = CommandOutput(stdout: Data("2.1.325 (Claude Code)\n".utf8))
    var authOutput = CommandOutput(stdout: Data(#"{"loggedIn": true, "authMethod": "claude.ai"}"#.utf8))
    /// Prompt replies in order; the last one repeats.
    var replies: [Result<CommandOutput, CommandError>] = []
    /// How long `--version` takes, so concurrent callers overlap.
    var statusDelay: Duration = .zero
    /// How long a prompt run takes.
    var promptDelay: Duration = .zero
    /// Cancels the calling task during the first prompt run, as if the learner pressed Stop then.
    var cancelCallerOnFirstPrompt = false
    private(set) var commands: [Command] = []

    func run(_ command: Command) async throws(CommandError) -> CommandOutput {
        commands.append(command)
        if command.arguments == ["--version"] {
            try? await Task.sleep(for: statusDelay)
            return versionOutput
        }
        if command.arguments.first == "auth" {
            return authOutput
        }
        if promptRuns == 1, cancelCallerOnFirstPrompt {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        try? await Task.sleep(for: promptDelay)
        let next =
            replies.count > 1 ? replies.removeFirst() : replies.first ?? .failure(.launchFailed(detail: "no reply"))
        return try next.get()
    }

    func set(
        version: String? = nil, auth: String? = nil, authExit: Int32 = 0,
        replies: [Result<CommandOutput, CommandError>]? = nil,
        statusDelay: Duration? = nil, promptDelay: Duration? = nil, cancelCallerOnFirstPrompt: Bool? = nil
    ) {
        if let version { versionOutput = CommandOutput(stdout: Data(version.utf8)) }
        if let auth { authOutput = CommandOutput(stdout: Data(auth.utf8), exitStatus: authExit) }
        if let replies { self.replies = replies }
        if let statusDelay { self.statusDelay = statusDelay }
        if let promptDelay { self.promptDelay = promptDelay }
        if let cancelCallerOnFirstPrompt { self.cancelCallerOnFirstPrompt = cancelCallerOnFirstPrompt }
    }

    var versionChecks: Int { commands.count { $0.arguments == ["--version"] } }
    var promptRuns: Int { commands.count { $0.arguments.first == "-p" } }
    var promptCommands: [Command] { commands.filter { $0.arguments.first == "-p" } }
}

/// Canned CLI output.
enum CLIOutput {
    /// A `--output-format json` result object.
    static func result(
        structured: Any? = nil, isError: Bool = false, apiErrorStatus: Int? = nil, result: String? = "done",
        modelUsage: [String: Int]? = ["claude-haiku-4-5": 120], exit: Int32 = 0, stderr: String = ""
    ) -> Result<CommandOutput, CommandError> {
        var object: [String: Any] = [
            "type": "result", "subtype": isError ? "error_during_execution" : "success", "is_error": isError,
            "duration_ms": 1234, "session_id": "abc",
        ]
        if let structured { object["structured_output"] = structured }
        if let apiErrorStatus { object["api_error_status"] = apiErrorStatus }
        if let result { object["result"] = result }
        if let modelUsage {
            object["modelUsage"] = modelUsage.mapValues { ["inputTokens": 10, "outputTokens": $0] }
        }
        // swiftlint:disable:next force_try
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return .success(CommandOutput(stdout: data, stderr: Data(stderr.utf8), exitStatus: exit))
    }

    static func raw(_ stdout: String, exit: Int32 = 0) -> Result<CommandOutput, CommandError> {
        .success(CommandOutput(stdout: Data(stdout.utf8), exitStatus: exit))
    }
}

/// Lesson replies as `structured_output` dictionaries.
enum SampleLesson {
    static var choice: [String: Any] {
        [
            "kind": "choice", "prompt": "Pick hello", "explanation": "Hola means hello.",
            "choices": [
                ["text": "Hola", "isCorrect": true], ["text": "Adiós", "isCorrect": false],
                ["text": "Gracias", "isCorrect": false],
            ],
        ]
    }
    static var fillBlank: [String: Any] {
        [
            "kind": "fillBlank", "prompt": "___ días", "explanation": "  ", "answers": ["Buenos", "buenos"],
            "tokens": ["ignored"],
        ]
    }
    static var reorder: [String: Any] {
        [
            "kind": "reorder", "prompt": "Order it", "explanation": "Subject first.", "tokens": ["Yo", "soy", "Ana"],
        ]
    }
    static var match: [String: Any] {
        [
            "kind": "match", "prompt": "Match them", "explanation": "Pairs.",
            "pairs": [["left": "uno", "right": "one"], ["left": "dos", "right": "two"]],
        ]
    }

    static func reply(_ exercises: [[String: Any]] = [choice, fillBlank, reorder, match], title: String = "Greetings")
        -> [String: Any]
    {
        ["title": title, "topic": "Greetings", "explanation": "Say **hola**.", "exercises": exercises]
    }

    static func replacing(_ exercise: [String: Any], _ key: String, with value: Any?) -> [String: Any] {
        var copy = exercise
        copy[key] = value
        return copy
    }
}

/// A `ClaudeCLI` wired to a fake runner, a temp data folder, and a fake `claude` file on a known path.
struct BridgeHarness {
    let folder: ScriptFolder
    let runner = FakeRunner()
    let paths: AppPaths
    let binary: URL
    let cli: ClaudeCLI
    /// A Polish to Spanish request with no hint.
    let lessonRequest: LessonRequest

    init(
        preferences: ClaudePreferences = ClaudePreferences(), shellLookup: ShellLookup? = nil,
        environment: [String: String] = ["PATH": "/usr/bin:/bin", "ANTHROPIC_API_KEY": "sk-x", "HOME": "/Users/t"]
    ) throws {
        folder = try ScriptFolder()
        paths = AppPaths(root: try folder.folder("data"))
        binary = try folder.script("claude", "exit 0")
        let searchPaths = shellLookup == nil ? [binary] : []
        cli = ClaudeCLI(
            paths: paths, runner: runner, preferences: { preferences }, searchPaths: searchPaths,
            shellLookup: { shellLookup }, baseEnvironment: environment)
        lessonRequest = try LessonRequest(
            courseID: CourseID(), nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"))
    }

    func request(hint: String? = nil) throws -> LessonRequest {
        try LessonRequest(
            courseID: CourseID(), nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"), topicHint: hint)
    }
}

/// Runs a typed throws call and returns its outcome, so tests can inspect the exact error.
func outcome<T>(_ body: () async throws(ClaudeError) -> T) async -> Result<T, ClaudeError> {
    do throws(ClaudeError) {
        return .success(try await body())
    } catch {
        return .failure(error)
    }
}
