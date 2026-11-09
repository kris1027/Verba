import Foundation

/// A validated BCP 47 language tag in canonical form, such as `pl`, `es`, or `pt-BR`.
public struct LanguageTag: Sendable, Hashable {
    /// The canonical tag: lowercase language, then any script and region the input named.
    public let rawValue: String

    /// Validates and canonicalizes a tag.
    /// - Throws: `ValidationError.invalidLanguageTag` for an empty or malformed string.
    public init(_ string: String) throws(ValidationError) {
        guard Self.isWellFormed(string) else { throw .invalidLanguageTag }
        // BCP 47 canonicalization replaces deprecated codes (`iw` becomes `he`), so one language has one tag.
        // `Components` keeps only what the tag named; `Locale.Language` would add a likely script (`pl-Latn`).
        let components = Locale.Language.Components(identifier: Locale.identifier(.bcp47, from: string))
        guard let language = components.languageCode?.identifier, language != "und" else {
            throw .invalidLanguageTag
        }
        rawValue = [language, components.script?.identifier, components.region?.identifier]
            .compactMap(\.self)
            .joined(separator: "-")
    }

    /// ASCII `language[-script][-region]` only: 2 or 3 letters, then 4 letters, then 2 letters or 3 digits.
    /// Anything else is rejected, because `Locale` would silently drop the part it can't read.
    private static func isWellFormed(_ string: String) -> Bool {
        guard string.allSatisfy(\.isASCII) else { return false }
        var subtags = string.split(separator: "-", omittingEmptySubsequences: false)[...]
        guard let language = subtags.popFirst(), (2...3).contains(language.count), language.allSatisfy(\.isLetter)
        else { return false }
        if let script = subtags.first, script.count == 4, script.allSatisfy(\.isLetter) {
            subtags.removeFirst()
        }
        if let region = subtags.first,
            (region.count == 2 && region.allSatisfy(\.isLetter)) || (region.count == 3 && region.allSatisfy(\.isNumber))
        {
            subtags.removeFirst()
        }
        return subtags.isEmpty
    }
}
