/// The app's own grading rules, for the exercise kinds it can judge by itself.
public enum Grader {
    /// Grades a response.
    /// - Returns: `correct` or `wrong` for `choice`, `reorder`, and `match`; nil for `fillBlank` and `translate`.
    public static func grade(_ response: AttemptResponse, kind: ExerciseKind, parts: [ExercisePart]) -> Grade? {
        switch (kind, response) {
        case (.fillBlank, _), (.translate, _):
            return nil
        case (.choice, .choice(let chosen)):
            return parts.first { $0.id == chosen }?.isCorrect == true ? .correct : .wrong
        case (.reorder, .order(let order)):
            let expected = parts.filter { $0.correctPosition != nil }
                .sorted { ($0.correctPosition ?? 0) < ($1.correctPosition ?? 0) }
                .map(\.id)
            return order == expected ? .correct : .wrong
        case (.match, .pairs(let pairs)):
            let keys = Dictionary(uniqueKeysWithValues: parts.map { ($0.id, $0.matchKey) })
            let allMatch = pairs.allSatisfy { pair in
                pair.count == 2 && keys[pair[0]] != nil && keys[pair[0]] == keys[pair[1]]
            }
            return allMatch && !pairs.isEmpty ? .correct : .wrong
        default:
            return .wrong
        }
    }

    /// Checks that a response fits the exercise kind and uses only this exercise's parts.
    /// - Throws: `ValidationError.invalidResponse` when it does not.
    public static func validate(
        _ response: AttemptResponse, kind: ExerciseKind, parts: [ExercisePart]
    ) throws(ValidationError) {
        let partIDs = Set(parts.map(\.id))
        let isValid: Bool
        switch (kind, response) {
        case (.fillBlank, .text), (.translate, .text):
            isValid = true
        case (.choice, .choice(let chosen)):
            isValid = partIDs.contains(chosen)
        case (.reorder, .order(let order)):
            isValid = order.count == partIDs.count && Set(order) == partIDs
        case (.match, .pairs(let pairs)):
            let paired = pairs.flatMap(\.self)
            isValid = pairs.allSatisfy { $0.count == 2 } && paired.count == partIDs.count && Set(paired) == partIDs
        default:
            isValid = false
        }
        guard isValid else { throw .invalidResponse }
    }
}
