import Core
import Foundation
import Testing

@testable import ClaudeBridge

struct IsolationTests {
    @Test func everyCallUsesThePinnedArgumentsStdinCwdAndNoKeys() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [CLIOutput.result(structured: SampleLesson.reply())])
        _ = try await harness.cli.writeLesson(harness.request(hint: "food"))
        let command = try #require(await harness.runner.promptCommands.first)
        let prompt = try LessonPrompt.make(for: harness.request(hint: "food"))
        #expect(
            command.arguments == [
                "-p", "--safe-mode", "--tools", "", "--strict-mcp-config", "--disable-slash-commands",
                "--no-session-persistence", "--output-format", "json", "--model", "sonnet", "--system-prompt",
                prompt.system, "--json-schema", prompt.schema,
            ])
        #expect(command.executable == harness.binary)
        #expect(command.workingDirectory == harness.paths.claudeWork)
        #expect(command.standardInput == prompt.user)
        #expect(command.standardInput?.contains("food") == true)
        #expect(!command.arguments.contains { $0.contains("food") })
        #expect(command.environment["ANTHROPIC_API_KEY"] == nil)
        #expect(command.environment["ANTHROPIC_AUTH_TOKEN"] == nil)
        #expect(command.environment["HOME"] == "/Users/t")
        #expect(command.timeLimit == .seconds(120))
    }

    @Test func pathStartsWithTheBinaryFolderThenHomebrewWhenNoShellLookupRan() async throws {
        let harness = try BridgeHarness(environment: ["PATH": "/usr/bin:/opt/homebrew/bin:/bin"])
        let env = harness.cli.childEnvironment(for: CLILocation(url: harness.binary, loginPATH: nil))
        let folder = harness.binary.deletingLastPathComponent().path(percentEncoded: false)
        let expectedFolder = folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        #expect(env["PATH"] == "\(expectedFolder):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin")
    }

    @Test func pathUsesTheLoginShellPathWhenTheLookupRan() async throws {
        let harness = try BridgeHarness(environment: ["PATH": "/usr/bin:/bin", "ANTHROPIC_AUTH_TOKEN": "t"])
        let env = harness.cli.childEnvironment(
            for: CLILocation(url: URL(filePath: "/Users/t/.local/bin/claude"), loginPATH: "/Users/t/.nvm:/usr/bin"))
        #expect(env["PATH"] == "/Users/t/.local/bin:/Users/t/.nvm:/usr/bin:/bin")
        #expect(env["ANTHROPIC_AUTH_TOKEN"] == nil)
    }

    @Test(arguments: [
        (ClaudePreferences(model: .opus), "opus"), (ClaudePreferences(savedModel: "gpt", savedPath: nil), "sonnet"),
    ])
    func modelPreferenceIsPassedAsModel(preferences: ClaudePreferences, expected: String) async throws {
        let harness = try BridgeHarness(preferences: preferences)
        await harness.runner.set(replies: [CLIOutput.result(structured: SampleLesson.reply())])
        _ = try await harness.cli.writeLesson(harness.request())
        let arguments = try #require(await harness.runner.promptCommands.first?.arguments)
        let index = try #require(arguments.firstIndex(of: "--model"))
        #expect(arguments[index + 1] == expected)
    }
}

struct WriteLessonTests {
    @Test func validReplyBecomesACheckedLessonAndGeneration() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(
            replies: [
                CLIOutput.result(
                    structured: SampleLesson.reply(), result: "raw text", modelUsage: ["m-a": 5, "m-b": 9])
            ])
        let request = try harness.request()
        let generated = try await harness.cli.writeLesson(request)
        #expect(generated.lesson.courseID == request.courseID)
        #expect(generated.lesson.kind == .regular)
        #expect(generated.lesson.exercises.map(\.kind) == [.choice, .fillBlank, .reorder, .match])
        try generated.lesson.validate()
        #expect(generated.generation.kind == .lesson)
        #expect(generated.generation.promptVersion == "lesson-v1")
        #expect(generated.generation.model == "m-b")
        #expect(generated.generation.rawReply == "raw text")
        #expect(generated.generation.durationMs >= 0)
        #expect(await harness.runner.promptRuns == 1)
    }

    @Test func badFirstReplyIsRetriedOnce() async throws {
        let harness = try BridgeHarness()
        let noTokens = SampleLesson.replacing(SampleLesson.reorder, "tokens", with: nil)
        await harness.runner.set(replies: [
            CLIOutput.result(
                structured: SampleLesson.reply([
                    SampleLesson.choice, SampleLesson.fillBlank, noTokens, SampleLesson.match,
                ])),
            CLIOutput.result(structured: SampleLesson.reply()),
        ])
        _ = try await harness.cli.writeLesson(harness.request())
        #expect(await harness.runner.promptRuns == 2)
    }

    @Test func twoBadRepliesGiveInvalidReplyWithTheSecondReason() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [
            CLIOutput.result(structured: SampleLesson.reply(title: String(repeating: "t", count: 81))),
            CLIOutput.result(structured: nil),
        ])
        let result = await outcome { () async throws(ClaudeError) in
            try await harness.cli.writeLesson(harness.lessonRequest)
        }
        #expect(result.failure == .invalidReply(reason: "no structured_output"))
        #expect(await harness.runner.promptRuns == 2)
    }

    @Test func errorResultIsNotRetried() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [CLIOutput.result(structured: SampleLesson.reply(), isError: true)])
        let result = await outcome { () async throws(ClaudeError) in
            try await harness.cli.writeLesson(harness.lessonRequest)
        }
        guard case .failed = result.failure else {
            Issue.record("Expected failed, got \(result)")
            return
        }
        #expect(await harness.runner.promptRuns == 1)
    }

    @Test func cancelAfterABadFirstReplyDoesNotStartTheRetry() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(
            replies: [CLIOutput.result(structured: nil), CLIOutput.result(structured: SampleLesson.reply())],
            cancelCallerOnFirstPrompt: true)
        let cli = harness.cli
        let request = try harness.request()
        let result = await Task { await outcome { () async throws(ClaudeError) in try await cli.writeLesson(request) } }
            .value
        #expect(result.failure == .cancelled)
        #expect(await harness.runner.promptRuns == 1)
    }

    @Test func timeoutIsNotRetried() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [.failure(.timedOut)])
        let result = await outcome { () async throws(ClaudeError) in
            try await harness.cli.writeLesson(harness.lessonRequest)
        }
        #expect(result.failure == .timedOut(seconds: 120))
        #expect(await harness.runner.promptRuns == 1)
    }

    @Test func runnerCancellationIsCancelled() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [.failure(.cancelled)])
        let result = await outcome { () async throws(ClaudeError) in
            try await harness.cli.writeLesson(harness.lessonRequest)
        }
        #expect(result.failure == .cancelled)
    }

    @Test func statusProblemStopsTheCallBeforeLaunching() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(auth: #"{"loggedIn": false}"#)
        let result = await outcome { () async throws(ClaudeError) in
            try await harness.cli.writeLesson(harness.lessonRequest)
        }
        #expect(result.failure == .notLoggedIn)
        #expect(await harness.runner.promptRuns == 0)
    }
}

struct FailureClassificationTests {
    private func run(_ reply: Result<CommandOutput, CommandError>, harness: BridgeHarness) async throws
        -> ClaudeError?
    {
        await harness.runner.set(replies: [reply])
        let request = try harness.request()
        return await outcome { () async throws(ClaudeError) in try await harness.cli.writeLesson(request) }.failure
    }

    @Test(arguments: [
        CLIOutput.result(isError: true, apiErrorStatus: 429, exit: 1),
        CLIOutput.result(isError: true, result: "Claude AI usage limit reached|1700000000", exit: 1),
        CLIOutput.result(isError: true, result: "API Error: Rate Limit exceeded"),
    ])
    func usageLimitIsNotRetriedAndKeepsTheCache(reply: Result<CommandOutput, CommandError>) async throws {
        let harness = try BridgeHarness()
        #expect(try await run(reply, harness: harness) == .usageLimitReached)
        #expect(await harness.runner.promptRuns == 1)
        #expect(await harness.runner.versionChecks == 1)
    }

    @Test func failureThenSignedOutGivesNotLoggedIn() async throws {
        let harness = try BridgeHarness()
        _ = await harness.cli.status(refresh: false)
        await harness.runner.set(auth: #"{"loggedIn": false}"#)
        #expect(try await run(CLIOutput.raw("", exit: 1), harness: harness) == .notLoggedIn)
        #expect(await harness.runner.versionChecks == 2)
    }

    @Test(arguments: [
        CLIOutput.raw("", exit: 1),
        CLIOutput.raw("Update available!\n{\"type\":\"result\",\"is_error\":false}"),
        CLIOutput.raw("{\"type\":\"result\",\"is_error\":false} trailing"),
        CLIOutput.raw("[1, 2]"),
        CLIOutput.raw("{\"type\":\"assistant\"}"),
        .success(CommandOutput(stdout: Data("{}".utf8), stderr: Data([0xFF, 0xFE]), stdoutTruncated: true)),
        .failure(.launchFailed(detail: "spawn failed")),
        CLIOutput.result(structured: SampleLesson.reply(), exit: 2),
    ])
    func otherFailuresRecheckOnceThenGiveFailed(reply: Result<CommandOutput, CommandError>) async throws {
        let harness = try BridgeHarness()
        guard case .failed = try await run(reply, harness: harness) else {
            Issue.record("Expected failed")
            return
        }
        #expect(await harness.runner.versionChecks == 2)
        #expect(await harness.runner.promptRuns == 1)
    }

    @Test func concurrentFailuresShareOneRecheck() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(promptDelay: .milliseconds(100))
        let request = try harness.request()
        let cli = harness.cli
        await harness.runner.set(replies: [CLIOutput.raw("", exit: 1)])
        async let first = outcome { () async throws(ClaudeError) in try await cli.writeLesson(request) }
        async let second = outcome { () async throws(ClaudeError) in try await cli.writeLesson(request) }
        let (firstResult, secondResult) = await (first, second)
        #expect(firstResult.failure != nil && secondResult.failure != nil)
        #expect(await harness.runner.promptRuns == 2)
        #expect(await harness.runner.versionChecks == 2)
    }
}

struct TestPromptTests {
    @Test func validReplyReportsModelAndDuration() async throws {
        let harness = try BridgeHarness(preferences: ClaudePreferences(model: .opus))
        await harness.runner.set(replies: [
            CLIOutput.result(structured: ["reply": "ready"], modelUsage: ["claude-haiku-4-5": 3])
        ])
        let reply = try await harness.cli.sendTestPrompt()
        #expect(reply.model == "claude-haiku-4-5")
        #expect(reply.durationMs >= 0)
        let command = try #require(await harness.runner.promptCommands.first)
        let index = try #require(command.arguments.firstIndex(of: "--model"))
        #expect(command.arguments[index + 1] == "haiku")
        #expect(command.timeLimit == .seconds(30))
        #expect(command.standardInput == "Reply with the word ready.")
    }

    @Test func missingModelUsageShowsClaude() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [CLIOutput.result(structured: ["reply": "ok"], modelUsage: nil)])
        #expect(try await harness.cli.sendTestPrompt().model == "Claude")
    }

    @Test func wrongShapeIsInvalidReply() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [CLIOutput.result(structured: ["answer": 1])])
        let result = await outcome { () async throws(ClaudeError) in try await harness.cli.sendTestPrompt() }
        guard case .invalidReply = result.failure else {
            Issue.record("Expected invalidReply, got \(result)")
            return
        }
    }

    @Test func timeoutReportsThirtySeconds() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(replies: [.failure(.timedOut)])
        let result = await outcome { () async throws(ClaudeError) in try await harness.cli.sendTestPrompt() }
        #expect(result.failure == .timedOut(seconds: 30))
    }
}

extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
