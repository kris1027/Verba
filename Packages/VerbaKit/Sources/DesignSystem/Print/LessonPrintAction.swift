import SwiftUI

/// A window's offer to print its lesson. A window sets it with
/// `.focusedSceneValue(\.lessonPrintAction, …)`; File › Print… (⌘P) calls it.
public struct LessonPrintAction {
    private let action: () -> Void

    /// Creates the action.
    public init(_ action: @escaping () -> Void) {
        self.action = action
    }

    /// Prints the lesson.
    public func callAsFunction() {
        action()
    }
}

extension FocusedValues {
    /// The focused window's print action, or `nil` when it has no lesson to print.
    @Entry public var lessonPrintAction: LessonPrintAction?
}
