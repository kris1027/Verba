import SwiftUI

/// A typed answer behind a `›` marker: one line for `fillBlank`, growing lines for `translate`.
/// Return submits; in the multiline field Option Return inserts a line break. Locked, the answer
/// stays on screen as plain text at full contrast.
public struct AnswerField: View {
    @Binding private var text: String
    private let isMultiline: Bool
    private let placeholder: String
    private let isLocked: Bool
    private let onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    /// Creates the field.
    /// - Parameters:
    ///   - text: The typed answer.
    ///   - isMultiline: True for `translate`, false for `fillBlank`.
    ///   - placeholder: The hint shown while the field is empty.
    ///   - isLocked: True from Check until Next.
    ///   - onSubmit: Called on Return; pass the card's Check action.
    public init(
        text: Binding<String>,
        isMultiline: Bool,
        placeholder: String,
        isLocked: Bool,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.isMultiline = isMultiline
        self.placeholder = placeholder
        self.isLocked = isLocked
        self.onSubmit = onSubmit
    }

    /// The marker and the field (or the locked answer).
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(verbatim: "›")
                .themeFont(.code)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            if isLocked {
                Text(verbatim: text.isEmpty ? " " : text)
                    .themeFont(.ui)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Your answer")
                    .accessibilityValue(text)
            } else {
                TextField(placeholder, text: $text, axis: isMultiline ? .vertical : .horizontal)
                    .textFieldStyle(.plain)
                    .themeFont(.ui)
                    .foregroundStyle(Theme.text)
                    .lineLimit(isMultiline ? 2...8 : 1...1)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .accessibilityLabel("Your answer")
            }
        }
        .padding(Theme.Spacing.m)
        .verbaBox(fill: Theme.raised, border: Theme.controlBorder)
        .focusBorder(isFocused && !isLocked)
        .locked(isLocked)
        .takesExerciseFocus(isLocked: isLocked) { isFocused = true }
    }
}
