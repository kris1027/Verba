import Core

extension ClaudeModel {
    /// The name shown in the Model picker.
    var title: String {
        switch self {
        case .sonnet: "Sonnet"
        case .opus: "Opus"
        case .haiku: "Haiku"
        }
    }

    /// What choosing the model means for you, read by VoiceOver.
    var tradeoff: String {
        switch self {
        case .sonnet: "Balanced quality and plan usage"
        case .opus: "Highest quality, uses the most plan usage"
        case .haiku: "Fastest, uses the least plan usage"
        }
    }
}
