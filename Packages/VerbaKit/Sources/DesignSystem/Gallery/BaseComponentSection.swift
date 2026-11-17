import SwiftUI

/// Gallery section: labels, both button styles in every state, and the checking cursor.
struct BaseComponentSection: View {
    var body: some View {
        GallerySection(title: "Base components") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TerminalLabel("TerminalLabel")
                TerminalLabel("Lesson · Spanish · ser and estar")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TerminalLabel("Buttons · enabled · disabled · secondary")
                HStack(spacing: Theme.Spacing.m) {
                    Button("Check") {}
                        .buttonStyle(.verbaPrimary)
                    Button("Check") {}
                        .buttonStyle(.verbaPrimary)
                        .disabled(true)
                    Button("Next") {}
                        .buttonStyle(.verbaPrimary)
                    Button("Try Again") {}
                        .buttonStyle(.verbaSecondary)
                    Button("Try Again") {}
                        .buttonStyle(.verbaSecondary)
                        .disabled(true)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TerminalLabel("BlinkingCursor")
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Checking…")
                        .themeFont(.code)
                        .foregroundStyle(Theme.textSecondary)
                    BlinkingCursor()
                }
            }
        }
    }
}
