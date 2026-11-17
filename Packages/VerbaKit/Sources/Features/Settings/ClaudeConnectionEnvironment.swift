import Core
import SwiftUI

extension EnvironmentValues {
    /// The connection to Claude Code, set by the app's composition root. Nil when the app could not launch.
    @Entry public var claudeConnection: (any ClaudeConnection)?
}
