import Core
import Testing

struct NewLessonTests {
    private func lesson(_ exercises: [NewExercise]) throws -> NewLesson {
        try NewLesson(courseID: CourseID(), title: "T", topic: "T", explanation: "E", exercises: exercises)
    }

    private func exercise(_ kind: ExerciseKind, _ parts: [NewExercisePart]) -> NewExercise {
        NewExercise(kind: kind, prompt: "P", parts: parts)
    }

    private static func options(_ flags: [Bool?]) -> [NewExercisePart] {
        flags.map { NewExercisePart(text: "x", isCorrect: $0) }
    }

    private static func tokens(_ positions: [Int?]) -> [NewExercisePart] {
        positions.map { NewExercisePart(text: "x", correctPosition: $0) }
    }

    private static func pairs(_ keys: [String?]) -> [NewExercisePart] {
        keys.map { NewExercisePart(text: "x", matchKey: $0) }
    }

    @Test func noExercisesIsRejected() {
        #expect(throws: ValidationError.emptyLesson) {
            try lesson([])
        }
    }

    @Test(
        "Parts that fit their kind are accepted",
        arguments: [
            (ExerciseKind.choice, options([true, false])),
            (.choice, options([true, true, false, false, false, false])),
            (.fillBlank, options([true])),
            (.translate, options([true, true])),
            (.reorder, tokens([1, 0])),
            (.match, pairs(["a", "b", "a", "b"])),
        ])
    func validParts(kind: ExerciseKind, parts: [NewExercisePart]) throws {
        #expect(try lesson([exercise(kind, parts)]).exercises.count == 1)
    }

    @Test(
        "Parts that break their kind's rules are rejected",
        arguments: [
            (ExerciseKind.choice, options([true])),
            (.choice, options([true, false, false, false, false, false, false])),
            (.choice, options([false, false])),
            (.fillBlank, []),
            (.fillBlank, options([true, false])),
            (.translate, []),
            (.translate, options([nil])),
            (.reorder, tokens([0])),
            (.reorder, tokens([0, 0])),
            (.reorder, tokens([0, nil])),
            (.match, []),
            (.match, pairs(["a", "a", "b"])),
            (.match, pairs(["a", "a", "a", "a"])),
            (.match, pairs([nil, nil])),
        ])
    func invalidParts(kind: ExerciseKind, parts: [NewExercisePart]) {
        #expect {
            try lesson([exercise(.fillBlank, Self.options([true])), exercise(kind, parts)])
        } throws: { error in
            guard case ValidationError.invalidExercise(let position, _) = error else { return false }
            return position == 1
        }
    }

    @Test func kindsThatShowTheirPartsAreTheOnesTheAppShuffles() {
        #expect(ExerciseKind.allCases.filter(\.displaysParts) == [.choice, .reorder, .match])
    }
}
