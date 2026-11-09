import Core
import Testing

struct LanguageTagTests {
    @Test(arguments: [
        ("pl", "pl"), ("PL", "pl"), ("es", "es"), ("pt-BR", "pt-BR"), ("pt-br", "pt-BR"), ("zh-Hant-TW", "zh-Hant-TW"),
        ("es-419", "es-419"), ("iw", "he"), ("in", "id"), ("tl", "fil"), ("pol", "pl"),
    ])
    func validTagsAreCanonicalized(input: String, canonical: String) throws {
        let tag = try LanguageTag(input)
        #expect(tag.rawValue == canonical)
        #expect(try LanguageTag(tag.rawValue) == tag)  // stored tags are parsed again on every read
    }

    @Test func aDeprecatedCodeIsTheSameLanguageAsItsReplacement() throws {
        #expect(try LanguageTag("iw") == LanguageTag("he"))
    }

    @Test(arguments: [
        "", " ", "es_ES", "e s", "12", "a", "-es", "es-", "es--MX", "abcdefghijk", "x-foo", "und", "język",
        "en-thisisnotasubtag", "en-1", "pl-123456789", "en-US-US-US", "ca-valencia", "en-Latn-Latn", "en-US-Latn",
        "en-US-u-ca-gregory",
    ])
    func malformedTagsThrow(input: String) {
        #expect(throws: ValidationError.invalidLanguageTag) {
            try LanguageTag(input)
        }
    }

    @Test func aCourseCannotTeachALanguageThroughItself() throws {
        let polish = try LanguageTag("pl")
        #expect(throws: ValidationError.sameLanguage) {
            try Course.validateLanguages(target: polish, native: polish)
        }
    }
}
