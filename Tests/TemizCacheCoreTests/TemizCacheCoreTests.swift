import XCTest
@testable import TemizCacheCore

final class PathPolicyTests: XCTestCase {
    let home = URL(fileURLWithPath: "/Users/tester")

    func testAllowsCacheSubfolder() {
        XCTAssertNoThrow(try PathPolicy.validate(home.appendingPathComponent("Library/Caches/Homebrew"), home: home))
    }

    func testRejectsRootsThemselves() {
        for root in PathPolicy.allowedRoots {
            XCTAssertThrowsError(try PathPolicy.validate(home.appendingPathComponent(root), home: home), root)
        }
    }

    func testRejectsHomeAndOutside() {
        XCTAssertThrowsError(try PathPolicy.validate(home, home: home))
        XCTAssertThrowsError(try PathPolicy.validate(home.appendingPathComponent("Documents"), home: home))
        XCTAssertThrowsError(try PathPolicy.validate(URL(fileURLWithPath: "/System/Library/Caches/x"), home: home))
        XCTAssertThrowsError(try PathPolicy.validate(URL(fileURLWithPath: "/Users/other/Library/Caches/x"), home: home))
    }

    func testRejectsTraversal() {
        let url = URL(fileURLWithPath: "/Users/tester/Library/Caches/../../Documents")
        XCTAssertThrowsError(try PathPolicy.validate(url, home: home))
        XCTAssertThrowsError(try PathPolicy.validate(PathPolicy.expand("~/Library/Caches/../../Documents", home: home), home: home))
    }

    func testApplicationSupportNeedsTwoLevels() {
        XCTAssertThrowsError(try PathPolicy.validate(home.appendingPathComponent("Library/Application Support/Google"), home: home))
        XCTAssertNoThrow(try PathPolicy.validate(home.appendingPathComponent("Library/Application Support/Slack/Cache"), home: home))
    }

    func testRejectsLookalikePrefix() {
        // "Library/CachesEvil" must not count as being inside "Library/Caches".
        XCTAssertThrowsError(try PathPolicy.validate(home.appendingPathComponent("Library/CachesEvil/x"), home: home))
    }

    func testEveryBuiltInPathIsAllowed() {
        for target in Catalog.builtIn {
            for url in target.resolvedURLs(home: home) {
                XCTAssertNoThrow(try PathPolicy.validate(url, home: home), "\(target.id): \(url.path)")
            }
        }
    }

    func testBuiltInIDsAreUnique() {
        let ids = Catalog.builtIn.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class FileSystemTests: XCTestCase {
    var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("temizcache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func write(_ relative: String, bytes: Int) throws {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
    }

    func testScanAndCleanKeepsFolder() throws {
        try write("Library/Caches/Demo/a.bin", bytes: 10_000)
        try write("Library/Caches/Demo/sub/b.bin", bytes: 20_000)
        try write("Documents/keep.txt", bytes: 100)

        let target = CacheTarget(id: "demo", title: "Demo", summary: "", kind: .custom, paths: ["~/Library/Caches/Demo"])
        XCTAssertGreaterThanOrEqual(SizeScanner.allocatedSize(of: target, home: home), 30_000)

        let report = Cleaner(home: home, mode: .delete).clean(target)
        XCTAssertEqual(report.removedItems, 2)
        XCTAssertTrue(report.failures.isEmpty)

        let folder = home.appendingPathComponent("Library/Caches/Demo")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent("Documents/keep.txt").path))
        XCTAssertEqual(SizeScanner.allocatedSize(of: target, home: home), 0)
    }

    func testDoesNotFollowSymlinkedCacheFolder() throws {
        try write("Documents/precious/data.bin", bytes: 5_000)
        let caches = home.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: caches.appendingPathComponent("Trap"),
            withDestinationURL: home.appendingPathComponent("Documents/precious")
        )

        let target = CacheTarget(id: "trap", title: "Trap", summary: "", kind: .custom, paths: ["~/Library/Caches/Trap"])
        XCTAssertEqual(SizeScanner.allocatedSize(of: target, home: home), 0)
        let report = Cleaner(home: home, mode: .delete).clean(target)
        XCTAssertEqual(report.removedItems, 0)
        XCTAssertEqual(report.refused.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent("Documents/precious/data.bin").path))
    }

    func testSymlinkInsideCacheIsRemovedNotFollowed() throws {
        try write("Documents/precious/data.bin", bytes: 5_000)
        let cache = home.appendingPathComponent("Library/Caches/Demo")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: cache.appendingPathComponent("link"),
            withDestinationURL: home.appendingPathComponent("Documents/precious")
        )
        let target = CacheTarget(id: "demo", title: "Demo", summary: "", kind: .custom, paths: ["~/Library/Caches/Demo"])
        _ = Cleaner(home: home, mode: .delete).clean(target)
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent("Documents/precious/data.bin").path))
    }

    func testUserDefinitionsMergeAndUnsafePathsDrop() throws {
        let json = """
        [
          {"id": "homebrew", "title": "Brew Override", "summary": "x", "kind": "packageManager", "paths": ["~/Library/Caches/Homebrew"]},
          {"id": "evil", "title": "Evil", "summary": "x", "kind": "custom", "paths": ["~/Documents", "~/Library/Caches/../../Desktop"]},
          {"id": "ok", "title": "OK", "summary": "x", "kind": "custom", "paths": ["~/Library/Caches/com.example"]}
        ]
        """
        let url = Catalog.userFileURL(home: home)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)

        let result = Catalog.load(home: home)
        let ids = result.targets.map(\.id)
        XCTAssertTrue(ids.contains("ok"))
        XCTAssertFalse(ids.contains("evil"))
        XCTAssertEqual(result.targets.first { $0.id == "homebrew" }?.title, "Brew Override")
        XCTAssertEqual(ids.filter { $0 == "homebrew" }.count, 1)
        XCTAssertEqual(result.warnings.count, 2)
    }

    func testBrokenUserFileProducesWarningNotCrash() throws {
        let url = Catalog.userFileURL(home: home)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not json".write(to: url, atomically: true, encoding: .utf8)
        let result = Catalog.load(home: home)
        XCTAssertEqual(result.targets.count, Catalog.builtIn.count)
        XCTAssertEqual(result.warnings.count, 1)
    }
}
