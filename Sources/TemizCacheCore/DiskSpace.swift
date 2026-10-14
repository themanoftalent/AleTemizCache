import Foundation

/// Capacity of the volume that holds the home folder.
public struct DiskSpace: Equatable, Sendable {
    public let total: Int64
    public let available: Int64

    public init(total: Int64, available: Int64) {
        self.total = total
        self.available = available
    }

    public var used: Int64 { max(0, total - available) }

    /// Fraction of the disk in use, 0...1.
    public var usedFraction: Double {
        total > 0 ? min(1, max(0, Double(used) / Double(total))) : 0
    }

    public static func forVolume(containing url: URL) -> DiskSpace? {
        #if os(macOS)
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys), let total = values.volumeTotalCapacity else { return nil }
        // "Important usage" includes purgeable space macOS frees on demand, matching what Finder shows.
        let available = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskSpace(total: Int64(total), available: available)
        #else
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else { return nil }
        return DiskSpace(total: Int64(total), available: Int64(available))
        #endif
    }
}
