import SwiftUI

/// Gallery section: every exercise kind in every state, side by side, without taking focus or
/// claiming Return and Esc.
struct ExerciseStateSection: View {
    private enum GalleryState: CaseIterable {
        case idle, selected, checking, failed, correct, partlyCorrect, wrong

        var name: String {
            switch self {
            case .idle: "Idle"
            case .selected: "Selected"
            case .checking: "Checking"
            case .failed: "Failed"
            case .correct: "Correct"
            case .partlyCorrect: "Partly correct"
            case .wrong: "Wrong"
            }
        }

        var tone: FeedbackTone? {
            switch self {
            case .correct: .correct
            case .partlyCorrect: .partlyCorrect
            case .wrong: .wrong
            default: nil
            }
        }
    }

    var body: some View {
        GallerySection(title: "Exercise states") {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                ForEach(SampleLesson.exercises) { exercise in
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        TerminalLabel("\(exercise.kindLabel) · every state")
                        ForEach(GalleryState.allCases, id: \.self) { state in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                TerminalLabel(state.name)
                                card(exercise, in: state)
                            }
                        }
                    }
                }
            }
            .readingColumnWidth()
            .environment(\.exerciseIsLive, false)
        }
    }

    private func card(_ exercise: SampleExercise, in state: GalleryState) -> some View {
        let answer = state == .idle ? SampleAnswer() : SampleAnswer.sample(for: exercise.kind)
        return SampleExerciseCard(
            exercise: exercise,
            count: SampleLesson.exercises.count,
            answer: .constant(stateAnswer(answer, exercise: exercise, state: state)),
            feedback: feedback(exercise, in: state),
            primaryAction: action(in: state),
            isLocked: state != .idle && state != .selected
        )
    }

    /// In the wrong state, the choice exercise shows a wrong pick so both row marks appear.
    private func stateAnswer(_ answer: SampleAnswer, exercise: SampleExercise, state: GalleryState) -> SampleAnswer {
        guard state == .wrong || state == .partlyCorrect, case .choice = exercise.kind else { return answer }
        return SampleAnswer(selection: 0)
    }

    private func feedback(_ exercise: SampleExercise, in state: GalleryState) -> FeedbackState {
        switch state {
        case .idle, .selected: .hidden
        case .checking: .checking(cancel: {})
        case .failed: .failed(message: "Claude did not answer in time. Your answer is kept.", retry: {})
        case .correct, .partlyCorrect, .wrong:
            .result(
                tone: state.tone ?? .correct, correctAnswer: exercise.correctAnswer, explanation: exercise.explanation)
        }
    }

    private func action(in state: GalleryState) -> ExerciseAction {
        switch state {
        case .idle, .checking, .failed: .disabled
        case .selected: .check {}
        case .correct, .partlyCorrect, .wrong: .next {}
        }
    }
}
