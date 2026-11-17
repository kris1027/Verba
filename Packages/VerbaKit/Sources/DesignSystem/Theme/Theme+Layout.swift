import SwiftUI

extension Theme {
    /// The 4 point spacing grid. Spacing stays fixed at every text size.
    nonisolated public enum Spacing {
        /// 4 points.
        public static let xs: Double = 4
        /// 8 points.
        public static let s: Double = 8
        /// 12 points.
        public static let m: Double = 12
        /// 16 points.
        public static let l: Double = 16
        /// 24 points.
        public static let xl: Double = 24
        /// 40 points.
        public static let xxl: Double = 40
    }

    /// Corners, borders, and the focus border. Verba draws sharp, flat panes with no shadows.
    nonisolated public enum Shape {
        /// Corner radius of panes, controls, and tokens.
        public static let cornerRadius: Double = 2
        /// Width of hairlines and control borders.
        public static let borderWidth: Double = 1
        /// Width of the sage border a focused control draws.
        public static let focusBorderWidth: Double = 2
        /// Opacity of a button while it is held down.
        public static let pressedOpacity: Double = 0.8
    }

    /// Animation timings. Both are switched off when Reduce Motion is on.
    nonisolated public enum Motion {
        /// How long the feedback panel takes to fade and slide in.
        public static let feedbackRevealDuration: Double = 0.15
        /// One full on and off cycle of the checking cursor.
        public static let cursorBlinkPeriod: Duration = .seconds(1)

        /// The feedback reveal animation, or `nil` (no animation) under Reduce Motion.
        public static func feedbackReveal(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: feedbackRevealDuration)
        }
    }

    /// Fixed print sizes in points. Paper does not follow the screen text size; `design.md`
    /// lists the same values (`DesignDocTests` compares them).
    nonisolated public enum Print {
        /// Lesson title, New York bold.
        public static let title: Double = 20
        /// Headings, New York bold.
        public static let heading: Double = 14
        /// Body text, New York.
        public static let body: Double = 11
        /// Code, SF Mono.
        public static let code: Double = 10
        /// Labels, SF Mono.
        public static let label: Double = 9
        /// Page margin on every side.
        public static let margin: Double = 72
    }

    /// The width of the reading column at default text size, in points.
    nonisolated public static let baseReadingWidth: Double = 680

    /// The reading column's maximum width: it widens in proportion to the text size.
    nonisolated public static func readingWidth(for size: TextSize) -> Double {
        baseReadingWidth * size.scale
    }
}
