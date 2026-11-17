import DesignSystem
import SwiftUI

/// The main window: a sidebar of sections and an empty detail area.
/// Each slice replaces one placeholder with its real screen.
public struct RootView: View {
    @State private var selection: SidebarItem? = .home

    /// Creates the main window with Home selected.
    public init() {}

    /// The split view: sidebar on the left, the selected section on the right.
    public var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                if let selection {
                    SectionPlaceholder(item: selection)
                        .navigationTitle(selection.title)
                } else {
                    SectionPlaceholder(item: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .verbaContentFont()
        }
    }
}

#Preview {
    RootView()
}
