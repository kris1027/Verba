import SwiftUI

/// Gallery section: every type token at the current text size, with its font and use.
struct TypeSection: View {
    @Environment(\.textSize) private var textSize

    var body: some View {
        GallerySection(title: "Type") {
            TerminalLabel("Text size · \(textSize.name) · scale \(textSize.scale.formatted(.number))")
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ForEach(ThemeFont.allCases, id: \.self) { font in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        TerminalLabel("\(font.name) · \(font.galleryDescription)")
                        Text(verbatim: font.gallerySample)
                            .themeFont(font)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

extension ThemeFont {
    /// The font in words, as the gallery shows it.
    fileprivate var galleryDescription: String {
        switch self {
        case .readingTitle: "New York, large title, bold"
        case .readingHeading: "New York, title 2, bold"
        case .readingBody: "New York, title 2, line spacing xs"
        case .ui: "SF Pro, body"
        case .label: "SF Mono, callout, uppercase, tracking 0.5"
        case .code: "SF Mono, body"
        }
    }

    /// Sample text in the languages Verba teaches with.
    fileprivate var gallerySample: String {
        switch self {
        case .readingTitle: "Ser i estar: dwa czasowniki „być”"
        case .readingHeading: "Kiedy używamy ser"
        case .readingBody:
            "Hiszpański ma dwa czasowniki znaczące „być”. Ser opisuje cechy stałe, a estar stany "
                + "i położenie. Porównaj: Soy de Polonia oraz Estoy en Madrid."
        case .ui: "Check · Next · Try Again"
        case .label: "Exercise 03/08 · translate"
        case .code: "estoy cansado"
        }
    }
}

extension TextSize {
    /// The step's case name, as the gallery and `design.md` write it.
    var name: String {
        switch self {
        case .xSmall: "xSmall"
        case .small: "small"
        case .medium: "medium"
        case .large: "large"
        case .xLarge: "xLarge"
        case .xxLarge: "xxLarge"
        case .xxxLarge: "xxxLarge"
        case .accessibility1: "accessibility1"
        case .accessibility2: "accessibility2"
        case .accessibility3: "accessibility3"
        }
    }
}
