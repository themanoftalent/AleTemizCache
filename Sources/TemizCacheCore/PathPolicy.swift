import Foundation

/// Decides which folders AleTemizCache is allowed to empty.
///
/// A cleaner that deletes the wrong folder destroys user data, so every path passes
/// through this check before any size scan or removal. User supplied definitions
/// get the same treatment as the built-in catalog.
public enum PathPolicy {
    public enum Violation: Error, Equatable, CustomStringConvertible {
        case notAbsolute(String)
        case containsTraversal(String)
        case outsideAllowedRoots(String)
        case isAllowedRootItself(String)

        public var description: String {
            switch self {
            case .notAbsolute(let p): return "Path is not absolute: \(p)"
            case .containsTraversal(let p): return "Path contains '..': \(p)"
            case .outsideAllowedRoots(let p): return "Path is outside the allowed cache locations: \(p)"
            case .isAllowedRootItself(let p): return "Refusing to empty a top-level location: \(p)"
            }
        }
    }

    /// Roots, relative to the home folder, under which cache folders may live.
    public static let allowedRoots: [String] = [
        "Library/Caches",
        "Library/Logs",
        "Library/Developer",
        "Library/Application Support",
        ".npm",
        ".gradle",
        ".cargo",
        ".cache"
    ]

    public static func expand(_ raw: String, home: URL) -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "~" { return home.standardizedFileURL }
        if trimmed.hasPrefix("~/") {
            return home.appendingPathComponent(String(trimmed.dropFirst(2))).standardizedFileURL
        }
        return URL(fileURLWithPath: trimmed).standardizedFileURL
    }

    /// Throws if `url` may not be emptied. The target must sit strictly below one of
    /// `allowedRoots`, and must be at least two components deep below `Library/Application Support`,
    /// so that a definition such as `~/Library/Application Support/Google` cannot wipe a whole vendor folder.
    public static func validate(_ url: URL, home: URL) throws {
        let raw = url.path
        guard raw.hasPrefix("/") else { throw Violation.notAbsolute(raw) }
        if url.pathComponents.contains("..") { throw Violation.containsTraversal(raw) }

        let target = url.standardizedFileURL.pathComponents
        let homeParts = home.standardizedFileURL.pathComponents

        for root in allowedRoots {
            let rootParts = homeParts + root.split(separator: "/").map(String.init)
            guard target.count >= rootParts.count,
                  Array(target.prefix(rootParts.count)) == rootParts else { continue }

            let depthBelowRoot = target.count - rootParts.count
            if depthBelowRoot == 0 { throw Violation.isAllowedRootItself(raw) }
            if root == "Library/Application Support" && depthBelowRoot < 2 {
                throw Violation.isAllowedRootItself(raw)
            }
            return
        }
        throw Violation.outsideAllowedRoots(raw)
    }

    public static func isAllowed(_ url: URL, home: URL) -> Bool {
        (try? validate(url, home: home)) != nil
    }
}
