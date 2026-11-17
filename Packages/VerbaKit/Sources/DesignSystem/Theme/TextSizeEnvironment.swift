import SwiftUI

extension EnvironmentValues {
    /// The text size step for this window, set by `.verbaWindowStyle()` from the saved preference.
    @Entry public var textSize: TextSize = .defaultSize
}
