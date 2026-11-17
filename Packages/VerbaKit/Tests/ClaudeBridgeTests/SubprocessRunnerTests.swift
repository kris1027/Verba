import Darwin
import Foundation
import Testing

@testable import ClaudeBridge

struct SubprocessRunnerTests {
    private let folder: ScriptFolder
    private let runner = SubprocessRunner()

    init() throws {
        folder = try ScriptFolder()
    }

    private func command(
        _ executable: URL, _ arguments: [String] = [], stdin: String? = nil, environment: [String: String] = [:],
        timeLimit: Duration = .seconds(10)
    ) -> Command {
        Command(
            executable: executable, arguments: arguments, standardInput: stdin, workingDirectory: folder.url,
            environment: environment, timeLimit: timeLimit)
    }

    @Test func passesArgumentsStdinCwdAndEnvironment() async throws {
        let echo = try folder.script(
            "echo",
            """
            for arg in "$@"; do printf 'ARG=%s\\n' "$arg"; done
            printf 'CWD=%s\\n' "$(pwd -P)"
            printf 'KEY=%s\\n' "${ANTHROPIC_API_KEY-unset}"
            printf 'ONLY=%s\\n' "$ONLY"
            printf 'STDIN=%s\\n' "$(cat)"
            """)
        let output = try await runner.run(
            command(echo, ["-p", "", "two words"], stdin: "hello\nthere", environment: ["ONLY": "yes"]))
        let lines = (String(bytes: output.stdout, encoding: .utf8) ?? "").split(separator: "\n").map(String.init)
        #expect(
            lines.filter { !$0.hasPrefix("CWD=") } == [
                "ARG=-p", "ARG=", "ARG=two words", "KEY=unset", "ONLY=yes", "STDIN=hello", "there",
            ])
        // The temp folder sits behind the /var to /private/var link, so compare its own name.
        let cwd = try #require(lines.first { $0.hasPrefix("CWD=") })
        #expect(cwd.hasSuffix("/\(folder.url.lastPathComponent)"))
        #expect(output.exitStatus == 0)
        #expect(!output.stdoutTruncated)
    }

    @Test func returnsNonZeroExitWithOutput() async throws {
        let failing = try folder.script("fail", "echo out; echo err >&2; exit 3")
        let output = try await runner.run(command(failing))
        #expect(output.exitStatus == 3)
        #expect(output.stdout == Data("out\n".utf8))
        #expect(output.stderrText == "err\n")
    }

    @Test func stdoutOverTheLimitIsTruncatedAndFlagged() async throws {
        let big = try folder.script("big", "head -c 5242880 /dev/zero")
        let output = try await runner.run(command(big))
        #expect(output.stdoutTruncated)
        #expect(output.stdout.count == SubprocessRunner.stdoutLimit)
        #expect(output.exitStatus == 0)
    }

    @Test func stderrOverTheLimitIsCutSilentlyAndInvalidUTF8DoesNotCrash() async throws {
        let noisy = try folder.script("noisy", "printf '\\377\\376' >&2; head -c 100000 /dev/zero >&2; echo ok")
        let output = try await runner.run(command(noisy))
        #expect(output.stderr.count == SubprocessRunner.stderrLimit)
        #expect(output.stderrText.hasPrefix("\u{FFFD}"))
        #expect(!output.stdoutTruncated)
    }

    @Test func missingProgramIsALaunchFailure() async {
        let missing = folder.url.appending(path: "nope")
        await #expect(throws: CommandError.self) {
            try await runner.run(command(missing))
        }
    }

    @Test func childThatExitsWithoutReadingStdinIsNotACrash() async throws {
        let quick = try folder.script("quick", "exec 0<&-; exit 0")
        let large = String(repeating: "x", count: 1_000_000)
        do {
            let output = try await runner.run(command(quick, stdin: large))
            #expect(output.exitStatus == 0)
        } catch let error {
            guard case .inputNotWritten = error else {
                Issue.record("Expected an input failure, got \(error)")
                return
            }
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func timeLimitStopsTheWholeProcessGroup() async throws {
        let sleeper = try folder.script(
            "sleeper",
            """
            echo $$ > "\(folder.url.path)/pid"
            sleep 300 &
            echo $! > "\(folder.url.path)/child"
            wait
            """)
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: CommandError.timedOut) {
            try await runner.run(command(sleeper, timeLimit: .seconds(1)))
        }
        #expect(clock.now - start < .seconds(10))
        let pid = try #require(try await folder.waitForPID("pid"))
        let child = try #require(try await folder.waitForPID("child"))
        #expect(!isAlive(pid))
        try await expectGone(child)
    }

    @Test(.timeLimit(.minutes(1)))
    func groupThatIgnoresSIGTERMIsKilledTwoSecondsLater() async throws {
        let stubborn = try folder.script(
            "stubborn",
            """
            trap '' TERM
            echo $$ > "\(folder.url.path)/pid"
            sleep 300 &
            echo $! > "\(folder.url.path)/child"
            wait
            """)
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: CommandError.timedOut) {
            try await runner.run(command(stubborn, timeLimit: .seconds(1)))
        }
        let elapsed = clock.now - start
        #expect(elapsed >= .seconds(3) && elapsed < .seconds(10))
        let pid = try #require(try await folder.waitForPID("pid"))
        let child = try #require(try await folder.waitForPID("child"))
        #expect(!isAlive(pid))
        try await expectGone(child)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingTheTaskStopsTheProcess() async throws {
        let sleeper = try folder.script("sleeper", "echo $$ > \"\(folder.url.path)/pid\"; exec sleep 300")
        let runner = runner
        let command = command(sleeper, timeLimit: .seconds(120))
        // A typed throws `Task` closure crashes the 6.4 compiler, so carry the error in a `Result`.
        let task = Task { () async -> Result<CommandOutput, CommandError> in
            do throws(CommandError) {
                return .success(try await runner.run(command))
            } catch {
                return .failure(error)
            }
        }
        let pid = try #require(try await folder.waitForPID("pid"))
        task.cancel()
        let result = await task.value
        #expect(throws: CommandError.cancelled) { try result.get() }
        #expect(!isAlive(pid))
    }

    /// An orphaned grandchild is reaped by launchd, so allow it a moment.
    private func expectGone(_ pid: pid_t) async throws {
        for _ in 0..<40 where isAlive(pid) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!isAlive(pid))
    }
}
