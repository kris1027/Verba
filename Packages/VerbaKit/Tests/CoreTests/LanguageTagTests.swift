import Core
import Testing

struct LanguageTagTests {
    @Test(arguments: [
        ("pl", "pl"), ("PL", "pl"), ("es", "es"), ("pt-BR", "pt-BR"), ("pt-br", "pt-BR"), ("zh-Hant-TW", "zh-Hant-TW"),
        ("es-419", "es-419"),
    ])
    func validTagsAreCanonicalized(input: String, canonical: String) throws {
        #expect(try LanguageTag(input).rawValue == canonical)
    }

    @Test(arguments: [
        "", " ", "es_ES", "e s", "12", "a", "-es", "es-", "es--MX", "abcdefghijk", "x-foo", "und", "język",
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
