import SwiftUI

/// One opaque color as 8 bit sRGB components, built from a hex value.
///
/// The palettes hold `RGB` values, not `Color`, so tests and the print builder can compute
/// contrast without a view environment.
nonisolated public struct RGB: Hashable, Sendable {
    /// Red component, 0 to 255.
    public let red: UInt8
    /// Green component, 0 to 255.
    public let green: UInt8
    /// Blue component, 0 to 255.
    public let blue: UInt8

    /// Creates a color from a 24 bit hex value such as `0x0E100F`.
    public init(hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    /// The color as an uppercase `#RRGGBB` string, the form `design.md` uses.
    public var hexString: String {
        "#" + [red, green, blue].map { String(format: "%02X", $0) }.joined()
    }

    /// WCAG 2 relative luminance, from 0 (black) to 1 (white).
    public var relativeLuminance: Double {
        func linear(_ component: UInt8) -> Double {
            let value = Double(component) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The SwiftUI color for this value in the sRGB color space.
    public var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
