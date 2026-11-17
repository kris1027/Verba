/// The grade of a checked answer as the design system shows it: a color, a glyph, and a word.
/// The glyph and word always appear together, so the grade never relies on color alone.
nonisolated public enum FeedbackTone: CaseIterable, Hashable, Sendable {
    /// The answer is right.
    case correct
    /// The answer is partly right.
    case partlyCorrect
    /// The answer is wrong.
    case wrong

    /// The color role of the tone (mint, amber, soft red; never the sage accent).
    public var colorToken: ColorToken {
        switch self {
        case .correct: .correct
        case .partlyCorrect: .partly
        case .wrong: .wrong
        }
    }

    /// The plain text glyph, the same on screen and in print.
    public var glyph: String {
        switch self {
        case .correct: "✓"
        case .partlyCorrect: "~"
        case .wrong: "✗"
        }
    }

    /// The word shown and read after the glyph.
    public var word: String {
        switch self {
        case .correct: "Correct"
        case .partlyCorrect: "Partly correct"
        case .wrong: "Not quite"
        }
    }

    /// Glyph and word together, such as `✓ Correct`.
    public var title: String {
        "\(glyph) \(word)"
    }
}
