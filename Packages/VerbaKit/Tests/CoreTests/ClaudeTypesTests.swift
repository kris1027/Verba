import Core
import Foundation
import Testing

struct LessonRequestTests {
    private let polish = try! LanguageTag("pl")  // swiftlint:disable:this force_try
    private let spanish = try! LanguageTag("es")  // swiftlint:disable:this force_try

    private func request(_ hint: String?) throws(ValidationError) -> LessonRequest {
        try LessonRequest(courseID: CourseID(), nativeLanguage: polish, targetLanguage: spanish, topicHint: hint)
    }

    @Test func hintIsTrimmed() throws {
        #expect(try request("  past tense \n").topicHint == "past tense")
    }

    @Test(arguments: [nil, "", "   ", "\n\t"])
    func emptyHintBecomesNil(hint: String?) throws {
        #expect(try request(hint).topicHint == nil)
    }

    @Test func hintOfExactly200CharactersIsAccepted() throws {
        let hint = String(repeating: "ą", count: 200)
        #expect(try request(hint).topicHint == hint)
    }

    @Test func hintOver200CharactersIsRejected() {
        #expect(throws: ValidationError.invalidTopicHint) {
            try request(String(repeating: "a", count: 201))
        }
    }

    @Test(arguments: ["food\nand drink", "food\r\ndrink"])
    func hintWithLineBreakIsRejected(hint: String) {
        #expect(throws: ValidationError.invalidTopicHint) {
            try request(hint)
        }
    }
}

struct ClaudePreferencesTests {
    @Test(
        arguments: [
            (nil, ClaudeModel.sonnet), ("sonnet", .sonnet), ("opus", .opus), ("haiku", .haiku), ("gpt", .sonnet),
            ("", .sonnet),
        ] as [(String?, ClaudeModel)])
    func savedModelFallsBackToSonnet(saved: String?, expected: ClaudeModel) {
        #expect(ClaudePreferences(savedModel: saved, savedPath: nil).model == expected)
    }

    @Test func emptyOrMissingPathMeansAutomatic() {
        #expect(ClaudePreferences(savedModel: nil, savedPath: nil).cliPath == nil)
        #expect(ClaudePreferences(savedModel: nil, savedPath: "").cliPath == nil)
    }

    @Test func savedPathBecomesFileURL() {
        let path = ClaudePreferences(savedModel: nil, savedPath: "/opt/bin/claude").cliPath
        #expect(path == URL(filePath: "/opt/bin/claude"))
    }

    @Test func keysMatchTheSpec() {
        #expect(ClaudePreferences.modelKey == "claude.model")
        #expect(ClaudePreferences.cliPathKey == "claude.cliPath")
    }
}

struct ClaudeErrorTests {
    static let allCases: [ClaudeError] = [
        .notInstalled, .customPathInvalid(path: "/x"), .versionTooOld(found: "2.0.0", minimum: "2.1.325"),
        .versionUnreadable, .notLoggedIn, .usageLimitReached, .timedOut(seconds: 120), .cancelled,
        .invalidReply(reason: "secret reason"), .failed(reason: "secret reason"),
    ]

    @Test(arguments: allCases)
    func everyCaseHasItsOwnMessage(error: ClaudeError) throws {
        let message = try #require(error.errorDescription)
        #expect(!message.isEmpty)
        #expect(!message.contains("secret reason"))
        let others = Self.allCases.filter { $0 != error }.compactMap(\.errorDescription)
        #expect(!others.contains(message))
    }

    @Test func messagesCarryTheirValues() {
        let old = ClaudeError.versionTooOld(found: "2.0.1", minimum: "2.1.325").errorDescription ?? ""
        #expect(old.contains("2.0.1") && old.contains("2.1.325"))
        #expect(ClaudeError.timedOut(seconds: 120).errorDescription?.contains("120") == true)
    }

    @Test func requireReadyUnwrapsOrThrows() throws {
        let path = URL(filePath: "/bin/claude")
        let ready = try ClaudeStatus.ready(version: "2.1.325", path: path).requireReady()
        #expect(ready.version == "2.1.325" && ready.path == path)
        #expect(throws: ClaudeError.notLoggedIn) {
            try ClaudeStatus.problem(.notLoggedIn).requireReady()
        }
    }

    @Test func topicHintErrorHasAMessage() {
        #expect(ValidationError.invalidTopicHint.errorDescription?.isEmpty == false)
    }
}
