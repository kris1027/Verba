/// The primary button of an exercise card. The feature model picks it: `.disabled` while nothing
/// is chosen or the field is blank, `.check` once there is an answer, `.next` after a result.
public enum ExerciseAction {
    /// "Check": sends the answer.
    case check(() -> Void)
    /// "Next": moves on to the next exercise.
    case next(() -> Void)
    /// "Check", disabled: there is no answer yet.
    case disabled

    /// The button title.
    public var title: String {
        switch self {
        case .check, .disabled: "Check"
        case .next: "Next"
        }
    }
}
