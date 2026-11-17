import SwiftUI

extension View {
    /// Draws the sage focus border (2 points) when `isFocused` is true and turns off the system
    /// focus effect, so the focus indicator is always sage. Use it on every focusable component.
    public func focusBorder(_ isFocused: Bool) -> some View {
        focusEffectDisabled()
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                        .strokeBorder(Theme.accent, lineWidth: Theme.Shape.focusBorderWidth)
                        .allowsHitTesting(false)
                }
            }
    }
}
