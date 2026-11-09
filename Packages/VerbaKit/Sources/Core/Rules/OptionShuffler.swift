/// The app's own shuffle, so an option's position never gives the answer away.
public struct OptionShuffler: Sendable {
    /// Creates a shuffler.
    public init() {}

    /// A random display order for the parts, or an empty one when this kind shows no parts.
    public func displayOrder(
        for kind: ExerciseKind, parts: [ExercisePart], using generator: inout some RandomNumberGenerator
    ) -> [ExercisePartID] {
        guard kind.displaysParts else { return [] }
        return parts.map(\.id).shuffled(using: &generator)
    }

    /// Checks that an order is exactly the exercise's displayed parts.
    /// - Throws: `ValidationError.invalidDisplayOrder` for missing, extra, duplicate, or unknown ids,
    ///   or any order for a kind that shows no parts.
    public static func validate(
        order: [ExercisePartID], kind: ExerciseKind, parts: [ExercisePart]
    ) throws(ValidationError) {
        guard kind.displaysParts, order.count == parts.count, Set(order) == Set(parts.map(\.id)) else {
            throw .invalidDisplayOrder
        }
    }
}
