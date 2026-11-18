import SwiftUI

/// A word or item a learner places or pairs: a bordered chip that is its own focus stop.
/// Space or a click activates it. A `›` marker and sage border show it is picked, and a tag
/// (such as a pair letter) can lead it.
struct TokenChip: View {
    let text: String
    var tag: String?
    var isPicked = false
    var isFilled = false
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            if isPicked {
                Text(verbatim: "›")
                    .themeFont(.code)
                    .foregroundStyle(Theme.accent)
            }
            if let tag {
                Text(verbatim: tag)
                    .themeFont(.code)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(verbatim: text)
                .themeFont(.readingBody)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.m)
        .verbaBox(fill: isFilled ? Theme.raised : Theme.surface, border: isPicked ? Theme.accent : Theme.controlBorder)
        .focusBorder(isFocused)
        .contentShape(.rect)
    }
}

extension View {
    /// Makes a chip a focus stop that Space and a click activate, and a button for VoiceOver.
    func chipInteraction(isLocked: Bool, activate: @escaping () -> Void) -> some View {
        focusable(!isLocked)
            .onKeyPress(.space) {
                guard !isLocked else { return .ignored }
                activate()
                return .handled
            }
            .onTapGesture {
                guard !isLocked else { return }
                activate()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                guard !isLocked else { return }
                activate()
            }
    }
}
