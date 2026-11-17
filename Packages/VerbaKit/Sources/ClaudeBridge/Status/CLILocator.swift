import Core
import Foundation

/// What the login shell lookup found: the `claude` path and the login shell's `PATH`.
struct ShellLookup: Sendable, Hashable {
    /// The `claude` program the login shell found.
    let path: URL
    /// The login shell's `PATH`, used to build the child's `PATH`.
    let loginPATH: String
}

/// Where `claude` was found, and the login shell's `PATH` when the shell lookup found it.
struct CLILocation: Sendable, Hashable {
    var url: URL
    var loginPATH: String?
}

/// Finds the `claude` program (AC-1): the saved path, then the known install paths, then one login shell lookup.
struct CLILocator: Sendable {
    let searchPaths: [URL]
    let shellLookup: @Sendable () async -> ShellLookup?

    /// The usual install locations, in the order they are tried.
    static func defaultSearchPaths(home: URL) -> [URL] {
        [
            home.appending(path: ".local/bin/claude"),
            home.appending(path: ".claude/local/claude"),
            URL(filePath: "/opt/homebrew/bin/claude"),
            URL(filePath: "/usr/local/bin/claude"),
        ]
    }

    /// - Throws: `customPathInvalid` for a saved path that is not an executable file (no fallback),
    ///   or `notInstalled` when nothing is found.
    func locate(customPath: URL?) async throws(ClaudeError) -> CLILocation {
        if let customPath {
            guard Self.isExecutableFile(customPath) else {
                throw .customPathInvalid(path: customPath.path(percentEncoded: false))
            }
            return CLILocation(url: customPath, loginPATH: nil)
        }
        if let known = searchPaths.first(where: Self.isExecutableFile) {
            return CLILocation(url: known, loginPATH: nil)
        }
        if let lookup = await shellLookup(), Self.isExecutableFile(lookup.path) {
            return CLILocation(url: lookup.path, loginPATH: lookup.loginPATH)
        }
        throw .notInstalled
    }

    static func isExecutableFile(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: path)
    }

    /// Runs `command -v claude` once in your login shell (5 second limit, stdin closed).
    static func loginShellLookup(runner: any CommandRunner, environment: [String: String]) async -> ShellLookup? {
        let command = Command(
            executable: URL(filePath: "/bin/zsh"),
            arguments: ["-lc", #"command -v claude; printf "%s" "$PATH" >&2"#],
            standardInput: nil,
            workingDirectory: .homeDirectory,
            environment: environment,
            timeLimit: .seconds(5))
        do {
            let output = try await runner.run(command)
            Log.bridge.info("Login shell lookup exited with status \(output.exitStatus, privacy: .public)")
            return parseShellLookup(stdout: output.stdout, stderr: output.stderr)
        } catch {
            Log.bridge.error("Login shell lookup failed: \(error.caseName, privacy: .public)")
            Log.bridge.error("Login shell lookup error detail: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// Uses only the last non empty stdout line, which must be an absolute path to an executable file.
    /// The `PATH` is the last stderr line, after anything your shell startup files printed.
    static func parseShellLookup(stdout: Data, stderr: Data) -> ShellLookup? {
        let lastLine = { (data: Data) in
            (String(bytes: data, encoding: .utf8) ?? "")
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { !$0.isEmpty }
        }
        guard let path = lastLine(stdout), path.hasPrefix("/") else { return nil }
        let url = URL(filePath: path)
        guard isExecutableFile(url) else { return nil }
        return ShellLookup(path: url, loginPATH: lastLine(stderr) ?? "")
    }
}
