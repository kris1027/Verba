import SwiftUI

/// A `reorder` exercise: the answer line on top and the bank of unplaced tokens below, both in
/// the order given. Space or a click on a bank token appends it to the answer; on a placed token
/// it goes back to the bank. Every token is a focus stop, so no drag is needed.
public struct ReorderBoard: View {
    private let tokens: [String]
    @Binding private var placed: [Int]
    private let isLocked: Bool
    @FocusState private var focused: Int?

    /// Creates the board.
    /// - Parameters:
    ///   - tokens: The token texts in display order (already shuffled by the app).
    ///   - placed: Display indexes of the placed tokens, in answer order.
    ///   - isLocked: True from Check until Next.
    public init(tokens: [String], placed: Binding<[Int]>, isLocked: Bool) {
        self.tokens = tokens
        _placed = placed
        self.isLocked = isLocked
    }

    /// The answer line and the bank.
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            TerminalLabel("Your answer")
            FlowLayout {
                ForEach(Array(placed.enumerated()), id: \.element) { position, index in
                    chip(index, value: "in answer, position \(position + 1)", isPlaced: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if placed.isEmpty {
                    Text("Press Space or click a word below to place it.")
                        .themeFont(.ui)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Theme.Spacing.xxl)
            .padding(Theme.Spacing.s)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .strokeBorder(Theme.hairline, lineWidth: Theme.Shape.borderWidth)
            }

            if !bank.isEmpty {
                TerminalLabel("Words")
                FlowLayout {
                    ForEach(bank, id: \.self) { index in
                        chip(index, value: "not placed", isPlaced: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .locked(isLocked)
        .takesExerciseFocus(isLocked: isLocked) { focused = bank.first ?? placed.first }
        .accessibilityElement(children: .contain)
    }

    private var bank: [Int] {
        tokens.indices.filter { !placed.contains($0) }
    }

    private func chip(_ index: Int, value: String, isPlaced: Bool) -> some View {
        TokenChip(text: tokens[index], isFilled: isPlaced, isFocused: focused == index && !isLocked)
            .chipInteraction(isLocked: isLocked) { toggle(index) }
            .focused($focused, equals: index)
            .accessibilityLabel(tokens[index])
            .accessibilityValue(value)
    }

    /// Places a bank token or returns a placed one, then keeps focus where the keyboard user
    /// expects it: on the next word still in the bank, or on the next placed word.
    private func toggle(_ index: Int) {
        guard !isLocked else { return }
        if let position = placed.firstIndex(of: index) {
            placed.remove(at: position)
            focused = placed.indices.contains(position) ? placed[position] : (placed.last ?? index)
        } else {
            let remaining = bank.filter { $0 != index }
            placed.append(index)
            focused = remaining.first { $0 > index } ?? remaining.last ?? index
        }
    }
}
