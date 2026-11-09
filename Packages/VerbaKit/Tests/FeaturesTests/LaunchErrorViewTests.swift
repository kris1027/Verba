import AppKit
import Features
import SwiftUI
import Testing

/// AC-12: the screen builds and keeps its minimum size. Pressing its buttons needs a real accessibility client,
/// so that stays with the manual steps in `verify.md` until `AppUITests` arrives.
@MainActor
struct LaunchErrorViewTests {
    @Test(arguments: ["Short.", String(repeating: "A very long explanation of what went wrong. ", count: 20)])
    func theScreenKeepsItsMinimumSizeForAnyMessage(message: String) {
        let host = NSHostingView(rootView: LaunchErrorView(message: message, showDatabase: {}, quit: {}))

        #expect(host.fittingSize.width >= 480)
        #expect(host.fittingSize.height >= 320)
    }
}
