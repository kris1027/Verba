import Core
import Foundation

/// A checked lesson plus the choice exercises whose options differ a lot in length (AC-16).
struct MappedLesson: Sendable, Hashable {
    var lesson: GeneratedLesson
    var unfairChoicePositions: [Int]
}

/// Turns a CLI result into Core values (AC-7), or says why the reply is unusable (AC-8).
/// Part order in the reply becomes `sourcePosition`; the bridge never shuffles.
enum LessonMapper {
    typealias Limits = LessonReply.Limits

    static func map(
        _ result: CLIResult, request: LessonRequest, prompt: Prompt, durationMs: Int
    ) -> Result<MappedLesson, ReplyProblem> {
        Result { () throws(ReplyProblem) -> MappedLesson in
            guard let structured = result.structuredOutput else { throw ReplyProblem("no structured_output") }
            let reply: LessonReply
            do {
                reply = try structured.decode(LessonReply.self)
            } catch {
                throw ReplyProblem("does not decode: \(error)")
            }
            let lesson = try makeLesson(reply, courseID: request.courseID)
            let generation = NewGeneration(
                kind: .lesson, model: result.model, promptVersion: prompt.version, rawReply: result.rawReply,
                durationMs: durationMs)
            return MappedLesson(
                lesson: GeneratedLesson(lesson: lesson, generation: generation),
                unfairChoicePositions: unfairChoicePositions(reply))
        }
    }

    static func makeLesson(_ reply: LessonReply, courseID: CourseID) throws(ReplyProblem) -> NewLesson {
        try requireText(reply.title, "title", limit: Limits.title)
        try requireText(reply.topic, "topic", limit: Limits.topic)
        try requireText(reply.explanation, "explanation", limit: Limits.explanation)
        guard Limits.exercises.contains(reply.exercises.count) else {
            throw ReplyProblem("has \(reply.exercises.count) exercises, not 4 to 6")
        }
        var exercises: [NewExercise] = []
        for (position, exercise) in reply.exercises.enumerated() {
            exercises.append(try makeExercise(exercise, position: position))
        }
        do {
            return try NewLesson(
                courseID: courseID, kind: .regular, title: reply.title, topic: reply.topic,
                explanation: reply.explanation, exercises: exercises)
        } catch {
            throw ReplyProblem("fails validation: \(error.errorDescription ?? String(describing: error))")
        }
    }

    private static func makeExercise(
        _ exercise: LessonReply.Exercise, position: Int
    ) throws(ReplyProblem) -> NewExercise {
        let label = "exercise \(position)"
        try requireText(exercise.prompt, "\(label) prompt", limit: Limits.prompt)
        guard exercise.explanation.count <= Limits.exerciseExplanation else {
            throw ReplyProblem("\(label) explanation is over \(Limits.exerciseExplanation) characters")
        }
        let explanation = exercise.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = try makeParts(exercise, label: label)
        return NewExercise(
            kind: coreKind(exercise.kind), prompt: exercise.prompt,
            explanation: explanation.isEmpty ? nil : explanation,
            parts: parts)
    }

    private static func makeParts(
        _ exercise: LessonReply.Exercise, label: String
    ) throws(ReplyProblem) -> [NewExercisePart] {
        switch exercise.kind {
        case .choice:
            let choices = try require(exercise.choices, "choices", label)
            guard Limits.choices.contains(choices.count) else {
                throw ReplyProblem("\(label) has \(choices.count) options, not 3 or 4")
            }
            guard choices.count(where: \.isCorrect) == 1 else {
                throw ReplyProblem("\(label) does not have exactly one correct option")
            }
            return try choices.map { choice throws(ReplyProblem) in
                try requireText(choice.text, "\(label) option", limit: Limits.part)
                return NewExercisePart(text: choice.text, isCorrect: choice.isCorrect)
            }
        case .fillBlank:
            return try require(exercise.answers, "answers", label).map { answer throws(ReplyProblem) in
                try requireText(answer, "\(label) answer", limit: Limits.part)
                return NewExercisePart(text: answer, isCorrect: true)
            }
        case .reorder:
            return try require(exercise.tokens, "tokens", label).enumerated().map { index, token throws(ReplyProblem) in
                try requireText(token, "\(label) token", limit: Limits.part)
                return NewExercisePart(text: token, correctPosition: index)
            }
        case .match:
            var parts: [NewExercisePart] = []
            for (index, pair) in try require(exercise.pairs, "pairs", label).enumerated() {
                try requireText(pair.left, "\(label) pair", limit: Limits.part)
                try requireText(pair.right, "\(label) pair", limit: Limits.part)
                parts.append(NewExercisePart(text: pair.left, matchKey: "p\(index)"))
                parts.append(NewExercisePart(text: pair.right, matchKey: "p\(index)"))
            }
            return parts
        }
    }

    /// AC-16: options whose longest is more than twice the `Character` count of the shortest.
    static func unfairChoicePositions(_ reply: LessonReply) -> [Int] {
        reply.exercises.enumerated().compactMap { position, exercise in
            guard exercise.kind == .choice, let lengths = exercise.choices?.map(\.text.count),
                let shortest = lengths.min(), let longest = lengths.max(), longest > 2 * shortest
            else { return nil }
            return position
        }
    }

    private static func coreKind(_ kind: LessonReply.Kind) -> ExerciseKind {
        switch kind {
        case .choice: .choice
        case .fillBlank: .fillBlank
        case .reorder: .reorder
        case .match: .match
        }
    }

    private static func require<T>(_ value: T?, _ field: String, _ label: String) throws(ReplyProblem) -> T {
        guard let value else { throw ReplyProblem("\(label) has no \(field)") }
        return value
    }

    private static func requireText(_ text: String, _ field: String, limit: Int) throws(ReplyProblem) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReplyProblem("\(field) is empty")
        }
        guard text.count <= limit else { throw ReplyProblem("\(field) is over \(limit) characters") }
    }
}
