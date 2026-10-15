import Foundation

/// A record of past cleanups, persisted as JSON.
public struct CleanHistory: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Identifiable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case caches
            case trash
        }

        public let id: UUID
        public let date: Date
        public let bytes: Int64
        public let items: Int
        public let kind: Kind
        public let targets: [String]

        public init(id: UUID = UUID(), date: Date = Date(), bytes: Int64, items: Int, kind: Kind, targets: [String]) {
            self.id = id
            self.date = date
            self.bytes = bytes
            self.items = items
            self.kind = kind
            self.targets = targets
        }
    }

    public static let maxEntries = 50

    public private(set) var entries: [Entry] = []
    /// Lifetime total. Kept separately so it survives trimming of old entries.
    public private(set) var lifetimeBytes: Int64 = 0

    public init() {}

    /// Adds an entry, newest first. Zero-byte runs are ignored.
    public mutating func record(_ entry: Entry) {
        guard entry.bytes > 0 || entry.items > 0 else { return }
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
        lifetimeBytes += max(0, entry.bytes)
    }

    public mutating func clear() {
        entries = []
        lifetimeBytes = 0
    }

    public var lastRun: Date? { entries.first?.date }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ data: Data?) -> CleanHistory {
        guard let data, let value = try? JSONDecoder().decode(CleanHistory.self, from: data) else { return CleanHistory() }
        return value
    }
}
