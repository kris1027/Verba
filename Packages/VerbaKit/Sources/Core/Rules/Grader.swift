/// The app's own grading rules, for the exercise kinds it can judge by itself.
public enum Grader {
    /// Grades a response.
    /// - Returns: `correct` or `wrong` for `choice`, `reorder`, and `match`; nil for `fillBlank` and `translate`.
    public static func grade(_ response: AttemptResponse, kind: ExerciseKind, parts: [ExercisePart]) -> Grade? {
        switch kind {
        case .fillBlank, .translate:
            return nil
        case .choice:
            guard case .choice(let chosen) = response else { return .wrong }
            return parts.first { $0.id == chosen }?.isCorrect == true ? .correct : .wrong
        case .reorder:
            guard case .order(let order) = response else { return .wrong }
            let expected = parts.filter { $0.correctPosition != nil }
                .sorted { ($0.correctPosition ?? 0) < ($1.correctPosition ?? 0) }
                .map(\.id)
            return order == expected ? .correct : .wrong
        case .match:
            guard case .pairs(let pairs) = response else { return .wrong }
            let keys = Dictionary(uniqueKeysWithValues: parts.map { ($0.id, $0.matchKey) })
            let allMatch = pairs.allSatisfy { pair in
                pair.count == 2 && keys[pair[0]] != nil && keys[pair[0]] == keys[pair[1]]
            }
            return allMatch && !pairs.isEmpty ? .correct : .wrong
        }
    }

    /// Checks that a response fits the exercise kind and uses only this exercise's parts.
    /// - Throws: `ValidationError.invalidResponse` when it does not.
    public static func validate(
        _ response: AttemptResponse, kind: ExerciseKind, parts: [ExercisePart]
    ) throws(ValidationError) {
        let partIDs = Set(parts.map(\.id))
        let isValid: Bool
        switch kind {
        case .fillBlank, .translate:
            guard case .text = response else { throw .invalidResponse }
            isValid = true
        case .choice:
            guard case .choice(let chosen) = response else { throw .invalidResponse }
            isValid = partIDs.contains(chosen)
        case .reorder:
            guard case .order(let order) = response else { throw .invalidResponse }
            isValid = order.count == partIDs.count && Set(order) == partIDs
        case .match:
            guard case .pairs(let pairs) = response else { throw .invalidResponse }
            let paired = pairs.flatMap(\.self)
            isValid = pairs.allSatisfy { $0.count == 2 } && paired.count == partIDs.count && Set(paired) == partIDs
        }
        guard isValid else { throw .invalidResponse }
    }
}
