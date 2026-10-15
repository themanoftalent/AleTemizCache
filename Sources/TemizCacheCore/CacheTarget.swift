import Foundation

/// A group of folders that one tool or app uses as disposable cache.
public struct CacheTarget: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case developer
        case packageManager
        case browser
        case app
        case logs
        case custom

        public var title: String {
            switch self {
            case .developer: return "Developer Tools"
            case .packageManager: return "Package Managers"
            case .browser: return "Browsers"
            case .app: return "Apps"
            case .logs: return "Logs"
            case .custom: return "Custom"
            }
        }

        public var symbol: String {
            switch self {
            case .developer: return "hammer"
            case .packageManager: return "shippingbox"
            case .browser: return "globe"
            case .app: return "app.badge"
            case .logs: return "doc.plaintext"
            case .custom: return "folder.badge.gearshape"
            }
        }
    }

    public let id: String
    public let title: String
    public let summary: String
    public let kind: Kind
    /// Paths that may start with `~`. Each path names a folder whose contents get removed.
    public let paths: [String]
    /// Optional warning shown next to the item, e.g. "Rebuilds on next device connect".
    public let caution: String?

    public init(id: String, title: String, summary: String, kind: Kind, paths: [String], caution: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.kind = kind
        self.paths = paths
        self.caution = caution
    }

    /// Expands `~` against the given home directory and standardizes the result.
    public func resolvedURLs(home: URL) -> [URL] {
        paths.map { PathPolicy.expand($0, home: home) }
    }
}
