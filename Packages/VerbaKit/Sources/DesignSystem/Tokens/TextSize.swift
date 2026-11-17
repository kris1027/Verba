/// Verba's own text size, one of ten steps from `.xSmall` to `.accessibility3`.
///
/// SwiftUI on macOS does not apply Dynamic Type, so Verba scales its content fonts itself:
/// every content area font is multiplied by `scale`. The steps mirror the iOS body size at
/// each Dynamic Type step divided by 17, so `.large` (the default) is 1.0.
nonisolated public enum TextSize: Int, CaseIterable, Comparable, Sendable {
    /// Scale 0.82.
    case xSmall = 0
    /// Scale 0.88.
    case small = 1
    /// Scale 0.94.
    case medium = 2
    /// Scale 1.0, the default.
    case large = 3
    /// Scale 1.12.
    case xLarge = 4
    /// Scale 1.24.
    case xxLarge = 5
    /// Scale 1.35.
    case xxxLarge = 6
    /// Scale 1.65.
    case accessibility1 = 7
    /// Scale 1.94.
    case accessibility2 = 8
    /// Scale 2.35, the largest step.
    case accessibility3 = 9

    /// The `UserDefaults` key that stores the chosen step as its raw value.
    public static let storageKey = "verba.textSize"

    /// The step a fresh install uses, and the fallback for an unknown stored value.
    public static let defaultSize = TextSize.large

    /// Reads a stored raw value, falling back to `.large` when it is missing or unknown.
    public init(storedValue: Int?) {
        self = storedValue.flatMap(TextSize.init(rawValue:)) ?? .defaultSize
    }

    /// The factor every content area font is multiplied by at this step.
    public var scale: Double {
        switch self {
        case .xSmall: 0.82
        case .small: 0.88
        case .medium: 0.94
        case .large: 1.0
        case .xLarge: 1.12
        case .xxLarge: 1.24
        case .xxxLarge: 1.35
        case .accessibility1: 1.65
        case .accessibility2: 1.94
        case .accessibility3: 2.35
        }
    }

    /// The next larger step, or `nil` at the largest.
    public var bigger: TextSize? {
        TextSize(rawValue: rawValue + 1)
    }

    /// The next smaller step, or `nil` at the smallest.
    public var smaller: TextSize? {
        TextSize(rawValue: rawValue - 1)
    }

    /// Whether native controls in content areas should use the large control size at this step.
    public var usesLargeControls: Bool {
        scale >= TextSize.xxxLarge.scale
    }

    /// Orders steps from smallest to largest.
    public static func < (lhs: TextSize, rhs: TextSize) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
