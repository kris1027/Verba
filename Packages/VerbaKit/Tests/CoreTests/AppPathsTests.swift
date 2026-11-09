import Core
import Foundation
import Testing

struct AppPathsTests {
    @Test func pathsLiveUnderTheRoot() {
        let root = URL(filePath: "/tmp/verba-root", directoryHint: .isDirectory)
        let paths = AppPaths(root: root)

        #expect(paths.database.lastPathComponent == "verba.sqlite")
        #expect(paths.database.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
        #expect(paths.claudeWork.lastPathComponent == "claude-work")
        #expect(paths.claudeWork.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
        #expect(paths.backups.lastPathComponent == "backups")
        #expect(paths.backups.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
    }

    @Test func prepareFoldersCreatesAnEmptyClaudeWorkFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "AppPathsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppPaths(root: root)

        try paths.prepareFolders()
        try paths.prepareFolders()  // safe to call on every launch

        var isDirectory: ObjCBool = false
        #expect(
            FileManager.default.fileExists(
                atPath: paths.claudeWork.path(percentEncoded: false), isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: paths.claudeWork.path(percentEncoded: false)).isEmpty)
        #expect(FileManager.default.fileExists(atPath: paths.backups.path(percentEncoded: false)))
    }
}
