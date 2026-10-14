import Foundation
import AppKit
import TemizCacheCore

/// Single source of truth for the UI. All view state lives here rather than in
/// `@State`, which keeps the app buildable with the Command Line Tools toolchain.
@MainActor
final class AppModel: ObservableObject {
    // MARK: Types

    enum SidebarItem: Hashable {
        case overview
        case category(CacheTarget.Kind)
        case trash
        case history
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case size, name
        var id: String { rawValue }
        var title: String { self == .size ? "Size" : "Name" }
    }

    enum PendingAction: Identifiable {
        case cleanSelected
        case cleanTarget(CacheTarget)
        case emptyTrash
        case clearHistory

        var id: String {
            switch self {
            case .cleanSelected: return "cleanSelected"
            case .cleanTarget(let t): return "clean-\(t.id)"
            case .emptyTrash: return "emptyTrash"
            case .clearHistory: return "clearHistory"
            }
        }
    }

    struct Toast: Identifiable, Equatable {
        enum Style { case success, info, warning, error }
        enum Action: Equatable { case emptyTrash, openFullDiskAccess, openAutomation, showTrash }

        let id = UUID()
        let style: Style
        let title: String
        var detail: String?
        var action: Action?
        var actionTitle: String?
    }

    struct Row: Identifiable {
        let target: CacheTarget
        var size: Int64?
        var isSelected: Bool
        var id: String { target.id }
    }

    struct CleaningProgress: Equatable {
        var current: String
        var completed: Int
        var total: Int
        var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    }

    // MARK: Published state

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var lastScan: Date?
    @Published private(set) var cleaning: CleaningProgress?
    @Published private(set) var disk: DiskSpace?
    @Published private(set) var trash: TrashInspector.Status?
    @Published private(set) var trashFinderCount: Int?
    @Published private(set) var isCheckingTrash = false
    @Published private(set) var isEmptyingTrash = false
    @Published private(set) var history = CleanHistory()
    @Published private(set) var warnings: [String] = []

    @Published var selection: SidebarItem? = .overview
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .size {
        didSet { defaults.set(sortOrder.rawValue, forKey: Keys.sort) }
    }
    @Published var pending: PendingAction?
    @Published var toast: Toast?

    // Settings
    @Published var deletePermanently = false {
        didSet { defaults.set(deletePermanently, forKey: Keys.permanent) }
    }
    @Published var confirmBeforeCleaning = true {
        didSet { defaults.set(confirmBeforeCleaning, forKey: Keys.confirm) }
    }
    @Published var hideEmptyLocations = false {
        didSet { defaults.set(hideEmptyLocations, forKey: Keys.hideEmpty) }
    }

    // MARK: Private

    private enum Keys {
        static let permanent = "deletePermanently"
        static let confirm = "confirmBeforeCleaning"
        static let hideEmpty = "hideEmptyLocations"
        static let deselected = "deselectedTargetIDs"
        static let history = "cleanHistory"
        static let sort = "sortOrder"
    }

    private let defaults = UserDefaults.standard
    let home = FileManager.default.homeDirectoryForCurrentUser
    private var toastTask: Task<Void, Never>?

    // MARK: Init

    init() {
        deletePermanently = defaults.bool(forKey: Keys.permanent)
        confirmBeforeCleaning = defaults.object(forKey: Keys.confirm) as? Bool ?? true
        hideEmptyLocations = defaults.bool(forKey: Keys.hideEmpty)
        sortOrder = SortOrder(rawValue: defaults.string(forKey: Keys.sort) ?? "") ?? .size
        history = CleanHistory.decode(defaults.data(forKey: Keys.history))
        reloadCatalog()
    }

    // MARK: Derived values

    var isBusy: Bool { isScanning || cleaning != nil || isEmptyingTrash }

    var totalBytes: Int64 { rows.compactMap(\.size).reduce(0, +) }

    var selectedRows: [Row] { rows.filter(\.isSelected) }

    var selectedBytes: Int64 { selectedRows.compactMap(\.size).reduce(0, +) }

    var selectedNonEmptyCount: Int { selectedRows.filter { ($0.size ?? 0) > 0 }.count }

    var kindsInUse: [CacheTarget.Kind] {
        CacheTarget.Kind.allCases.filter { kind in rows.contains { $0.target.kind == kind } }
    }

    func bytes(for kind: CacheTarget.Kind) -> Int64 {
        rows.filter { $0.target.kind == kind }.compactMap(\.size).reduce(0, +)
    }

    func rows(for kind: CacheTarget.Kind) -> [Row] {
        sorted(rows.filter { $0.target.kind == kind && visible($0) })
    }

    var searchResults: [Row] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return sorted(rows.filter {
            $0.target.title.localizedCaseInsensitiveContains(query)
                || $0.target.summary.localizedCaseInsensitiveContains(query)
                || $0.target.kind.title.localizedCaseInsensitiveContains(query)
                || $0.target.paths.contains { $0.localizedCaseInsensitiveContains(query) }
        })
    }

    var largestRows: [Row] {
        Array(rows.filter { ($0.size ?? 0) > 0 }.sorted { ($0.size ?? 0) > ($1.size ?? 0) }.prefix(6))
    }

    func row(_ id: String) -> Row? { rows.first { $0.id == id } }

    private func visible(_ row: Row) -> Bool {
        !(hideEmptyLocations && row.size == 0)
    }

    private func sorted(_ list: [Row]) -> [Row] {
        switch sortOrder {
        case .size: return list.sorted { ($0.size ?? -1, $1.target.title) > ($1.size ?? -1, $0.target.title) }
        case .name: return list.sorted { $0.target.title.localizedStandardCompare($1.target.title) == .orderedAscending }
        }
    }

    // MARK: Catalog and selection

    func reloadCatalog() {
        let result = Catalog.load(home: home)
        let deselected = Set(defaults.stringArray(forKey: Keys.deselected) ?? [])
        let previous = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.size) })
        rows = result.targets.map { Row(target: $0, size: previous[$0.id] ?? nil, isSelected: !deselected.contains($0.id)) }
        warnings = result.warnings
        if !result.warnings.isEmpty {
            showToast(.init(style: .warning, title: "Some definitions were skipped",
                            detail: "\(result.warnings.count) path(s) failed the safety check. See Settings › Custom Locations."))
        }
        Task { await refreshAll() }
    }

    func toggle(_ id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].isSelected.toggle()
        persistSelection()
    }

    func setSelected(_ selected: Bool, kind: CacheTarget.Kind? = nil) {
        for i in rows.indices where kind == nil || rows[i].target.kind == kind {
            rows[i].isSelected = selected
        }
        persistSelection()
    }

    func allSelected(kind: CacheTarget.Kind) -> Bool {
        rows.filter { $0.target.kind == kind }.allSatisfy(\.isSelected)
    }

    private func persistSelection() {
        defaults.set(rows.filter { !$0.isSelected }.map(\.id), forKey: Keys.deselected)
    }

    // MARK: Scanning

    func refreshAll() async {
        await scan()
        await refreshTrash()
    }

    func scan() async {
        guard !isScanning, cleaning == nil else { return }
        isScanning = true
        scannedCount = 0
        refreshDisk()

        let home = self.home
        let targets = rows.map(\.target)
        await withTaskGroup(of: (String, Int64).self) { group in
            for target in targets {
                group.addTask(priority: .utility) {
                    (target.id, SizeScanner.allocatedSize(of: target, home: home))
                }
            }
            for await (id, size) in group {
                if let index = rows.firstIndex(where: { $0.id == id }) {
                    rows[index].size = size
                }
                scannedCount += 1
            }
        }
        lastScan = Date()
        isScanning = false
    }

    private func measure(_ target: CacheTarget) async -> Int64 {
        let home = self.home
        return await Task.detached(priority: .userInitiated) {
            SizeScanner.allocatedSize(of: target, home: home)
        }.value
    }

    func refreshDisk() {
        disk = DiskSpace.forVolume(containing: home)
    }

    // MARK: Cleaning

    func requestCleanSelected() {
        guard selectedNonEmptyCount > 0, !isBusy else { return }
        confirmBeforeCleaning ? (pending = .cleanSelected) : perform(.cleanSelected)
    }

    func requestClean(_ target: CacheTarget) {
        guard !isBusy else { return }
        confirmBeforeCleaning ? (pending = .cleanTarget(target)) : perform(.cleanTarget(target))
    }

    func requestEmptyTrash() {
        guard !isBusy else { return }
        // Emptying the Trash is irreversible, so it is always confirmed.
        pending = .emptyTrash
    }

    func requestClearHistory() { pending = .clearHistory }

    func perform(_ action: PendingAction) {
        pending = nil
        switch action {
        case .cleanSelected:
            let targets = selectedRows.filter { ($0.size ?? 0) > 0 }.map(\.target)
            Task { await clean(targets) }
        case .cleanTarget(let target):
            Task { await clean([target]) }
        case .emptyTrash:
            Task { await emptyTrash() }
        case .clearHistory:
            history.clear()
            persistHistory()
            showToast(.init(style: .info, title: "History cleared"))
        }
    }

    private func clean(_ targets: [CacheTarget]) async {
        guard !targets.isEmpty, cleaning == nil, !isScanning else { return }
        let mode: Cleaner.Mode = deletePermanently ? .delete : .trash
        let cleaner = Cleaner(home: home, mode: mode)
        var freed: Int64 = 0
        var removed = 0
        var problems: [String] = []
        var touched: [String] = []

        cleaning = CleaningProgress(current: targets[0].title, completed: 0, total: targets.count)
        for (index, target) in targets.enumerated() {
            cleaning = CleaningProgress(current: target.title, completed: index, total: targets.count)
            let before = row(target.id)?.size ?? 0
            let report = await Task.detached(priority: .userInitiated) { cleaner.clean(target) }.value
            let after = await measure(target)
            if let i = rows.firstIndex(where: { $0.id == target.id }) { rows[i].size = after }

            freed += max(0, before - after)
            removed += report.removedItems
            problems += report.failures + report.refused
            if report.removedItems > 0 { touched.append(target.title) }
        }
        cleaning = CleaningProgress(current: "Done", completed: targets.count, total: targets.count)

        history.record(.init(bytes: freed, items: removed, kind: .caches, targets: touched))
        persistHistory()
        refreshDisk()
        cleaning = nil
        await refreshTrash()

        if !problems.isEmpty {
            NSLog("AleTemizCache: %d item(s) not removed:\n%@", problems.count, problems.joined(separator: "\n"))
        }
        let skippedNote = problems.isEmpty ? nil : "\(problems.count) item(s) were in use or protected and stayed. Quit the related apps and try again."

        if removed == 0 && !problems.isEmpty {
            showToast(.init(style: .error, title: "Nothing could be removed", detail: skippedNote))
        } else if mode == .trash {
            var toast = Toast(style: problems.isEmpty ? .success : .warning,
                              title: "Moved \(ByteText.string(freed)) to the Trash",
                              detail: [skippedNote ?? "Disk space is released when you empty the Trash."].joined())
            toast.action = .emptyTrash
            toast.actionTitle = "Empty Trash…"
            showToast(toast)
        } else {
            showToast(.init(style: problems.isEmpty ? .success : .warning,
                            title: "Freed \(ByteText.string(freed))",
                            detail: skippedNote))
        }
    }

    // MARK: Trash

    func refreshTrash() async {
        isCheckingTrash = true
        let home = self.home
        let status = await Task.detached(priority: .utility) { TrashInspector.inspect(home: home) }.value
        trash = status
        if status.readable { trashFinderCount = nil }
        isCheckingTrash = false
    }

    /// Without Full Disk Access the Trash folder is unreadable; Finder can still count it.
    func countTrashWithFinder() async {
        isCheckingTrash = true
        let result = await FinderBridge.countTrashItems()
        isCheckingTrash = false
        switch result {
        case .success(let count):
            trashFinderCount = count
        case .failure(let error):
            showFinderError(error)
        }
    }

    private func emptyTrash() async {
        guard !isEmptyingTrash else { return }
        isEmptyingTrash = true
        defer { isEmptyingTrash = false }

        let before = trash?.readable == true ? trash : nil
        let result = await FinderBridge.emptyTrash()
        var bytes = before?.bytes ?? 0
        var items = before?.itemCount ?? trashFinderCount ?? 0

        switch result {
        case .success:
            break
        case .failure(let error):
            // Fall back to removing ~/.Trash contents directly when Finder automation
            // is refused but the app can read the folder.
            if error == .notAuthorized, trash?.readable == true {
                let home = self.home
                let report = await Task.detached(priority: .userInitiated) { TrashInspector.emptyDirectly(home: home) }.value
                items = report.removedItems
                if !report.failures.isEmpty {
                    await refreshTrash()
                    refreshDisk()
                    showToast(.init(style: .warning, title: "Some items stayed in the Trash",
                                    detail: "\(report.failures.count) item(s) are locked or in use."))
                    return
                }
            } else {
                showFinderError(error)
                return
            }
        }

        await refreshTrash()
        refreshDisk()
        if let after = trash, after.readable, let before { bytes = max(0, before.bytes - after.bytes) }
        trashFinderCount = nil
        history.record(.init(bytes: bytes, items: items, kind: .trash, targets: ["Trash"]))
        persistHistory()
        showToast(.init(style: .success,
                        title: bytes > 0 ? "Emptied the Trash, freed \(ByteText.string(bytes))" : "Emptied the Trash",
                        detail: nil))
    }

    private func showFinderError(_ error: FinderBridge.Failure) {
        switch error {
        case .notAuthorized:
            var toast = Toast(style: .error, title: "AleTemizCache may not control Finder",
                              detail: "Allow it in System Settings › Privacy & Security › Automation, or grant Full Disk Access.")
            toast.action = .openAutomation
            toast.actionTitle = "Open Settings"
            showToast(toast)
        case .other(let message):
            showToast(.init(style: .error, title: "Finder reported an error", detail: message))
        }
    }

    // MARK: History

    private func persistHistory() {
        defaults.set(history.encoded(), forKey: Keys.history)
    }

    // MARK: Toasts

    func showToast(_ toast: Toast) {
        toastTask?.cancel()
        self.toast = toast
        let seconds: UInt64 = toast.action == nil ? 5 : 10
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismissToast(toast.id)
        }
    }

    func dismissToast(_ id: UUID? = nil) {
        if id == nil || toast?.id == id { toast = nil }
    }

    func runToastAction(_ action: Toast.Action) {
        dismissToast()
        switch action {
        case .emptyTrash: requestEmptyTrash()
        case .openFullDiskAccess: SystemSettings.open(.fullDiskAccess)
        case .openAutomation: SystemSettings.open(.automation)
        case .showTrash: selection = .trash
        }
    }

    // MARK: Finder and files

    func reveal(_ target: CacheTarget) {
        let urls = target.resolvedURLs(home: home).filter { FileManager.default.fileExists(atPath: $0.path) }
        if urls.isEmpty {
            showToast(.init(style: .info, title: "\(target.title) has no cache folder on this Mac"))
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    func copyPaths(_ target: CacheTarget) {
        let text = target.resolvedURLs(home: home).map(\.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(.init(style: .info, title: "Copied \(target.paths.count) path(s)"))
    }

    func openTrashInFinder() {
        NSWorkspace.shared.open(TrashInspector.trashURL(home: home))
    }

    func openCustomTargetsFile() {
        let url = Catalog.userFileURL(home: home)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let sample = """
                [
                  {
                    "id": "example.app",
                    "title": "Example App",
                    "summary": "Replace with a real cache folder, then choose Reload Definitions.",
                    "kind": "custom",
                    "paths": ["~/Library/Caches/com.example.app"]
                  }
                ]
                """
                try sample.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showToast(.init(style: .error, title: "Could not create the definitions file", detail: error.localizedDescription))
                return
            }
        }
        NSWorkspace.shared.open(url)
    }
}
