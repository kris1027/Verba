/// One pair a learner made in a `match` exercise, as display indexes into the two columns.
nonisolated public struct MatchPair: Hashable, Sendable {
    /// Display index in the left column.
    public let left: Int
    /// Display index in the right column.
    public let right: Int

    /// Creates a pair.
    public init(left: Int, right: Int) {
        self.left = left
        self.right = right
    }
}
