import SwiftUI

/// The terminal block cursor shown while an answer is being checked. It blinks once per second,
/// stays solid under Reduce Motion, and is hidden from VoiceOver (the panel says "Checking").
public struct BlinkingCursor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = true

    /// Creates the cursor.
    public init() {}

    /// The blinking block.
    public var body: some View {
        Text(verbatim: "▍")
            .themeFont(.code)
            .foregroundStyle(Theme.accent)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                isVisible = true
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: Theme.Motion.cursorBlinkPeriod / 2)
                    } catch {
                        return
                    }
                    isVisible.toggle()
                }
            }
    }
}

#Preview {
    HStack(spacing: 0) {
        TerminalLabel("Checking…")
        BlinkingCursor()
    }
    .padding()
    .background(Theme.background)
}
