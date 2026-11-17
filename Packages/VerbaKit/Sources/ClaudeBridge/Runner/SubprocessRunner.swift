import Darwin
import Foundation
import Subprocess
import Synchronization
import System

/// Runs programs with swift-subprocess: in their own session and process group, with output limits,
/// a time limit, and a SIGTERM then SIGKILL teardown that is awaited before returning.
struct SubprocessRunner: CommandRunner {
    /// The most standard output kept; more sets `stdoutTruncated`.
    static let stdoutLimit = 4 * 1024 * 1024
    /// The most standard error kept; more is dropped silently.
    static let stderrLimit = 64 * 1024

    private let stdoutLimit: Int
    private let stderrLimit: Int

    init(stdoutLimit: Int = Self.stdoutLimit, stderrLimit: Int = Self.stderrLimit) {
        self.stdoutLimit = stdoutLimit
        self.stderrLimit = stderrLimit
        // Writing to a child that already exited must be a returned error, not a SIGPIPE that ends the app.
        signal(SIGPIPE, SIG_IGN)
    }

    func run(_ command: Command) async throws(CommandError) -> CommandOutput {
        let timerFired = Mutex(false)
        let outcome = await withTaskGroup(of: RaceResult.self) { group in
            group.addTask { .finished(await launch(command)) }
            group.addTask {
                do {
                    try await Task.sleep(for: command.timeLimit)
                } catch {
                    return .timerStopped
                }
                timerFired.withLock { $0 = true }
                return .timerStopped
            }
            var finished: Result<CommandOutput, CommandError>?
            for await result in group {
                // Either way the race is over: stop the other child. The group waits for both.
                group.cancelAll()
                if case .finished(let result) = result { finished = result }
            }
            return finished ?? .failure(.cancelled)
        }
        switch outcome {
        case .success(let output):
            return output
        case .failure(.cancelled) where timerFired.withLock({ $0 }):
            throw .timedOut
        case .failure(let error):
            throw error
        }
    }

    private enum RaceResult: Sendable {
        case finished(Result<CommandOutput, CommandError>)
        case timerStopped
    }

    /// Runs the program to its end. Cancelling the calling task tears the process group down.
    private func launch(_ command: Command) async -> Result<CommandOutput, CommandError> {
        var options = PlatformOptions()
        options.createSession = true
        options.teardownSequence = [
            .send(signal: .terminate, toProcessGroup: true, allowedDurationToNextStep: .seconds(2))
        ]
        let environment = Environment.custom(
            Dictionary(uniqueKeysWithValues: command.environment.map { (Environment.Key(stringLiteral: $0), $1) }))
        let stdoutLimit = stdoutLimit
        let stderrLimit = stderrLimit
        do {
            let result = try await Subprocess.run(
                .path(FilePath(command.executable.path(percentEncoded: false))),
                arguments: Arguments(command.arguments),
                environment: environment,
                workingDirectory: FilePath(command.workingDirectory.path(percentEncoded: false)),
                platformOptions: options,
                input: .inputWriter,
                output: .sequence,
                error: .sequence
            ) { execution in
                async let stdout = Self.collect(execution.standardOutput, limit: stdoutLimit)
                async let stderr = Self.collect(execution.standardError, limit: stderrLimit)
                let writer = execution.standardInputWriter
                var inputFailure: String?
                do {
                    if let text = command.standardInput {
                        _ = try await writer.write(text)
                    }
                    try await writer.finish()
                } catch {
                    inputFailure = String(describing: error)
                    try? await writer.finish()
                }
                let collected = try await (stdout, stderr)
                return (collected.0, collected.1, inputFailure)
            }
            if Task.isCancelled { return .failure(.cancelled) }
            let (stdout, stderr, inputFailure) = result.closureResult
            if let inputFailure { return .failure(.inputNotWritten(detail: inputFailure)) }
            return .success(
                CommandOutput(
                    stdout: stdout.data, stderr: stderr.data, exitStatus: Self.exitStatus(result.terminationStatus),
                    stdoutTruncated: stdout.truncated))
        } catch {
            if Task.isCancelled { return .failure(.cancelled) }
            return .failure(.launchFailed(detail: String(describing: error)))
        }
    }

    /// Reads a stream to its end, keeping at most `limit` bytes, so the child never blocks on a full pipe.
    private static func collect(
        _ sequence: SubprocessOutputSequence, limit: Int
    ) async throws -> (data: Data, truncated: Bool) {
        var data = Data()
        var truncated = false
        for try await buffer in sequence {
            let room = limit - data.count
            if buffer.count > room { truncated = true }
            guard room > 0 else { continue }
            buffer.withUnsafeBytes { data.append(contentsOf: $0.prefix(room)) }
        }
        return (data, truncated)
    }

    private static func exitStatus(_ status: TerminationStatus) -> Int32 {
        switch status {
        case .exited(let code): code
        case .signaled(let signal): 128 + signal
        }
    }
}
