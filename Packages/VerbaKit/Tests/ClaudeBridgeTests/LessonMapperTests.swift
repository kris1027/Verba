import Core
import Foundation
import Testing

@testable import ClaudeBridge

struct LessonMapperTests {
    private let courseID = CourseID()

    private func map(_ structured: [String: Any]?, result: String? = "text") throws -> Result<
        MappedLesson, ReplyProblem
    > {
        let request = try LessonRequest(
            courseID: courseID, nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"))
        let output = try CLIOutput.result(structured: structured, result: result).get()
        let cliResult = try CLIResult.decode(stdout: output.stdout)
        return try LessonMapper.map(
            cliResult, request: request, prompt: LessonPrompt.make(for: request), durationMs: 42)
    }

    @Test func eachKindMapsItsParts() throws {
        let mapped = try map(SampleLesson.reply()).get()
        let exercises = mapped.lesson.lesson.exercises
        #expect(exercises[0].parts.map(\.text) == ["Hola", "Adiós", "Gracias"])
        #expect(exercises[0].parts.map(\.isCorrect) == [true, false, false])
        #expect(exercises[1].parts.map(\.text) == ["Buenos", "buenos"])
        #expect(exercises[1].parts.allSatisfy { $0.isCorrect == true })
        #expect(exercises[1].explanation == nil)  // whitespace only becomes nil
        #expect(exercises[2].parts.map(\.text) == ["Yo", "soy", "Ana"])
        #expect(exercises[2].parts.map(\.correctPosition) == [0, 1, 2])
        #expect(exercises[3].parts.map(\.text) == ["uno", "one", "dos", "two"])
        #expect(exercises[3].parts.map(\.matchKey) == ["p0", "p0", "p1", "p1"])
        #expect(exercises[0].explanation == "Hola means hello.")
        #expect(mapped.lesson.lesson.title == "Greetings")
        #expect(mapped.lesson.lesson.explanation == "Say **hola**.")
        #expect(mapped.lesson.generation.durationMs == 42)
    }

    @Test func emptyResultTextSavesStructuredOutputWithSortedKeys() throws {
        let mapped = try map(
            SampleLesson.reply([SampleLesson.reorder, SampleLesson.reorder, SampleLesson.reorder, SampleLesson.reorder]
            ), result: ""
        ).get()
        let raw = mapped.lesson.generation.rawReply
        #expect(raw.hasPrefix(#"{"exercises":[{"explanation":"Subject first.","kind":"reorder""#))
    }

    @Test func modelIsTheKeyWithMostOutputTokensTiesAlphabetical() throws {
        let tie = try CLIResult.decode(stdout: CLIOutput.result(modelUsage: ["b": 5, "a": 5, "c": 1]).get().stdout)
        #expect(tie.model == "a")
        let none = try CLIResult.decode(stdout: CLIOutput.result(modelUsage: [:]).get().stdout)
        #expect(none.model == nil)
    }

    static func badReply(_ name: String) -> [String: Any]? {
        let sample = SampleLesson.self
        let base = [sample.choice, sample.fillBlank, sample.reorder, sample.match]
        let twoCorrect = sample.replacing(
            sample.choice, "choices",
            with: [
                ["text": "a", "isCorrect": true], ["text": "b", "isCorrect": true], ["text": "c", "isCorrect": false],
            ])
        let twoOptions = sample.replacing(
            sample.choice, "choices", with: [["text": "a", "isCorrect": true], ["text": "b", "isCorrect": false]])
        let translate = sample.replacing(sample.fillBlank, "kind", with: "translate")
        let replies: [String: [String: Any]?] = [
            "no structured output": nil,
            "three exercises": sample.reply(Array(base.prefix(3))),
            "seven exercises": sample.reply(base + base.prefix(3)),
            "translate kind": sample.reply([sample.choice, translate, sample.reorder, sample.match]),
            "two correct options": sample.reply([twoCorrect, sample.fillBlank, sample.reorder, sample.match]),
            "two options": sample.reply([twoOptions, sample.fillBlank, sample.reorder, sample.match]),
            "81 character title": sample.reply(title: String(repeating: "x", count: 81)),
            "blank title": sample.reply(title: "  \n"),
            "reorder without tokens": sample.reply([
                sample.choice, sample.fillBlank, sample.replacing(sample.reorder, "tokens", with: nil), sample.match,
            ]),
            "choice without choices": sample.reply([
                sample.replacing(sample.choice, "choices", with: nil), sample.fillBlank, sample.reorder, sample.match,
            ]),
            "empty answers": sample.reply([
                sample.choice, sample.replacing(sample.fillBlank, "answers", with: [String]()), sample.reorder,
                sample.match,
            ]),
            "one token": sample.reply([
                sample.choice, sample.fillBlank, sample.replacing(sample.reorder, "tokens", with: ["solo"]),
                sample.match,
            ]),
            "empty token": sample.reply([
                sample.choice, sample.fillBlank, sample.replacing(sample.reorder, "tokens", with: ["a", " "]),
                sample.match,
            ]),
            "missing prompt": sample.reply([
                sample.replacing(sample.choice, "prompt", with: nil), sample.fillBlank, sample.reorder, sample.match,
            ]),
        ]
        return replies[name] ?? nil
    }

    @Test(arguments: [
        "no structured output", "three exercises", "seven exercises", "translate kind", "two correct options",
        "two options", "81 character title", "blank title", "reorder without tokens", "choice without choices",
        "empty answers", "one token", "empty token", "missing prompt",
    ])
    func unusableRepliesAreRejected(name: String) throws {
        if name != "no structured output" { #expect(Self.badReply(name) != nil, "unknown case \(name)") }
        guard case .failure(let problem) = try map(Self.badReply(name)) else {
            Issue.record("\(name) was accepted")
            return
        }
        #expect(!problem.reason.isEmpty)
    }

    @Test func lopsidedOptionsAreFlaggedButAccepted() throws {
        let lopsided = SampleLesson.replacing(
            SampleLesson.choice, "choices",
            with: [
                ["text": "a", "isCorrect": true], ["text": "a very long option", "isCorrect": false],
                ["text": "b", "isCorrect": false],
            ])
        let mapped = try map(
            SampleLesson.reply([SampleLesson.match, lopsided, SampleLesson.reorder, SampleLesson.choice])
        ).get()
        #expect(mapped.unfairChoicePositions == [1])
        #expect(try map(SampleLesson.reply()).get().unfairChoicePositions.isEmpty)
    }
}

struct LessonSchemaTests {
    private func schema() throws -> [String: Any] {
        let text = try Prompt.resource("lesson-v1", "schema", "json")
        return try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    private func properties(_ object: [String: Any]?) throws -> [String: [String: Any]] {
        try #require(object?["properties"] as? [String: [String: Any]])
    }

    private func encodedKeys<T: Encodable>(_ value: T) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        return Set(try #require(object).keys)
    }

    @Test func schemaAndReplyTypeAgreeOnEveryFieldName() throws {
        let choice = LessonReply.Choice(text: "a", isCorrect: true)
        let pair = LessonReply.Pair(left: "l", right: "r")
        let exercise = LessonReply.Exercise(
            kind: .choice, prompt: "p", explanation: "e", choices: [choice], answers: ["a"], tokens: ["t"],
            pairs: [pair])
        let reply = LessonReply(title: "t", topic: "t", explanation: "e", exercises: [exercise])

        let top = try properties(schema())
        let item = try #require(top["exercises"]?["items"] as? [String: Any])
        let fields = try properties(item)
        #expect(Set(top.keys) == (try encodedKeys(reply)))
        #expect(Set(fields.keys) == (try encodedKeys(exercise)))
        #expect(Set(try properties(fields["choices"]?["items"] as? [String: Any]).keys) == (try encodedKeys(choice)))
        #expect(Set(try properties(fields["pairs"]?["items"] as? [String: Any]).keys) == (try encodedKeys(pair)))
        #expect(fields["kind"]?["enum"] as? [String] == ["choice", "fillBlank", "reorder", "match"])
    }

    @Test func schemaLimitsMatchTheMapperLimits() throws {
        typealias Limits = LessonReply.Limits
        let top = try properties(schema())
        #expect(top["title"]?["maxLength"] as? Int == Limits.title)
        #expect(top["topic"]?["maxLength"] as? Int == Limits.topic)
        #expect(top["explanation"]?["maxLength"] as? Int == Limits.explanation)
        #expect(top["exercises"]?["minItems"] as? Int == Limits.exercises.lowerBound)
        #expect(top["exercises"]?["maxItems"] as? Int == Limits.exercises.upperBound)
        let fields = try properties(top["exercises"]?["items"] as? [String: Any])
        #expect(fields["prompt"]?["maxLength"] as? Int == Limits.prompt)
        #expect(fields["explanation"]?["maxLength"] as? Int == Limits.exerciseExplanation)
        #expect(fields["choices"]?["minItems"] as? Int == Limits.choices.lowerBound)
        #expect(fields["choices"]?["maxItems"] as? Int == Limits.choices.upperBound)
    }

    @Test func everyObjectForbidsExtraProperties() throws {
        func check(_ node: Any) {
            if let object = node as? [String: Any] {
                if object["type"] as? String == "object" {
                    #expect(object["additionalProperties"] as? Bool == false)
                }
                object.values.forEach(check)
            } else if let array = node as? [Any] {
                array.forEach(check)
            }
        }
        check(try schema())
    }
}

struct PromptTests {
    @Test func renderIsOneLeftToRightPass() {
        let rendered = Prompt.render("A {{x}} B {{y}} {{unknown}}", values: ["x": "{{y}}", "y": "2"])
        #expect(rendered == "A {{y}} B 2 {{unknown}}")
    }

    @Test func lessonPromptNamesBothLanguagesAndTheTopic() throws {
        let request = try LessonRequest(
            courseID: CourseID(), nativeLanguage: LanguageTag("pl"), targetLanguage: LanguageTag("es"),
            topicHint: #"the "past" tense {{nativeLanguage}}"#)
        let prompt = try LessonPrompt.make(for: request)
        #expect(prompt.version == "lesson-v1")
        #expect(prompt.user.contains("Native language (for every explanation and instruction): Polish (pl)"))
        #expect(prompt.user.contains("Target language (the language being taught): Spanish (es)"))
        #expect(prompt.user.contains(#"Topic requested by the learner: "the 'past' tense {{nativeLanguage}}""#))
        #expect(!prompt.system.isEmpty && !prompt.schema.isEmpty)
    }

    @Test func noHintLetsClaudeChoose() {
        #expect(LessonPrompt.topicLine(nil) == "Choose a useful topic for a beginner.")
    }

    @Test func testPromptLoads() throws {
        let prompt = try Prompt.load("test-v1")
        #expect(prompt.user == "Reply with the word ready.")
    }

    @Test func missingPromptIsFailed() {
        #expect(throws: ClaudeError.self) { try Prompt.load("nope-v1") }
    }
}
