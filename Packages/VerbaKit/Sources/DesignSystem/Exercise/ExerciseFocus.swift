import SwiftUI

extension EnvironmentValues {
    /// Rises each time an exercise card appears or moves to another exercise; the input inside
    /// the card then takes keyboard focus.
    @Entry var exerciseFocusRequest = 0

    /// Whether the exercises here are live: their inputs take focus when asked, and their
    /// buttons claim Return and Esc. The gallery turns it off for its static state grid, so only
    /// the live exercise answers the keyboard.
    @Entry var exerciseIsLive = true
}

extension View {
    /// Locks an input after Check: it ignores clicks and taps. Each input also drops out of the
    /// focus order and ignores keys while locked. It is never `.disabled`, which would dim the
    /// answer below AA contrast.
    public func locked(_ isLocked: Bool) -> some View {
        allowsHitTesting(!isLocked)
    }

    /// Focuses an input when its card asks (on appear and on a new exercise), unless it is locked.
    func takesExerciseFocus(isLocked: Bool, focus: @escaping () -> Void) -> some View {
        modifier(ExerciseFocusTaker(isLocked: isLocked, focus: focus))
    }
}

private struct ExerciseFocusTaker: ViewModifier {
    let isLocked: Bool
    let focus: () -> Void
    @Environment(\.exerciseFocusRequest) private var request
    @Environment(\.exerciseIsLive) private var isLive

    func body(content: Content) -> some View {
        content.task(id: request) {
            guard request > 0, isLive, !isLocked else { return }
            focus()
        }
    }
}
