/// The primary button of an exercise card. The feature model picks it: `.awaitingAnswer` while nothing
/// is chosen or the field is blank, `.check` once there is an answer, `.next` after a result.
public enum ExerciseAction {
    /// "Check": sends the answer.
    case check(() -> Void)
    /// "Next": moves on to the next exercise.
    case next(() -> Void)
    /// "Check", disabled: there is no answer yet.
    case awaitingAnswer

    /// The button title.
    public var title: String {
        switch self {
        case .check, .awaitingAnswer: "Check"
        case .next: "Next"
        }
    }
}
