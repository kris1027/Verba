import SwiftUI

/// Gallery section: Markdown the renderer does not know (shown as plain text) and a table wider
/// than the reading column (scrolls sideways).
struct MarkdownEdgeSection: View {
    private static let markdown = """
        Raw HTML and a thematic break are shown as plain text:

        <div class="note">To jest blok HTML.</div>

        ---

        | Osoba | ser (presente) | estar (presente) | ser (indefinido) | estar (indefinido) | ser (imperfecto) |
        |:--|:--|:--|:--|:--|:--|
        | yo | soy | estoy | fui | estuve | era |
        | vosotros | sois | estáis | fuisteis | estuvisteis | erais |
        """

    var body: some View {
        GallerySection(title: "Markdown edge cases") {
            MarkdownText(markdown: Self.markdown)
                .readingColumnWidth()
        }
    }
}
