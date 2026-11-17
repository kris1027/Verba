import Core
import Foundation
import Synchronization
import Testing

@testable import ClaudeBridge

struct CLILocatorTests {
    private let folder: ScriptFolder

    init() throws {
        folder = try ScriptFolder()
    }

    private func locator(_ searchPaths: [URL], lookup: ShellLookup? = nil, lookups: Counter? = nil) -> CLILocator {
        CLILocator(searchPaths: searchPaths) {
            lookups?.increment()
            return lookup
        }
    }

    @Test func savedExecutablePathWins() async throws {
        let saved = try folder.script("saved", "exit 0")
        let known = try folder.script("known", "exit 0")
        let location = try await locator([known]).locate(customPath: saved)
        #expect(location == CLILocation(url: saved, loginPATH: nil))
    }

    @Test func savedPathThatIsNotExecutableGivesCustomPathInvalidWithoutSearching() async throws {
        let plain = folder.url.appending(path: "plain")
        try "x".write(to: plain, atomically: true, encoding: .utf8)
        let known = try folder.script("known", "exit 0")
        let lookups = Counter()
        await #expect(throws: ClaudeError.customPathInvalid(path: plain.path(percentEncoded: false))) {
            try await locator([known], lookups: lookups).locate(customPath: plain)
        }
        await #expect(throws: ClaudeError.self) {
            try await locator([known]).locate(customPath: folder.url)  // a folder is not a program
        }
        #expect(lookups.value == 0)
    }

    @Test func firstExecutableKnownPathIsUsed() async throws {
        let missing = folder.url.appending(path: "missing")
        let known = try folder.script("known", "exit 0")
        let lookups = Counter()
        let location = try await locator([missing, known], lookups: lookups).locate(customPath: nil)
        #expect(location.url == known)
        #expect(lookups.value == 0)
    }

    @Test func shellLookupIsTheLastResort() async throws {
        let found = try folder.script("found", "exit 0")
        let location = try await locator([], lookup: ShellLookup(path: found, loginPATH: "/a:/b"))
            .locate(customPath: nil)
        #expect(location == CLILocation(url: found, loginPATH: "/a:/b"))
    }

    @Test func nothingFoundGivesNotInstalled() async {
        await #expect(throws: ClaudeError.notInstalled) {
            try await locator([folder.url.appending(path: "missing")]).locate(customPath: nil)
        }
    }

    @Test func shellLookupUsesTheLastNonEmptyLine() throws {
        let found = try folder.script("claude", "exit 0")
        let stdout = Data("Welcome to zsh!\nnvm loaded\n\(found.path(percentEncoded: false))\n\n".utf8)
        let stderr = Data("some warning\n/usr/bin:/opt/homebrew/bin".utf8)
        let lookup = CLILocator.parseShellLookup(stdout: stdout, stderr: stderr)
        #expect(lookup == ShellLookup(path: found, loginPATH: "/usr/bin:/opt/homebrew/bin"))
    }

    @Test(arguments: ["claude: aliased to /x/claude", "claude", "/does/not/exist/claude", ""])
    func shellLookupRejectsAnythingButAnExecutablePath(stdout: String) {
        #expect(CLILocator.parseShellLookup(stdout: Data(stdout.utf8), stderr: Data()) == nil)
    }

    @Test func defaultSearchPathsFollowTheSpecOrder() {
        let paths = CLILocator.defaultSearchPaths(home: URL(filePath: "/Users/t")).map {
            $0.path(percentEncoded: false)
        }
        #expect(
            paths == [
                "/Users/t/.local/bin/claude", "/Users/t/.claude/local/claude", "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude",
            ])
    }
}

/// A thread safe counter for closures.
final class Counter: Sendable {
    private let count = Mutex(0)
    func increment() { count.withLock { $0 += 1 } }
    var value: Int { count.withLock { $0 } }
}

struct StatusCheckTests {
    @Test(arguments: ["2.1.325 (Claude Code)", "2.2.0", "3.0.0-beta.1", "v2.1.400\n"])
    func supportedVersionsAreReady(output: String) async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(version: output)
        let status = await harness.cli.status(refresh: false)
        guard case .ready(let version, let path) = status else {
            Issue.record("Expected ready, got \(status)")
            return
        }
        #expect(version == CLIVersion(firstMatchIn: output)?.description)
        #expect(path == harness.binary)
    }

    @Test func olderVersionIsTooOld() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(version: "2.1.324 (Claude Code)")
        #expect(
            await harness.cli.status(refresh: false)
                == .problem(.versionTooOld(found: "2.1.324", minimum: "2.1.325")))
    }

    @Test(arguments: ["hello", "", "2.1"])
    func outputWithoutAVersionIsUnreadable(output: String) async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(version: output)
        #expect(await harness.cli.status(refresh: false) == .problem(.versionUnreadable))
    }

    @Test func versionComparesAsIntegers() {
        let version = { CLIVersion(firstMatchIn: $0)! }  // swiftlint:disable:this force_unwrapping
        #expect(version("2.1.325") > version("2.1.99"))
        #expect(version("10.0.0") > version("9.9.9"))
        #expect(version("2.1.325-beta") == version("2.1.325"))
    }

    @Test func signedOutIsNotLoggedIn() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(auth: #"{"loggedIn": false}"#, authExit: 1)
        #expect(await harness.cli.status(refresh: false) == .problem(.notLoggedIn))
    }

    @Test func signedInIsReadEvenWithANonZeroExit() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(auth: #"{"loggedIn": true}"#, authExit: 1)
        #expect(await harness.cli.status(refresh: false) == .ready(version: "2.1.325", path: harness.binary))
    }

    @Test(arguments: ["Not logged in", #"{"authMethod": "none"}"#, "[]"])
    func authOutputWithoutLoggedInIsFailed(output: String) async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(auth: output)
        guard case .problem(.failed) = await harness.cli.status(refresh: false) else {
            Issue.record("Expected failed")
            return
        }
    }

    @Test func statusCommandsRunInClaudeWorkWithTenSecondLimit() async throws {
        let harness = try BridgeHarness()
        _ = await harness.cli.status(refresh: false)
        let commands = await harness.runner.commands
        #expect(commands.map(\.arguments) == [["--version"], ["auth", "status", "--json"]])
        #expect(commands.allSatisfy { $0.workingDirectory == harness.paths.claudeWork && $0.timeLimit == .seconds(10) })
        #expect(commands.allSatisfy { $0.standardInput == nil && $0.executable == harness.binary })
    }

    @Test func missingWorkFolderIsCreated() async throws {
        let harness = try BridgeHarness()
        #expect(!FileManager.default.fileExists(atPath: harness.paths.claudeWork.path))
        _ = await harness.cli.status(refresh: false)
        #expect(FileManager.default.fileExists(atPath: harness.paths.claudeWork.path))
    }
}

struct StatusCacheTests {
    @Test func concurrentCallersShareOneCheck() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(statusDelay: .milliseconds(200))
        let cli = harness.cli
        async let first = cli.status(refresh: false)
        async let second = cli.status(refresh: false)
        let (firstStatus, secondStatus) = await (first, second)
        #expect(firstStatus == secondStatus)
        #expect(await harness.runner.versionChecks == 1)
    }

    @Test func readyIsCachedAndRefreshChecksAgain() async throws {
        let harness = try BridgeHarness()
        _ = await harness.cli.status(refresh: false)
        _ = await harness.cli.status(refresh: false)
        #expect(await harness.runner.versionChecks == 1)
        _ = await harness.cli.status(refresh: true)
        #expect(await harness.runner.versionChecks == 2)
    }

    @Test func problemIsNeverCached() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(auth: #"{"loggedIn": false}"#)
        #expect(await harness.cli.status(refresh: false) == .problem(.notLoggedIn))
        // Signing in from Terminal fixes the next call without Check again.
        await harness.runner.set(auth: #"{"loggedIn": true}"#)
        #expect(await harness.cli.status(refresh: false) == .ready(version: "2.1.325", path: harness.binary))
        #expect(await harness.runner.versionChecks == 2)
    }

    @Test func invalidateDuringACheckStopsItsResultBeingStored() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(statusDelay: .milliseconds(300))
        let cli = harness.cli
        async let first = cli.status(refresh: false)
        try await Task.sleep(for: .milliseconds(100))
        await harness.cli.invalidate()
        _ = await first
        await harness.runner.set(statusDelay: .zero)
        _ = await harness.cli.status(refresh: false)
        #expect(await harness.runner.versionChecks == 2)
    }

    @Test func cancellingOneWaitingCallerDoesNotCancelTheSharedCheck() async throws {
        let harness = try BridgeHarness()
        await harness.runner.set(statusDelay: .milliseconds(300))
        let cli = harness.cli
        let cancelled = Task { await cli.status(refresh: false) }
        let other = Task { await cli.status(refresh: false) }
        try await Task.sleep(for: .milliseconds(50))
        cancelled.cancel()
        #expect(await other.value == .ready(version: "2.1.325", path: harness.binary))
        #expect(await harness.runner.versionChecks == 1)
    }
}
