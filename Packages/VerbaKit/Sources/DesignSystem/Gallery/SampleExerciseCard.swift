import SwiftUI

/// What a learner has entered for a sample exercise, whatever its kind.
struct SampleAnswer: Equatable {
    var selection: Int?
    var text = ""
    var placed: [Int] = []
    var pairs: [MatchPair] = []

    /// Whether there is anything to check (picks Check over disabled Check).
    func hasAnswer(for kind: SampleExercise.Kind) -> Bool {
        switch kind {
        case .choice: selection != nil
        case .fillBlank, .translate: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reorder: !placed.isEmpty
        case .match: !pairs.isEmpty
        }
    }

    /// A plausible grade for the gallery demo (the real app gets grades from `Core` and Claude).
    func grade(for kind: SampleExercise.Kind) -> FeedbackTone {
        switch kind {
        case .choice(_, let correct):
            return selection == correct ? .correct : .wrong
        case .fillBlank(let answer), .translate(let answer):
            let typed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if typed == answer.lowercased() { return .correct }
            return answer.lowercased().hasPrefix(String(typed.prefix(3))) ? .partlyCorrect : .wrong
        case .reorder(_, let correctOrder):
            if placed == correctOrder { return .correct }
            return placed.first == correctOrder.first ? .partlyCorrect : .wrong
        case .match(_, _, let key):
            let right = Set(pairs).intersection(key).count
            if right == key.count { return .correct }
            return right > 0 ? .partlyCorrect : .wrong
        }
    }

    /// A filled in answer for the static gallery states.
    static func sample(for kind: SampleExercise.Kind) -> SampleAnswer {
        switch kind {
        case .choice: SampleAnswer(selection: 1)
        case .fillBlank: SampleAnswer(text: "estoy")
        case .translate: SampleAnswer(text: "Soy de Polonia, pero ahora estoy en Madrid.")
        case .reorder: SampleAnswer(placed: [1, 0])
        case .match: SampleAnswer(pairs: [MatchPair(left: 0, right: 2), MatchPair(left: 1, right: 3)])
        }
    }
}

/// An exercise card for a sample exercise, with the input its kind needs.
struct SampleExerciseCard: View {
    let exercise: SampleExercise
    let count: Int
    @Binding var answer: SampleAnswer
    let feedback: FeedbackState
    let primaryAction: ExerciseAction
    let isLocked: Bool

    var body: some View {
        ExerciseCard(
            position: exercise.position,
            count: count,
            kindLabel: exercise.kindLabel,
            prompt: exercise.prompt,
            feedback: feedback,
            primaryAction: primaryAction,
            returnSubmitsFromInput: returnSubmitsFromInput
        ) {
            input
        }
    }

    private var returnSubmitsFromInput: Bool {
        switch exercise.kind {
        case .fillBlank, .translate: true
        case .choice, .reorder, .match: false
        }
    }

    @ViewBuilder private var input: some View {
        switch exercise.kind {
        case .choice(let options, let correct):
            ChoiceList(
                options: options, selection: $answer.selection, isLocked: isLocked, marks: marks(correct: correct))
        case .fillBlank:
            AnswerField(
                text: $answer.text, isMultiline: false, placeholder: "Type the missing word", isLocked: isLocked,
                onSubmit: submit)
        case .translate:
            AnswerField(
                text: $answer.text, isMultiline: true, placeholder: "Type your translation", isLocked: isLocked,
                onSubmit: submit)
        case .reorder(let tokens, _):
            ReorderBoard(tokens: tokens, placed: $answer.placed, isLocked: isLocked)
        case .match(let left, let right, _):
            MatchBoard(left: left, right: right, pairs: $answer.pairs, isLocked: isLocked)
        }
    }

    /// Return in a typed field runs Check, but only when Check is available.
    private func submit() {
        if case .check(let check) = primaryAction { check() }
    }

    /// After a result: the chosen row carries the grade, and the right row is marked when it differs.
    private func marks(correct: Int) -> [Int: FeedbackTone] {
        guard case .result(let tone, _, _) = feedback, let selection = answer.selection else { return [:] }
        var marks = [selection: tone]
        if tone != .correct { marks[correct] = .correct }
        return marks
    }
}
