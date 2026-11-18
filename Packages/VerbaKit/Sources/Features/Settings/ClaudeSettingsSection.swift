import Core
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// The **Claude** section of Settings: status, the `claude` path, the model, Check again, and a test prompt.
struct ClaudeSettingsSection: View {
    @State private var model: ClaudeSettingsModel
    /// A plain path; nil (the key removed) means automatic.
    @AppStorage(ClaudePreferences.cliPathKey) private var savedPath: String?
    @AppStorage(ClaudePreferences.modelKey) private var claudeModel: ClaudeModel = .defaultModel
    @State private var isChoosingPath = false

    init(connection: any ClaudeConnection) {
        _model = State(initialValue: ClaudeSettingsModel(connection: connection))
    }

    var body: some View {
        Section("Claude") {
            LabeledContent("Status") {
                statusLine
            }
            .accessibilityElement(children: .combine)

            LabeledContent("Claude Code") {
                VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
                    Text(pathDescription)
                        .themeFont(.code)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Path in use: \(pathDescription)")
                    HStack {
                        Button("Choose…") { isChoosingPath = true }
                            .accessibilityLabel("Choose Claude Code program")
                            .accessibilityHint("Pick the claude program Verba should run.")
                        Button("Use Automatic") { savedPath = nil }
                            .disabled(savedPath == nil)
                            .accessibilityHint("Forget the chosen path and search the usual install folders.")
                    }
                }
            }

            Picker("Model", selection: $claudeModel) {
                ForEach(ClaudeModel.allCases, id: \.self) { option in
                    Text(option.title)
                        .tag(option)
                        .accessibilityHint(option.tradeoff)
                }
            }
            .accessibilityHint("The Claude model that writes your lessons.")

            LabeledContent("Connection") {
                HStack {
                    Button("Check Again") {
                        Task { await model.checkAgain() }
                    }
                    .accessibilityHint("Checks the Claude Code install and sign in again.")
                    Button("Send Test Prompt") {
                        Task { await model.sendTestPrompt() }
                    }
                    .disabled(model.isTesting)
                    .accessibilityHint("Sends one short prompt to Claude to prove the connection works.")
                }
            }

            if model.test != .idle {
                testResult
            }
        }
        .task { await model.loadStatus() }
        .onChange(of: savedPath) {
            Task { await model.checkAgain() }
        }
        .fileImporter(isPresented: $isChoosingPath, allowedContentTypes: [.unixExecutable, .item]) { result in
            if case .success(let url) = result {
                savedPath = url.path(percentEncoded: false)
            }
        }
        .fileDialogBrowserOptions(.includeHiddenFiles)
    }

    @ViewBuilder private var statusLine: some View {
        switch model.status {
        case .checking: ProgressLine(text: model.statusText)
        case .ready: StatusMessage(text: model.statusText, isProblem: false)
        case .problem: StatusMessage(text: model.statusText, isProblem: true)
        }
    }

    @ViewBuilder private var testResult: some View {
        switch model.test {
        case .idle: EmptyView()
        case .running: ProgressLine(text: "Waiting for Claude…")
        case .succeeded(let message): StatusMessage(text: message, isProblem: false)
        case .failed(let message): StatusMessage(text: message, isProblem: true)
        }
    }

    private var pathDescription: String {
        if let pathInUse = model.pathInUse { return pathInUse }
        if let savedPath { return savedPath }
        return "Automatic"
    }
}

/// A small spinner with the text of what is running, read as one element by VoiceOver.
private struct ProgressLine: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ProgressView()
                .controlSize(.small)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A result line: a mint checkmark when all is well, an amber warning for a problem.
private struct StatusMessage: View {
    let text: String
    let isProblem: Bool

    var body: some View {
        Label(text, systemImage: isProblem ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .labelStyle(StatusLabelStyle(tint: isProblem ? Theme.partly : Theme.correct))
    }
}

/// A status message in the primary text color (for contrast), with only the icon tinted.
private struct StatusLabelStyle: LabelStyle {
    let tint: ThemeColor

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            configuration.icon
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            configuration.title
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
