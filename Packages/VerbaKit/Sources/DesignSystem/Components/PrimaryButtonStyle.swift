import SwiftUI

/// The primary action: sage fill with dark text, sharp corners, and the sage focus border.
/// Disabled, it shows an outline with tertiary text, which still meets AA contrast.
public struct PrimaryButtonStyle: ButtonStyle {
    /// Creates the style.
    public init() {}

    /// The styled button.
    public func makeBody(configuration: Configuration) -> some View {
        VerbaButtonBody(configuration: configuration, isPrimary: true)
    }
}

/// A secondary action: a control border outline with primary text.
public struct SecondaryButtonStyle: ButtonStyle {
    /// Creates the style.
    public init() {}

    /// The styled button.
    public func makeBody(configuration: Configuration) -> some View {
        VerbaButtonBody(configuration: configuration, isPrimary: false)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Verba's primary button: sage fill.
    public static var verbaPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Verba's secondary button: outlined.
    public static var verbaSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Shared drawing for both styles; a view so it can read the enabled and focus state.
private struct VerbaButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .themeFont(.ui)
            .foregroundStyle(foreground)
            .padding(.vertical, Theme.Spacing.s)
            .padding(.horizontal, Theme.Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .strokeBorder(border, lineWidth: Theme.Shape.borderWidth)
            }
            .opacity(configuration.isPressed ? Theme.Shape.pressedOpacity : 1)
            .contentShape(.rect)
            .focusBorder(isFocused)
    }

    private var isFilled: Bool { isPrimary && isEnabled }

    private var foreground: ThemeColor {
        if !isEnabled { return Theme.textTertiary }
        return isPrimary ? Theme.onAccent : Theme.text
    }

    private var fill: ThemeColor {
        isFilled ? Theme.accent : Theme.surface
    }

    private var border: ThemeColor {
        isFilled ? Theme.accent : Theme.controlBorder
    }
}

#Preview {
    HStack {
        Button("Check") {}.buttonStyle(.verbaPrimary)
        Button("Check") {}.buttonStyle(.verbaPrimary).disabled(true)
        Button("Try Again") {}.buttonStyle(.verbaSecondary)
    }
    .padding()
    .background(Theme.background)
}
