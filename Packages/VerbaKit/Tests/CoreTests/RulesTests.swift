import Core
import Foundation
import Testing

/// A small seeded generator so shuffles are repeatable (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

private func part(
    _ id: ExercisePartID = ExercisePartID(), isCorrect: Bool? = nil, correctPosition: Int? = nil,
    matchKey: String? = nil
) -> ExercisePart {
    ExercisePart(
        id: id, exerciseID: ExerciseID(), sourcePosition: 0, text: "x", displayPosition: nil, isCorrect: isCorrect,
        correctPosition: correctPosition, matchKey: matchKey)
}

private func attempt(number: Int, grade: Grade) -> Attempt {
    Attempt(
        id: AttemptID(), exerciseID: ExerciseID(), attemptNumber: number, response: .text("x"), grade: grade,
        feedback: "", gradedBy: .app, answeredAt: .now)
}

struct LessonStateTests {
    @Test(arguments: [
        (LessonState.ready, 3, 1, LessonState.inProgress),
        (.ready, 3, 3, .completed),
        (.ready, 1, 1, .completed),
        (.ready, 3, 0, .ready),
        (.inProgress, 3, 2, .inProgress),
        (.inProgress, 3, 3, .completed),
        (.inProgress, 3, 0, .inProgress),
        (.completed, 3, 3, .completed),
        (.completed, 3, 1, .completed),
        (.completed, 3, 0, .completed),
    ])
    func advancing(from: LessonState, exercises: Int, answered: Int, expected: LessonState) {
        #expect(from.advanced(exerciseCount: exercises, answeredCount: answered) == expected)
    }
}

struct LessonScoreTests {
    @Test func onlyAFirstCorrectAttemptCounts() {
        let score = LessonScore(exercises: [
            (ExerciseID(), [attempt(number: 1, grade: .correct)]),
            (ExerciseID(), [attempt(number: 1, grade: .wrong), attempt(number: 2, grade: .correct)]),
            (ExerciseID(), [attempt(number: 1, grade: .partlyCorrect)]),
            (ExerciseID(), []),
        ])
        #expect(score.firstTryCorrect == 1)
        #expect(score.exerciseCount == 4)
    }
}

struct OptionShufflerTests {
    private let parts = (0..<4).map { _ in part() }

    @Test func theSameSeedGivesTheSamePermutation() {
        var first = SeededGenerator(state: 42)
        var second = SeededGenerator(state: 42)
        let one = OptionShuffler().displayOrder(for: .choice, parts: parts, using: &first)
        let two = OptionShuffler().displayOrder(for: .choice, parts: parts, using: &second)
        #expect(one == two)
        #expect(Set(one) == Set(parts.map(\.id)))
        #expect(one.count == parts.count)
    }

    @Test func everyOptionReachesEveryPosition() {
        var seen = Set<[Int]>()
        for seed in 0..<1000 {
            var generator = SeededGenerator(state: UInt64(seed))
            let order = OptionShuffler().displayOrder(for: .choice, parts: parts, using: &generator)
            for (position, id) in order.enumerated() {
                seen.insert([parts.firstIndex { $0.id == id } ?? -1, position])
            }
        }
        #expect(seen.count == parts.count * parts.count)
    }

    @Test(arguments: [ExerciseKind.fillBlank, .translate])
    func kindsThatShowNoPartsHaveNoOrder(kind: ExerciseKind) {
        var generator = SeededGenerator(state: 1)
        #expect(OptionShuffler().displayOrder(for: kind, parts: parts, using: &generator).isEmpty)
    }
}

struct GraderTests {
    private let right = part(isCorrect: true)
    private let wrong = part(isCorrect: false)

    @Test func choice() {
        let parts = [right, wrong]
        #expect(Grader.grade(.choice(right.id), kind: .choice, parts: parts) == .correct)
        #expect(Grader.grade(.choice(wrong.id), kind: .choice, parts: parts) == .wrong)
    }

    @Test func reorderComparesAgainstCorrectPositions() {
        let first = part(correctPosition: 0)
        let second = part(correctPosition: 1)
        #expect(Grader.grade(.order([first.id, second.id]), kind: .reorder, parts: [second, first]) == .correct)
        #expect(Grader.grade(.order([second.id, first.id]), kind: .reorder, parts: [second, first]) == .wrong)
    }

    @Test func matchNeedsEveryPairToShareAKey() {
        let (oneA, oneB, twoA, twoB) = (
            part(matchKey: "1"), part(matchKey: "1"), part(matchKey: "2"), part(matchKey: "2")
        )
        let parts = [oneA, oneB, twoA, twoB]
        #expect(
            Grader.grade(.pairs([[oneA.id, oneB.id], [twoA.id, twoB.id]]), kind: .match, parts: parts) == .correct)
        #expect(Grader.grade(.pairs([[oneA.id, twoA.id], [oneB.id, twoB.id]]), kind: .match, parts: parts) == .wrong)
    }

    @Test(arguments: [ExerciseKind.fillBlank, .translate])
    func kindsTheAppCannotJudgeHaveNoGrade(kind: ExerciseKind) {
        #expect(Grader.grade(.text("x"), kind: kind, parts: [right]) == nil)
    }

    @Test func aResponseThatFitsIsAccepted() throws {
        try Grader.validate(.text("hola"), kind: .translate, parts: [right])
        try Grader.validate(.choice(right.id), kind: .choice, parts: [right, wrong])
        try Grader.validate(.order([wrong.id, right.id]), kind: .reorder, parts: [right, wrong])
        try Grader.validate(.pairs([[right.id, wrong.id]]), kind: .match, parts: [right, wrong])
    }

    @Test func aResponseThatDoesNotFitIsRejected() {
        let other = ExercisePartID()
        let cases: [(AttemptResponse, ExerciseKind)] = [
            (.text("x"), .choice),
            (.choice(other), .choice),
            (.choice(right.id), .translate),
            (.order([right.id]), .reorder),
            (.order([right.id, right.id]), .reorder),
            (.order([right.id, other]), .reorder),
            (.pairs([[right.id]]), .match),
            (.pairs([[right.id, other]]), .match),
            (.pairs([[right.id, wrong.id], [right.id, wrong.id]]), .match),
        ]
        for (response, kind) in cases {
            #expect(throws: ValidationError.invalidResponse) {
                try Grader.validate(response, kind: kind, parts: [right, wrong])
            }
        }
    }
}

struct ErrorMessageTests {
    @Test(arguments: [
        ValidationError.invalidLanguageTag, .sameLanguage, .emptyLesson, .invalidExercise(position: 0, reason: "r"),
        .invalidDisplayOrder, .invalidResponse,
    ])
    func everyValidationErrorHasAMessage(error: ValidationError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test(arguments: [
        StoreError.duplicateCourse, .notFound, .archived, .displayOrderAlreadySet, .invalid(.emptyLesson),
        .unavailable(reason: "r"),
    ])
    func everyStoreErrorHasAMessage(error: StoreError) {
        #expect(error.errorDescription?.isEmpty == false)
    }
}

struct IDTests {
    @Test func encodesAsABareUUID() throws {
        let id = LessonID()
        let data = try JSONEncoder().encode(id)
        #expect(try JSONDecoder().decode(UUID.self, from: data) == id.rawValue)
        #expect(try JSONDecoder().decode(LessonID.self, from: data) == id)
    }
}
