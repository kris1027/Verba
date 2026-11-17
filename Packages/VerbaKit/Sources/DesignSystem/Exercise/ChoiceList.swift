import SwiftUI

/// The options of a `choice` exercise as numbered rows `[1]` to `[n]`, in exactly the order
/// given. It is one focus stop: keys 1 to 9 pick an option, and the up and down arrows move the
/// selection. The selected row shows a `›` marker and a sage border, not only a tint.
public struct ChoiceList: View {
    private let options: [String]
    @Binding private var selection: Int?
    private let isLocked: Bool
    private let marks: [Int: FeedbackTone]
    @FocusState private var isFocused: Bool

    /// Creates the list.
    /// - Parameters:
    ///   - options: The option texts in display order (already shuffled by the app).
    ///   - selection: The chosen display index, or `nil`.
    ///   - isLocked: True from Check until Next: the list ignores clicks and keys.
    ///   - marks: After checking, the grade per display index: the chosen row carries its grade,
    ///     and when it is not correct, the right row carries `.correct`.
    public init(options: [String], selection: Binding<Int?>, isLocked: Bool, marks: [Int: FeedbackTone] = [:]) {
        self.options = options
        _selection = selection
        self.isLocked = isLocked
        self.marks = marks
    }

    /// The numbered rows.
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(options.indices, id: \.self) { index in
                ChoiceRow(
                    number: index + 1,
                    count: options.count,
                    text: options[index],
                    isSelected: selection == index,
                    mark: marks[index],
                    select: { select(index) }
                )
            }
        }
        .padding(Theme.Spacing.xs)
        .focusable(!isLocked)
        .focused($isFocused)
        .focusBorder(isFocused)
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard let digit = Int(press.characters), (1...9).contains(digit), digit <= options.count else {
                return .ignored
            }
            return select(digit - 1) ? .handled : .ignored
        }
        .onKeyPress(.downArrow) { move(by: 1) ? .handled : .ignored }
        .onKeyPress(.upArrow) { move(by: -1) ? .handled : .ignored }
        .locked(isLocked)
        .takesExerciseFocus(isLocked: isLocked) { isFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Options")
    }

    @discardableResult private func select(_ index: Int) -> Bool {
        guard !isLocked, options.indices.contains(index) else { return false }
        selection = index
        return true
    }

    private func move(by step: Int) -> Bool {
        guard !options.isEmpty else { return false }
        let target = selection.map { $0 + step } ?? (step > 0 ? 0 : options.count - 1)
        return select(min(max(target, 0), options.count - 1))
    }
}

private struct ChoiceRow: View {
    let number: Int
    let count: Int
    let text: String
    let isSelected: Bool
    let mark: FeedbackTone?
    let select: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(verbatim: isSelected ? "›" : " ")
                .themeFont(.code)
                .foregroundStyle(Theme.accent)
            Text(verbatim: "[\(number)]")
                .themeFont(.code)
                .foregroundStyle(Theme.textSecondary)
            Text(verbatim: text)
                .themeFont(.readingBody)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.m)
            if let mark {
                Text(verbatim: mark.glyph)
                    .themeFont(.code)
                    .bold()
                    .foregroundStyle(ThemeColor(mark.colorToken))
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.m)
        .background(isSelected ? Theme.raised : Theme.surface, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                .strokeBorder(border, lineWidth: Theme.Shape.borderWidth)
        }
        .contentShape(.rect)
        .onTapGesture(perform: select)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Option \(number) of \(count), \(text)")
        .accessibilityValue(mark?.word ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, select)
    }

    private var border: ThemeColor {
        if let mark { return ThemeColor(mark.colorToken) }
        return isSelected ? Theme.accent : Theme.controlBorder
    }
}
