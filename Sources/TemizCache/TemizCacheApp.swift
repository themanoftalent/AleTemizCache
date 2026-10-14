import SwiftUI
import AppKit

@main
struct TemizCacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("TemizCache", id: "main") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About TemizCache") { AppDelegate.showAboutPanel() }
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Clean") {
                Button("Rescan") { Task { await model.refreshAll() } }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
                Button("Clean Selected…") { model.requestCleanSelected() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(model.selectedNonEmptyCount == 0 || model.isBusy)
                Button("Empty Trash…") { model.requestEmptyTrash() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .disabled(model.isBusy)
                Divider()
                Button("Select All Locations") { model.setSelected(true) }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Deselect All Locations") { model.setSelected(false) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("Overview") { model.selection = .overview }.keyboardShortcut("1")
                Button("Trash") { model.selection = .trash }.keyboardShortcut("2")
                Button("History") { model.selection = .history }.keyboardShortcut("3")
                Divider()
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when the binary runs outside a bundle, e.g. `swift run`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    static func showAboutPanel() {
        let credits = NSMutableAttributedString(
            string: "\(Brand.credit)\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.labelColor]
        )
        credits.append(NSAttributedString(
            string: "Brand: \(Brand.identity)\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        ))
        credits.append(NSAttributedString(
            string: Brand.repository.absoluteString,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: Brand.repository]
        ))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        credits.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
