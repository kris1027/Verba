import Foundation

/// A `MAJOR.MINOR.PATCH` version, compared as a triple of integers.
struct CLIVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    var major: Int
    var minor: Int
    var patch: Int

    /// The first `MAJOR.MINOR.PATCH` in the text; any suffix such as `-beta` is ignored.
    init?(firstMatchIn text: String) {
        guard let match = text.firstMatch(of: /(\d+)\.(\d+)\.(\d+)/),
            let major = Int(match.1), let minor = Int(match.2), let patch = Int(match.3)
        else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// Reads `loggedIn` from `claude auth status --json`.
enum AuthStatus {
    /// `loggedIn` when stdout is a JSON object holding it as a Boolean, else nil.
    static func loggedIn(from stdout: Data) -> Bool? {
        struct Body: Decodable { let loggedIn: Bool }
        return try? JSONDecoder().decode(Body.self, from: stdout).loggedIn
    }
}
