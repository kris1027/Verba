import Foundation

/// A validated BCP 47 language tag in canonical form, such as `pl`, `es`, or `pt-BR`.
public struct LanguageTag: Sendable, Hashable {
    /// The canonical tag: lowercase language, then any script and region the input named.
    public let rawValue: String

    /// Validates and canonicalizes a tag.
    /// - Throws: `ValidationError.invalidLanguageTag` for an empty or malformed string.
    public init(_ string: String) throws(ValidationError) {
        guard Self.isWellFormed(string) else { throw .invalidLanguageTag }
        // `Components` keeps only what the tag named; `Locale.Language` would add a likely script (`pl-Latn`).
        let components = Locale.Language.Components(identifier: string)
        guard let language = components.languageCode?.identifier, language != "und" else {
            throw .invalidLanguageTag
        }
        rawValue = [language, components.script?.identifier, components.region?.identifier]
            .compactMap(\.self)
            .joined(separator: "-")
    }

    /// ASCII letters, digits, and `-` only, no empty subtag, and a primary subtag of 2 or 3 letters.
    private static func isWellFormed(_ string: String) -> Bool {
        guard string.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return false }
        let subtags = string.split(separator: "-", omittingEmptySubsequences: false)
        guard subtags.allSatisfy({ !$0.isEmpty }), let primary = subtags.first else { return false }
        return (2...3).contains(primary.count) && primary.allSatisfy(\.isLetter)
    }
}
