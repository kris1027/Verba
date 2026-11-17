import Foundation

/// One program to run: what, with which arguments and input, where, and for how long.
struct Command: Sendable, Hashable {
    /// The program to run.
    var executable: URL
    /// Its arguments, without the program name.
    var arguments: [String]
    /// Text written to standard input, which is then closed. Nil leaves standard input empty.
    var standardInput: String?
    /// The folder the program runs in.
    var workingDirectory: URL
    /// The program's whole environment.
    var environment: [String: String]
    /// How long the program may run before it is stopped.
    var timeLimit: Duration
}

/// What a finished program printed and how it exited. Returned for every exit, zero or not.
struct CommandOutput: Sendable, Hashable {
    /// Standard output, up to the runner's limit.
    var stdout: Data
    /// Standard error, up to the runner's limit (cut off silently).
    var stderr: Data
    /// The exit status, or 128 plus the signal number when a signal ended the program.
    var exitStatus: Int32
    /// True when standard output was longer than the runner's limit.
    var stdoutTruncated: Bool

    init(stdout: Data = Data(), stderr: Data = Data(), exitStatus: Int32 = 0, stdoutTruncated: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitStatus = exitStatus
        self.stdoutTruncated = stdoutTruncated
    }

    /// Standard error as text, with invalid UTF-8 bytes replaced.
    var stderrText: String {
        // Lossy on purpose: stderr is only logged, and invalid bytes must not hide the rest.
        String(decoding: stderr, as: UTF8.self)  // swiftlint:disable:this optional_data_string_conversion
    }
}

/// Why a program could not be run to its end.
enum CommandError: Error, Sendable, Hashable {
    /// The program could not be started. The detail may hold its path, so it is logged privately.
    case launchFailed(detail: String)
    /// The program started, but its standard input could not be written.
    case inputNotWritten(detail: String)
    /// The time limit ran out and the program was stopped.
    case timedOut
    /// The calling task was cancelled and the program was stopped.
    case cancelled

    /// The case name alone, safe to log as public.
    var caseName: String {
        switch self {
        case .launchFailed: "launchFailed"
        case .inputNotWritten: "inputNotWritten"
        case .timedOut: "timedOut"
        case .cancelled: "cancelled"
        }
    }
}

/// The seam between the bridge and real processes, so tests can return canned output.
protocol CommandRunner: Sendable {
    /// Runs a program to its end, or stops it on timeout or cancellation.
    /// Returns only after the program has exited.
    func run(_ command: Command) async throws(CommandError) -> CommandOutput
}
