/// The named color roles every palette fills. Views never use a literal color; they use a role.
nonisolated public enum ColorToken: String, CaseIterable, Sendable {
    /// Window content area.
    case background
    /// Cards and exercise panes.
    case surface
    /// Input fields and the selected row fill.
    case raised
    /// Primary text.
    case text
    /// Metadata and hints.
    case textSecondary
    /// Labels and counters.
    case textTertiary
    /// Sage: focus border, primary button fill, selection marker.
    case accent
    /// Text drawn on the accent.
    case onAccent
    /// Decorative pane borders, exempt from contrast.
    case hairline
    /// Borders of option rows, fields, and tokens.
    case controlBorder
    /// The correct grade tone.
    case correct
    /// The partly correct grade tone.
    case partly
    /// The wrong grade tone.
    case wrong

    /// What the token is for, in a few words (shown in the Design Gallery and `design.md`).
    public var role: String {
        switch self {
        case .background: "window content area"
        case .surface: "cards, exercise panes"
        case .raised: "input fields, selected row fill"
        case .text: "primary text"
        case .textSecondary: "metadata, hints"
        case .textTertiary: "labels, counters"
        case .accent: "sage: focus border, primary button fill, selection marker"
        case .onAccent: "text on the accent"
        case .hairline: "decorative pane borders (exempt from contrast)"
        case .controlBorder: "option rows, fields, tokens"
        case .correct: "correct tone"
        case .partly: "partly correct tone"
        case .wrong: "wrong tone"
        }
    }
}
