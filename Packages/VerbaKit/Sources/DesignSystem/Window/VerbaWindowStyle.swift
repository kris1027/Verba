import SwiftUI

extension View {
    /// The styling every Verba window root applies: dark color scheme and sage tinted controls.
    public func verbaWindowStyle() -> some View {
        preferredColorScheme(.dark)
            .tint(Theme.accent)
    }
}
