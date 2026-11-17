import Darwin
import Foundation

/// A temporary folder that holds small fake programs written by a test. Removed on deinit.
final class ScriptFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(
            path: "verba-bridge-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes an executable `/bin/sh` script and returns its URL.
    @discardableResult
    func script(_ name: String, _ body: String) throws -> URL {
        let file = url.appending(path: name)
        try "#!/bin/sh\n\(body)\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }

    /// A subfolder, created on demand.
    func folder(_ name: String) throws -> URL {
        let folder = url.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Waits up to 5 seconds for a file to exist, then reads it as a process id.
    func waitForPID(_ name: String) async throws -> pid_t? {
        let file = url.appending(path: name)
        for _ in 0..<100 {
            if let text = try? String(contentsOf: file, encoding: .utf8),
                let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                return pid
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }
}

/// Whether a process with this id still exists (a zombie counts as gone once reaped by its parent).
func isAlive(_ pid: pid_t) -> Bool {
    kill(pid, 0) == 0 || errno == EPERM
}
