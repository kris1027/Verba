/// What the feedback panel under an answer shows. The caller (a feature model) owns the state
/// and the actions; the panel only draws it.
public enum FeedbackState {
    /// Nothing checked yet: no panel.
    case hidden
    /// The answer is being checked; Esc calls `cancel`.
    case checking(cancel: () -> Void)
    /// Checking failed with a user facing message; Try Again calls `retry`.
    case failed(message: String, retry: () -> Void)
    /// The answer was graded. `correctAnswer` is shown when the tone is not `.correct`.
    case result(tone: FeedbackTone, correctAnswer: String?, explanation: String?)

    /// The state without its actions, for comparing states and driving animation.
    public var phase: FeedbackPhase {
        switch self {
        case .hidden: .hidden
        case .checking: .checking
        case .failed: .failed
        case .result(let tone, _, _): .result(tone)
        }
    }
}

/// A `FeedbackState` without its actions or text: comparable, so views can react when it changes.
nonisolated public enum FeedbackPhase: Hashable, Sendable {
    /// No panel.
    case hidden
    /// Checking in progress.
    case checking
    /// Checking failed.
    case failed
    /// Graded with a tone.
    case result(FeedbackTone)
}
