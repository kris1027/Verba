/// WCAG 2 contrast between two colors, shared by the contrast test and the Design Gallery.
nonisolated public enum Contrast {
    /// The contrast ratio of two colors, from 1 (same luminance) to 21 (black on white).
    /// The order of the arguments does not matter.
    public static func ratio(_ first: RGB, _ second: RGB) -> Double {
        let lighter = max(first.relativeLuminance, second.relativeLuminance)
        let darker = min(first.relativeLuminance, second.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
