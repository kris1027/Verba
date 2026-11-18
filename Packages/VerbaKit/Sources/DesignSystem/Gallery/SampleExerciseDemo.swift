import SwiftUI

/// A live sample exercise: answer it, check it (a short fake wait), see the feedback, go on.
/// With `simulatesFailure` on, checking fails so Try Again can be tried.
///
/// `simulatesFailure` is a binding, not a plain value: Return can run a Check action captured on an
/// earlier render, so the action must read the toggle's live state, not a copy taken back then.
struct SampleExerciseDemo: View {
    let exercise: SampleExercise
    let count: Int
    @Binding var simulatesFailure: Bool

    private enum Phase: Equatable {
        case answering, checking, failed, graded(FeedbackTone)
    }

    @State private var answer = SampleAnswer()
    @State private var phase = Phase.answering
    @State private var checkTask: Task<Void, Never>?

    var body: some View {
        SampleExerciseCard(
            exercise: exercise,
            count: count,
            answer: $answer,
            feedback: feedback,
            primaryAction: primaryAction,
            isLocked: phase != .answering
        )
        .onDisappear { checkTask?.cancel() }
    }

    private var feedback: FeedbackState {
        switch phase {
        case .answering: .hidden
        case .checking: .checking(cancel: cancel)
        case .failed: .failed(message: "Claude did not answer in time. Your answer is kept.", retry: check)
        case .graded(let tone):
            .result(tone: tone, correctAnswer: exercise.correctAnswer, explanation: exercise.explanation)
        }
    }

    private var primaryAction: ExerciseAction {
        switch phase {
        case .graded: .next(reset)
        case .checking, .failed: .awaitingAnswer
        case .answering: answer.hasAnswer(for: exercise.kind) ? .check(check) : .awaitingAnswer
        }
    }

    private func check() {
        phase = .checking
        checkTask?.cancel()
        checkTask = Task {
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
            phase = simulatesFailure ? .failed : .graded(answer.grade(for: exercise.kind))
        }
    }

    private func cancel() {
        checkTask?.cancel()
        phase = .answering
    }

    private func reset() {
        answer = SampleAnswer()
        phase = .answering
    }
}
