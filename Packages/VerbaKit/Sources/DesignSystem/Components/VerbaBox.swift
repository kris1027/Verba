import SwiftUI

extension View {
    /// Verba's box: a fill with the shared corner radius and a border of the shared width.
    /// Panes, controls, tokens, and buttons all draw their frame with it.
    func verbaBox(fill: some ShapeStyle, border: some ShapeStyle) -> some View {
        background(fill, in: .rect(cornerRadius: Theme.Shape.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Shape.cornerRadius)
                    .strokeBorder(border, lineWidth: Theme.Shape.borderWidth)
            }
    }
}
