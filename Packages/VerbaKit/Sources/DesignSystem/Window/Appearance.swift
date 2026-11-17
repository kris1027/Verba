import AppKit

/// The app wide appearance. Verba's screen is dark only, whatever the macOS setting.
public enum Appearance {
    /// Forces the dark aqua appearance on the whole app, so menus, alerts, and system panels
    /// match the dark content. Call it once, before the first window appears.
    public static func applyDark() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }
}
