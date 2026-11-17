import Core
import Foundation
import Testing

@testable import ClaudeBridge

/// Runs the real `claude` CLI with your login. Off by default; run with
/// `VERBA_LIVE_CLAUDE=1 swift test --package-path Packages/VerbaKit --filter LiveClaudeTests`.
/// It uses a little of your plan (haiku), so run it after each Claude Code update you install.
@Suite(
    .enabled(if: ProcessInfo.processInfo.environment["VERBA_LIVE_CLAUDE"] == "1"),
    .serialized,
    .timeLimit(.minutes(5)))
struct LiveClaudeTests {
    private let folder: ScriptFolder
    private let paths: AppPaths
    private let cli: ClaudeCLI

    init() throws {
        folder = try ScriptFolder()
        paths = AppPaths(root: try folder.folder("data"))
        cli = ClaudeCLI(paths: paths) { ClaudePreferences(model: .haiku) }
    }

    @Test func statusIsReady() async throws {
        let status = await cli.status(refresh: false)
        let ready = try status.requireReady()
        #expect(CLIVersion(firstMatchIn: ready.version).map { $0 >= ClaudeCLI.minimumVersion } == true)
    }

    @Test func testPromptReplies() async throws {
        let reply = try await cli.sendTestPrompt()
        #expect(!reply.model.isEmpty)
        #expect(reply.durationMs > 0)
        try expectWorkFolderEmpty()
    }

    @Test func haikuWritesALessonThatValidates() async throws {
        let request = try LessonRequest(
            courseID: CourseID(), nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"),
            topicHint: "greetings")
        let generated = try await cli.writeLesson(request)
        try generated.lesson.validate()
        #expect((4...6).contains(generated.lesson.exercises.count))
        #expect(generated.lesson.courseID == request.courseID)
        #expect(generated.generation.promptVersion == "lesson-v1")
        #expect(!generated.generation.rawReply.isEmpty)
        #expect(generated.generation.model?.contains("haiku") == true)
        try expectWorkFolderEmpty()
    }

    private func expectWorkFolderEmpty() throws {
        let contents = try FileManager.default.contentsOfDirectory(atPath: paths.claudeWork.path)
        #expect(contents.isEmpty, "claude-work holds \(contents)")
    }
}
