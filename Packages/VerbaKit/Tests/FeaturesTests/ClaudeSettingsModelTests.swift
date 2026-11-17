import AppKit
import Core
import Foundation
import SwiftUI
import Testing

@testable import Features

@MainActor
struct ClaudeSettingsModelTests {
    private let path = URL(filePath: "/Users/t/.local/bin/claude")

    @Test func readyStatusShowsVersionAndPath() async {
        let model = ClaudeSettingsModel(
            connection: FakeClaudeConnection(statuses: [.ready(version: "2.1.325", path: path)]))
        #expect(model.status == .checking)
        await model.loadStatus()
        #expect(model.statusText == "Ready, Claude Code 2.1.325")
        #expect(model.pathInUse == "/Users/t/.local/bin/claude")
    }

    @Test(arguments: [
        ClaudeError.notInstalled, .customPathInvalid(path: "/x"), .versionTooOld(found: "2.0.0", minimum: "2.1.325"),
        .versionUnreadable, .notLoggedIn, .failed(reason: "private detail"),
    ])
    func problemShowsTheErrorMessage(error: ClaudeError) async {
        let model = ClaudeSettingsModel(connection: FakeClaudeConnection(statuses: [.problem(error)]))
        await model.loadStatus()
        #expect(model.statusText == error.errorDescription)
        #expect(!model.statusText.contains("private detail"))
        #expect(model.pathInUse == nil)
    }

    @Test func checkAgainRefreshesTheCache() async {
        let connection = FakeClaudeConnection(statuses: [
            .ready(version: "2.1.325", path: path), .problem(.notLoggedIn),
        ])
        let model = ClaudeSettingsModel(connection: connection)
        await model.loadStatus()
        await model.loadStatus()
        #expect(await connection.statusChecks == 1)
        await model.checkAgain()
        #expect(await connection.statusChecks == 2)
        #expect(model.status == .problem(message: ClaudeError.notLoggedIn.errorDescription ?? ""))
    }

    @Test func testPromptShowsSecondsAndModel() async {
        let connection = FakeClaudeConnection(
            statuses: [.ready(version: "2.1.325", path: path)],
            testResult: .success(TestReply(model: "claude-haiku-4-5", durationMs: 2345)))
        let model = ClaudeSettingsModel(connection: connection)
        await model.sendTestPrompt()
        let seconds = 2.345.formatted(.number.precision(.fractionLength(1)))
        #expect(model.test == .succeeded(message: "Reply received in \(seconds) s from claude-haiku-4-5"))
    }

    @Test func testPromptFailureShowsTheErrorMessage() async {
        let connection = FakeClaudeConnection(
            statuses: [.ready(version: "2.1.325", path: path)], testResult: .failure(.usageLimitReached))
        let model = ClaudeSettingsModel(connection: connection)
        await model.sendTestPrompt()
        #expect(model.test == .failed(message: ClaudeError.usageLimitReached.errorDescription ?? ""))
    }

    @Test func testButtonIsDisabledWhileATestRuns() async throws {
        let connection = FakeClaudeConnection(
            statuses: [.ready(version: "2.1.325", path: path)],
            testResult: .success(TestReply(model: "Claude", durationMs: 100)))
        await connection.holdTestPrompt()
        let model = ClaudeSettingsModel(connection: connection)
        let running = Task { await model.sendTestPrompt() }
        while await connection.testPrompts == 0 { await Task.yield() }
        #expect(model.isTesting)
        await model.sendTestPrompt()  // ignored while running
        #expect(await connection.testPrompts == 1)
        await connection.releaseTestPrompt()
        await running.value
        #expect(!model.isTesting)
    }

    @Test func settingsViewBuildsWithAndWithoutAConnection() {
        let connection = FakeClaudeConnection(statuses: [.ready(version: "2.1.325", path: path)])
        let withConnection = NSHostingView(rootView: SettingsView().environment(\.claudeConnection, connection))
        let without = NSHostingView(rootView: SettingsView())
        #expect(withConnection.fittingSize.width >= 480)
        #expect(without.fittingSize.width >= 480)
    }

    @Test func everyModelHasATitleAndTradeoff() {
        #expect(ClaudeModel.allCases.map(\.title) == ["Sonnet", "Opus", "Haiku"])
        #expect(ClaudeModel.allCases.allSatisfy { !$0.tradeoff.isEmpty })
    }
}

struct FakeClaudeTests {
    @Test func fakeConnectionCachesOnlyReady() async {
        let path = URL(filePath: "/c")
        let connection = FakeClaudeConnection(statuses: [
            .problem(.notLoggedIn), .ready(version: "2.1.325", path: path),
        ])
        #expect(await connection.status(refresh: false) == .problem(.notLoggedIn))
        #expect(await connection.status(refresh: false) == .ready(version: "2.1.325", path: path))
        #expect(await connection.status(refresh: false) == .ready(version: "2.1.325", path: path))
        #expect(await connection.statusChecks == 2)
    }

    @Test func fakeWriterReturnsResultsInOrder() async throws {
        let request = try LessonRequest(
            courseID: CourseID(), nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"))
        let writer = FakeLessonWriter(results: [.failure(.timedOut(seconds: 120)), .failure(.cancelled)])
        await #expect(throws: ClaudeError.timedOut(seconds: 120)) { try await writer.writeLesson(request) }
        await #expect(throws: ClaudeError.cancelled) { try await writer.writeLesson(request) }
        #expect(await writer.requests == [request, request])
    }
}
