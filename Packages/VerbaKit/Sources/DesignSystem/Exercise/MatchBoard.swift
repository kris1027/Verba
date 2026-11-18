import SwiftUI

/// A `match` exercise: two columns of items in the order given. Pick an item, then one in the
/// other column, to pair them; picking a paired item unpairs it. Pairs carry letter tags (`A`,
/// `B`…) by left row. Every item is a focus stop that Space or a click picks, so no drag is needed.
public struct MatchBoard: View {
    private let left: [String]
    private let right: [String]
    @Binding private var pairs: [MatchPair]
    private let isLocked: Bool
    @State private var picked: MatchItem?
    @FocusState private var focused: MatchItem?

    /// Creates the board.
    /// - Parameters:
    ///   - left: Left column texts in display order.
    ///   - right: Right column texts in display order (already shuffled by the app).
    ///   - pairs: The pairs made so far.
    ///   - isLocked: True from Check until Next.
    public init(left: [String], right: [String], pairs: Binding<[MatchPair]>, isLocked: Bool) {
        self.left = left
        self.right = right
        _pairs = pairs
        self.isLocked = isLocked
    }

    /// The two columns.
    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            column(.left)
            column(.right)
        }
        .locked(isLocked)
        .takesExerciseFocus(isLocked: isLocked) {
            focused = left.indices.first { pair(forLeft: $0) == nil }.map(MatchItem.left) ?? .left(0)
        }
        .onChange(of: isLocked) { _, isLocked in
            if isLocked { picked = nil }
        }
        .accessibilityElement(children: .contain)
    }

    private func column(_ side: MatchItem.Side) -> some View {
        let texts = side == .left ? left : right
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(texts.indices, id: \.self) { index in
                item(MatchItem(side: side, index: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func item(_ item: MatchItem) -> some View {
        let partner = partner(of: item)
        let tag = partner.map { Self.letter(forLeft: item.side == .left ? item.index : $0.index) } ?? "·"
        return TokenChip(
            text: text(of: item),
            tag: tag,
            isPicked: picked == item,
            isFilled: partner != nil,
            isFocused: focused == item && !isLocked
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .chipInteraction(isLocked: isLocked) { pick(item) }
        .focused($focused, equals: item)
        .accessibilityLabel(text(of: item))
        .accessibilityValue(partner.map { "paired with \(text(of: $0))" } ?? "not paired")
        .accessibilityAddTraits(picked == item ? .isSelected : [])
    }

    private func pick(_ item: MatchItem) {
        guard !isLocked else { return }
        if let existing = pairs.firstIndex(where: { $0.contains(item) }) {
            pairs.remove(at: existing)
            picked = nil
            return
        }
        guard let first = picked, first.side != item.side else {
            picked = picked == item ? nil : item
            return
        }
        let leftIndex = first.side == .left ? first.index : item.index
        let rightIndex = first.side == .right ? first.index : item.index
        pairs.append(MatchPair(left: leftIndex, right: rightIndex))
        picked = nil
        if let next = left.indices.first(where: { pair(forLeft: $0) == nil }) {
            focused = .left(next)
        }
    }

    private func pair(forLeft index: Int) -> MatchPair? {
        pairs.first { $0.left == index }
    }

    private func partner(of item: MatchItem) -> MatchItem? {
        guard let pair = pairs.first(where: { $0.contains(item) }) else { return nil }
        return item.side == .left ? .right(pair.right) : .left(pair.left)
    }

    private func text(of item: MatchItem) -> String {
        let texts = item.side == .left ? left : right
        return texts.indices.contains(item.index) ? texts[item.index] : ""
    }

    /// The pair tag for a left row: `A` for the first row, `B` for the second, and so on.
    nonisolated static func letter(forLeft index: Int) -> String {
        guard index >= 0, index < 26, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
        return String(Character(scalar))
    }
}

/// One item on a match board: a side and a display index.
private struct MatchItem: Hashable {
    enum Side { case left, right }
    let side: Side
    let index: Int

    static func left(_ index: Int) -> MatchItem { MatchItem(side: .left, index: index) }
    static func right(_ index: Int) -> MatchItem { MatchItem(side: .right, index: index) }
}

extension MatchPair {
    fileprivate func contains(_ item: MatchItem) -> Bool {
        item.side == .left ? left == item.index : right == item.index
    }
}
