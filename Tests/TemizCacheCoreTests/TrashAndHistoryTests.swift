import XCTest
@testable import TemizCacheCore

final class TrashTests: XCTestCase {
    var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("temizcache-trash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    func testMissingTrashIsEmptyAndReadable() {
        let status = TrashInspector.inspect(home: home)
        XCTAssertTrue(status.readable)
        XCTAssertTrue(status.isEmpty)
    }

    func testInspectCountsTopLevelItemsAndIgnoresDSStore() throws {
        let trash = TrashInspector.trashURL(home: home)
        try FileManager.default.createDirectory(at: trash.appendingPathComponent("folder"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_000).write(to: trash.appendingPathComponent("folder/a.bin"))
        try Data(repeating: 1, count: 6_000).write(to: trash.appendingPathComponent("b.bin"))
        try Data().write(to: trash.appendingPathComponent(".DS_Store"))

        let status = TrashInspector.inspect(home: home)
        XCTAssertTrue(status.readable)
        XCTAssertEqual(status.itemCount, 2)
        XCTAssertGreaterThanOrEqual(status.bytes, 10_000)
    }

    func testEmptyDirectlyRemovesEverythingButKeepsFolder() throws {
        let trash = TrashInspector.trashURL(home: home)
        try FileManager.default.createDirectory(at: trash.appendingPathComponent("x/y"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: trash.appendingPathComponent("x/y/z.bin"))
        try Data(repeating: 1, count: 100).write(to: trash.appendingPathComponent("w.bin"))

        let report = TrashInspector.emptyDirectly(home: home)
        XCTAssertEqual(report.removedItems, 2)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
        XCTAssertTrue(TrashInspector.inspect(home: home).isEmpty)
    }

    func testEmptyDirectlyDoesNotFollowLinksOutOfTrash() throws {
        let precious = home.appendingPathComponent("Documents/precious")
        try FileManager.default.createDirectory(at: precious, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: precious.appendingPathComponent("keep.bin"))
        let trash = TrashInspector.trashURL(home: home)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: trash.appendingPathComponent("link"), withDestinationURL: precious)

        _ = TrashInspector.emptyDirectly(home: home)
        XCTAssertTrue(FileManager.default.fileExists(atPath: precious.appendingPathComponent("keep.bin").path))
    }

    func testSymlinkedTrashIsRefused() throws {
        let elsewhere = home.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: elsewhere.appendingPathComponent("keep.bin"))
        try FileManager.default.createSymbolicLink(at: TrashInspector.trashURL(home: home), withDestinationURL: elsewhere)

        let report = TrashInspector.emptyDirectly(home: home)
        XCTAssertEqual(report.refused.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent("keep.bin").path))
    }
}

final class HistoryAndDiskTests: XCTestCase {
    func testHistoryOrderingTrimAndLifetime() {
        var history = CleanHistory()
        for i in 1...(CleanHistory.maxEntries + 5) {
            history.record(.init(date: Date(timeIntervalSince1970: Double(i)), bytes: 10, items: 1, kind: .caches, targets: ["t"]))
        }
        XCTAssertEqual(history.entries.count, CleanHistory.maxEntries)
        XCTAssertEqual(history.entries.first?.date, Date(timeIntervalSince1970: Double(CleanHistory.maxEntries + 5)))
        XCTAssertEqual(history.lifetimeBytes, Int64(10 * (CleanHistory.maxEntries + 5)))
    }

    func testHistoryIgnoresEmptyRunsAndRoundTrips() {
        var history = CleanHistory()
        history.record(.init(bytes: 0, items: 0, kind: .trash, targets: []))
        XCTAssertTrue(history.entries.isEmpty)
        history.record(.init(bytes: 1_024, items: 3, kind: .trash, targets: ["Trash"]))
        let decoded = CleanHistory.decode(history.encoded())
        XCTAssertEqual(decoded, history)
        XCTAssertEqual(CleanHistory.decode(Data("junk".utf8)), CleanHistory())
        XCTAssertEqual(CleanHistory.decode(nil), CleanHistory())
    }

    func testDiskSpaceFraction() {
        XCTAssertEqual(DiskSpace(total: 100, available: 25).usedFraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(DiskSpace(total: 0, available: 0).usedFraction, 0)
        XCTAssertEqual(DiskSpace(total: 100, available: 200).used, 0)
        XCTAssertNotNil(DiskSpace.forVolume(containing: FileManager.default.temporaryDirectory))
    }
}

final class ByteTextTests: XCTestCase {
    func testZeroIsNumeric() {
        XCTAssertFalse(ByteText.string(0).lowercased().contains("zero"))
    }
}
