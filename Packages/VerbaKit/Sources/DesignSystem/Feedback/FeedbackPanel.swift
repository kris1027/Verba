import SwiftUI

/// The inline panel directly under an answer: `Checking…` with a blinking cursor, a failure with
/// Try Again, or the grade (glyph and word), the correct answer when the grade is not correct,
/// and the explanation. It is one accessibility element, and VoiceOver announces the grade and
/// explanation once each time a result appears (in a live area; the gallery's static grid is quiet).
public struct FeedbackPanel: View {
    private let state: FeedbackState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.exerciseIsLive) private var isLive

    /// Creates the panel for a state. In `.hidden` it draws nothing.
    public init(state: FeedbackState) {
        self.state = state
    }

    /// The panel for the current state.
    public var body: some View {
        // The stack stays in place while hidden, so a change into a result is always observed.
        ZStack(alignment: .topLeading) {
            if state.phase != .hidden {
                content
                    .transition(.opacity.combined(with: .offset(y: Theme.Spacing.xs)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Theme.Motion.feedbackReveal(reduceMotion: reduceMotion), value: state.phase)
        // `initial` covers a panel that is new with a result already in it: `ExerciseCard` gives
        // each exercise its own panel, so equal grades on two exercises in a row are both read.
        .onChange(of: state.phase, initial: true) { _, phase in
            guard isLive, case .result(let tone) = phase else { return }
            AccessibilityNotification.Announcement(announcement(for: tone)).post()
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .checking(let cancel):
            pane(border: Theme.hairline) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Checking…")
                        .themeFont(.code)
                        .foregroundStyle(Theme.textSecondary)
                    BlinkingCursor()
                    Spacer(minLength: Theme.Spacing.l)
                    TerminalLabel("Esc to cancel")
                }
                .background {
                    // Esc while checking: the only time Esc does anything in an exercise.
                    if isLive {
                        Button("Cancel", action: cancel)
                            .keyboardShortcut(.cancelAction)
                            .opacity(0)
                            .focusable(false)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Checking your answer")
            .accessibilityAction(named: "Cancel", cancel)
        case .failed(let message, let retry):
            pane(border: Theme.controlBorder) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text(verbatim: message)
                        .themeFont(.readingBody)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    // The card's Check is disabled after a failure, so Return retries.
                    Button("Try Again", action: retry)
                        .buttonStyle(.verbaSecondary)
                        .keyboardShortcut(isLive ? .defaultAction : nil)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Checking failed")
            .accessibilityValue(message)
            .accessibilityAction(named: "Try Again", retry)
        case .result(let tone, let correctAnswer, let explanation):
            pane(border: ThemeColor(tone.colorToken)) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(verbatim: tone.title)
                        .themeFont(.ui)
                        .bold()
                        .foregroundStyle(ThemeColor(tone.colorToken))
                    if tone != .correct, let correctAnswer {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            TerminalLabel("Answer")
                            Text(verbatim: correctAnswer)
                                .themeFont(.code)
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let explanation, !explanation.isEmpty {
                        Text(verbatim: explanation)
                            .themeFont(.readingBody)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tone.word)
            .accessibilityValue(resultValue(tone: tone, correctAnswer: correctAnswer, explanation: explanation))
        }
    }

    private func pane(border: ThemeColor, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .strokeBorder(border, lineWidth: Theme.Shape.borderWidth)
            }
    }

    private func resultValue(tone: FeedbackTone, correctAnswer: String?, explanation: String?) -> String {
        var parts: [String] = []
        if tone != .correct, let correctAnswer { parts.append("Answer: \(correctAnswer)") }
        if let explanation, !explanation.isEmpty { parts.append(explanation) }
        return parts.joined(separator: ". ")
    }

    private func announcement(for tone: FeedbackTone) -> String {
        guard case .result(_, _, let explanation) = state, let explanation, !explanation.isEmpty else {
            return tone.word
        }
        return "\(tone.word). \(explanation)"
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.l) {
        FeedbackPanel(state: .checking(cancel: {}))
        FeedbackPanel(state: .failed(message: "Claude did not answer in time.", retry: {}))
        FeedbackPanel(state: .result(tone: .correct, correctAnswer: nil, explanation: "Zawód to cecha stała."))
        FeedbackPanel(state: .result(tone: .wrong, correctAnswer: "es", explanation: "Ser opisuje cechy stałe."))
    }
    .padding()
    .background(Theme.background)
}
