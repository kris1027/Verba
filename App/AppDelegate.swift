import AppKit
import DesignSystem

/// Forces the dark appearance before the first window appears, so system panels match too.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        Appearance.applyDark()
    }
}
