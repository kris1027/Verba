import Core
import Foundation

extension ClaudeCLI {
    /// The pinned argument list (AC-5). The user message goes on stdin, never here.
    static func arguments(model: ClaudeModel, prompt: Prompt) -> [String] {
        [
            "-p", "--safe-mode", "--tools", "", "--strict-mcp-config", "--disable-slash-commands",
            "--no-session-persistence", "--output-format", "json", "--model", model.rawValue,
            "--system-prompt", prompt.system, "--json-schema", prompt.schema,
        ]
    }

    /// The app's environment without API key variables, with `PATH` set to the binary's folder,
    /// then the login shell's `PATH` (or the Homebrew folders), then the app's own `PATH`.
    nonisolated func childEnvironment(for location: CLILocation) -> [String: String] {
        var environment = baseEnvironment
        environment["ANTHROPIC_API_KEY"] = nil
        environment["ANTHROPIC_AUTH_TOKEN"] = nil
        var binaryFolder = location.url.deletingLastPathComponent().path(percentEncoded: false)
        if binaryFolder.count > 1, binaryFolder.hasSuffix("/") { binaryFolder.removeLast() }
        let shellFolders = location.loginPATH.map { $0.split(separator: ":").map(String.init) } ?? Self.fallbackPATH
        let appFolders = baseEnvironment["PATH"]?.split(separator: ":").map(String.init) ?? []
        var seen = Set<String>()
        let folders = ([binaryFolder] + shellFolders + appFolders).filter { !$0.isEmpty && seen.insert($0).inserted }
        environment["PATH"] = folders.joined(separator: ":")
        return environment
    }

    nonisolated func prepareWorkFolder() throws(ClaudeError) {
        guard !FileManager.default.fileExists(atPath: paths.claudeWork.path(percentEncoded: false)) else { return }
        do {
            try paths.prepareFolders()
        } catch {
            throw .failed(reason: "claude-work could not be created")
        }
    }

    /// What `claude-work/` held after a call.
    enum WorkFolderCheck: Sendable, Hashable {
        case empty
        case holds(items: Int)
        case unreadable
    }

    /// Looks into `claude-work/`. The bridge never deletes anything there.
    nonisolated func checkWorkFolder() -> WorkFolderCheck {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                atPath: paths.claudeWork.path(percentEncoded: false))
            return contents.isEmpty ? .empty : .holds(items: contents.count)
        } catch {
            return .unreadable
        }
    }

    /// AC-5: after every call, however it ended, reports that the isolation leaked.
    nonisolated func warnIfWorkFolderIsNotEmpty() {
        switch checkWorkFolder() {
        case .empty:
            break
        case .holds(let items):
            Log.bridge.warning("claude-work holds \(items, privacy: .public) item(s) after a call")
        case .unreadable:
            Log.bridge.warning("claude-work could not be read after a call")
        }
    }
}
