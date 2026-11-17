import Core
import Foundation

/// The status probes (AC-1 to AC-4): find `claude`, read its version, and check that it is signed in.
/// They hold no state; the actor's cache in `ClaudeCLI.swift` decides when they run.
extension ClaudeCLI {
    /// Runs every probe once and returns a ready CLI or the first problem found.
    nonisolated func check() async -> Result<ResolvedCLI, ClaudeError> {
        do throws(ClaudeError) {
            let location = try await locator.locate(customPath: preferences().cliPath)
            try prepareWorkFolder()
            let version = try await readVersion(location)
            try await requireSignedIn(location)
            Log.bridge.info("Claude Code \(version.description, privacy: .public) is ready")
            Log.bridge.info("Claude Code path: \(location.url.path(percentEncoded: false), privacy: .private)")
            return .success(ResolvedCLI(path: location.url, version: version, loginPATH: location.loginPATH))
        } catch {
            Log.bridge.error("Claude status check found a problem: \(error.caseName, privacy: .public)")
            return .failure(error)
        }
    }

    nonisolated func readVersion(_ location: CLILocation) async throws(ClaudeError) -> CLIVersion {
        let output: CommandOutput
        do {
            output = try await runner.run(
                statusCommand(location, ["--version"]))
        } catch {
            Log.bridge.error("claude --version did not finish: \(error.caseName, privacy: .public)")
            Log.bridge.error("claude --version error detail: \(String(describing: error), privacy: .private)")
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
        return version
    }

    nonisolated func requireSignedIn(_ location: CLILocation) async throws(ClaudeError) {
        let output: CommandOutput
        do {
            output = try await runner.run(
                statusCommand(location, ["auth", "status", "--json"]))
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

    nonisolated func statusCommand(_ location: CLILocation, _ arguments: [String]) -> Command {
        Command(
            executable: location.url, arguments: arguments, standardInput: nil, workingDirectory: paths.claudeWork,
            environment: childEnvironment(for: location), timeLimit: Self.statusTimeLimit)
    }
}
