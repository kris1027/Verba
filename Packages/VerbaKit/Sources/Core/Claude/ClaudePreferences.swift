import Foundation

/// The Claude model that teaches you. Raw values are the CLI's model aliases.
public enum ClaudeModel: String, Sendable, Hashable, CaseIterable {
    /// Balanced quality and plan usage. The default.
    case sonnet
    /// The highest quality, using the most plan usage.
    case opus
    /// The fastest, using the least plan usage.
    case haiku

    /// The model used when nothing is saved, or the saved value is unknown.
    public static let defaultModel = ClaudeModel.sonnet
}

/// The Claude settings the bridge reads at the start of each call.
public struct ClaudePreferences: Sendable, Hashable {
    /// The `UserDefaults` key for the model choice.
    public static let modelKey = "claude.model"
    /// The `UserDefaults` key for the saved `claude` path. Missing or empty means automatic.
    public static let cliPathKey = "claude.cliPath"

    /// The model passed as `--model`.
    public let model: ClaudeModel
    /// The `claude` program you chose in Settings, or nil to search automatically.
    public let cliPath: URL?

    /// Creates preferences from values.
    public init(model: ClaudeModel = .defaultModel, cliPath: URL? = nil) {
        self.model = model
        self.cliPath = cliPath
    }

    /// Creates preferences from the raw saved values. A missing or unknown model means `sonnet`;
    /// a missing or empty path means automatic.
    public init(savedModel: String?, savedPath: String?) {
        model = savedModel.flatMap(ClaudeModel.init(rawValue:)) ?? .defaultModel
        if let savedPath, !savedPath.isEmpty {
            cliPath = URL(filePath: savedPath)
        } else {
            cliPath = nil
        }
    }
}
