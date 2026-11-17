import SwiftUI

/// One exercise: a `03/08` counter and kind label, the prompt in the reading serif, the input,
/// the inline feedback panel, and the primary button. When it appears, and when `position`
/// changes, keyboard focus moves to the input.
///
/// Return activates the primary button. For typed answers (`returnSubmitsFromInput`), the field
/// submits Check itself, and the button takes Return only once it says Next. A card in a
/// non live area (the gallery's static state grid) claims no keys at all.
public struct ExerciseCard<Input: View>: View {
    private let position: Int
    private let count: Int
    private let kindLabel: String
    private let prompt: String
    private let feedback: FeedbackState
    private let primaryAction: ExerciseAction
    private let returnSubmitsFromInput: Bool
    private let input: Input
    @State private var focusRequest = 0
    @Environment(\.exerciseIsLive) private var isLive

    /// Creates a card.
    /// - Parameters:
    ///   - position: The exercise's place in the lesson, 0 based.
    ///   - count: How many exercises the lesson has.
    ///   - kindLabel: The kind in words, such as `Translate`; shown in capitals.
    ///   - prompt: The prompt, shown as written.
    ///   - feedback: What the panel under the input shows.
    ///   - primaryAction: Check, Next, or disabled Check.
    ///   - returnSubmitsFromInput: True for typed answers, whose field submits on Return.
    ///   - input: One of `ChoiceList`, `AnswerField`, `ReorderBoard`, `MatchBoard`.
    public init(
        position: Int,
        count: Int,
        kindLabel: String,
        prompt: String,
        feedback: FeedbackState,
        primaryAction: ExerciseAction,
        returnSubmitsFromInput: Bool,
        @ViewBuilder input: () -> Input
    ) {
        self.position = position
        self.count = count
        self.kindLabel = kindLabel
        self.prompt = prompt
        self.feedback = feedback
        self.primaryAction = primaryAction
        self.returnSubmitsFromInput = returnSubmitsFromInput
        self.input = input()
    }

    /// The card.
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header
            Text(verbatim: prompt)
                .themeFont(.readingBody)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            input
                .environment(\.exerciseFocusRequest, focusRequest)
            FeedbackPanel(state: feedback)
                .id(position)
            footer
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .verbaBox(fill: Theme.surface, border: Theme.hairline)
        .accessibilityElement(children: .contain)
        .onAppear { focusRequest += 1 }
        .onChange(of: position) { focusRequest += 1 }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            TerminalLabel(Self.counter(position: position, count: count))
            TerminalLabel("·")
            TerminalLabel(kindLabel)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exercise \(position + 1) of \(count), \(kindLabel)")
        .accessibilityAddTraits(.isHeader)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.l) {
            primaryButton
            TerminalLabel(keyHint)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var primaryButton: some View {
        switch primaryAction {
        case .check(let check):
            Button(primaryAction.title, action: check)
                .buttonStyle(.verbaPrimary)
                .keyboardShortcut(isLive && !returnSubmitsFromInput ? .defaultAction : nil)
        case .next(let next):
            Button(primaryAction.title, action: next)
                .buttonStyle(.verbaPrimary)
                .keyboardShortcut(isLive ? .defaultAction : nil)
        case .disabled:
            Button(primaryAction.title) {}
                .buttonStyle(.verbaPrimary)
                .disabled(true)
        }
    }

    private var keyHint: String {
        switch (primaryAction, feedback.phase) {
        case (_, .checking): "Esc · cancel"
        case (_, .failed): "Return · try again"
        case (.next, _): "Return · next"
        default: "Return · check"
        }
    }

    /// The counter text: the 1 based position and the count, two digits each, such as `03/08`.
    nonisolated static func counter(position: Int, count: Int) -> String {
        func twoDigits(_ value: Int) -> String {
            value < 10 ? "0\(value)" : "\(value)"
        }
        return "\(twoDigits(position + 1))/\(twoDigits(count))"
    }
}
