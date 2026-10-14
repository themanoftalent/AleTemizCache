import SwiftUI
import TemizCacheCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            locations
                .tabItem { Label("Custom Locations", systemImage: "folder.badge.gearshape") }
            permissions
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 400)
        .tint(Theme.accent)
    }

    private var general: some View {
        Form {
            Section("When cleaning") {
                Picker("Cleaned files", selection: $model.deletePermanently) {
                    Text("Move to Trash (recoverable)").tag(false)
                    Text("Delete permanently").tag(true)
                }
                .pickerStyle(.radioGroup)
                Toggle("Ask for confirmation before cleaning", isOn: $model.confirmBeforeCleaning)
                Text("Emptying the Trash is always confirmed, whatever this setting says.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Display") {
                Toggle("Hide empty locations", isOn: $model.hideEmptyLocations)
                Picker("Sort locations by", selection: $model.sortOrder) {
                    ForEach(AppModel.SortOrder.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Data") {
                LabeledContent("Lifetime space freed") { BytesText(bytes: model.history.lifetimeBytes) }
                Button("Clear History…", role: .destructive) { model.requestClearHistory() }
                    .disabled(model.history.entries.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private var locations: some View {
        Form {
            Section {
                Text("Add your own cache folders in a JSON file. Every path must sit inside ~/Library/Caches, ~/Library/Logs, ~/Library/Developer, ~/Library/Application Support (two levels deep), ~/.npm, ~/.gradle, ~/.cargo or ~/.cache. Paths outside these are ignored.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Edit Definitions File…") { model.openCustomTargetsFile() }
                    Button("Reload") { model.reloadCatalog() }
                }
            }
            Section("Skipped paths") {
                if model.warnings.isEmpty {
                    Label("All definitions passed the safety check", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    ForEach(model.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissions: some View {
        Form {
            Section {
                LabeledContent("Full Disk Access") {
                    Button("Open Settings") { SystemSettings.open(.fullDiskAccess) }
                }
                Text("Optional. Lets TemizCache measure the Trash and reach caches that macOS protects.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Automation (Finder)") {
                    Button("Open Settings") { SystemSettings.open(.automation) }
                }
                Text("Used only to empty the Trash. macOS asks the first time you empty it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Brand.version)
                LabeledContent("Developed by", value: Brand.developer)
                LabeledContent("Brand", value: Brand.identity)
                LabeledContent("Locations tracked", value: "\(model.rows.count)")
                Link("github.com/themanoftalent/TemizCache", destination: Brand.repository)
                Text(Brand.credit)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
