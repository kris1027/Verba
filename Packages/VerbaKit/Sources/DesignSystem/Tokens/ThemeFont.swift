import SwiftUI

/// The type ramp. Reading text is New York (the system serif), controls SF Pro, labels SF Mono.
///
/// Every font comes from a text style, never a fixed point size, and reaches the screen only
/// through `.themeFont(_:)`, which multiplies it by the current `TextSize`.
nonisolated public enum ThemeFont: CaseIterable, Sendable {
    /// Lesson title: large title serif, bold.
    case readingTitle
    /// Markdown headings and section heads: title 2 serif, bold.
    case readingHeading
    /// Explanations, prompts, and feedback explanations: title 2 serif with extra line spacing.
    case readingBody
    /// Buttons and fields: body, SF Pro.
    case ui
    /// Kind labels, counters, status lines, key hints: callout SF Mono, uppercase, tracked.
    case label
    /// Inline code, code blocks, and typed answers shown back: body SF Mono.
    case code

    /// The unscaled font, built from a text style.
    public var base: Font {
        switch self {
        case .readingTitle: .system(.largeTitle, design: .serif).bold()
        case .readingHeading: .system(.title2, design: .serif).bold()
        case .readingBody: .system(.title2, design: .serif)
        case .ui: .body
        case .label: .system(.callout, design: .monospaced)
        case .code: .system(.body, design: .monospaced)
        }
    }

    /// The font scaled for a text size step.
    public func font(for size: TextSize) -> Font {
        base.scaled(by: size.scale)
    }

    /// Extra space between lines at a text size step (only reading body text has any).
    public func lineSpacing(for size: TextSize) -> Double {
        self == .readingBody ? Theme.Spacing.xs * size.scale : 0
    }

    /// Letter spacing in points (only labels are tracked).
    public var tracking: Double {
        self == .label ? 0.5 : 0
    }

    /// Whether the text is shown in capitals (only labels are).
    public var isUppercase: Bool {
        self == .label
    }

    /// The token name as `design.md` and the Design Gallery write it.
    public var name: String {
        switch self {
        case .readingTitle: "readingTitle"
        case .readingHeading: "readingHeading"
        case .readingBody: "readingBody"
        case .ui: "ui"
        case .label: "label"
        case .code: "code"
        }
    }
}
