import Core
import Foundation

/// One versioned prompt, ready to send: the system text, the user message, and the reply schema.
struct Prompt: Sendable, Hashable {
    /// The resource file stem, saved as `promptVersion`.
    var version: String
    var system: String
    var user: String
    var schema: String

    /// Loads `<version>.system.md`, `<version>.user.md`, and `<version>.schema.json`, filling the user template.
    static func load(_ version: String, values: [String: String] = [:]) throws(ClaudeError) -> Prompt {
        let system = try resource(version, "system", "md")
        let user = try resource(version, "user", "md")
        let schema = try resource(version, "schema", "json")
        return Prompt(
            version: version,
            system: system.trimmingCharacters(in: .whitespacesAndNewlines),
            user: render(user, values: values).trimmingCharacters(in: .whitespacesAndNewlines),
            schema: schema)
    }

    /// The text of one prompt resource in `Resources/Prompts`.
    static func resource(_ version: String, _ part: String, _ fileExtension: String) throws(ClaudeError) -> String {
        guard
            let url = Bundle.module.url(
                forResource: "\(version).\(part)", withExtension: fileExtension, subdirectory: "Prompts")
        else {
            throw .failed(reason: "Missing prompt resource \(version).\(part).\(fileExtension)")
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw .failed(reason: "Unreadable prompt resource \(version).\(part): \(error)")
        }
    }

    /// Replaces each `{{name}}` in one left to right pass. Inserted values are never expanded again,
    /// so a value holding `{{` stays literal. Unknown placeholders stay as written.
    static func render(_ template: String, values: [String: String]) -> String {
        var output = ""
        var rest = template[...]
        while let open = rest.range(of: "{{") {
            output += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]
            if let close = afterOpen.range(of: "}}"), let value = values[String(afterOpen[..<close.lowerBound])] {
                output += value
                rest = afterOpen[close.upperBound...]
            } else {
                output += "{{"
                rest = afterOpen
            }
        }
        return output + rest
    }
}
