import SwiftUI

struct EditorSettingsView: View {
    @AppStorage("WatchMotionEditor.appearance") private var appearance = EditorAppearance.system
    @AppStorage(ProjectExportPreferences.nameKey) private var projectName = ProjectExportPreferences.defaultName
    @AppStorage(ProjectExportPreferences.formatKey) private var archiveFormat = ProjectArchiveFormat.watchmotion
    @AppStorage(ProjectExportPreferences.timestampKey) private var includeTimestamp = true

    var body: some View {
        TabView {
            Form {
                Picker("Appearance", selection: $appearance) {
                    ForEach(EditorAppearance.allCases) { Text($0.title).tag($0) }
                }
                Section("Project Labels") {
                    Text("Use Settings → Project Labels in a workspace toolbar to edit that project's labels, colors, order, and shortcuts.")
                        .foregroundStyle(.secondary)
                    Text("Label settings travel with exported projects. Appearance and export defaults apply to this Mac.")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                TextField("Default project name", text: $projectName)
                Picker("Project format", selection: $archiveFormat) {
                    ForEach(ProjectArchiveFormat.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Append date and time", isOn: $includeTimestamp)
                LabeledContent("File name") {
                    Text(ProjectExportPreferences.safeName(projectName)
                         + (includeTimestamp ? "_YYYYMMDD_HHmmss" : "") + "." + archiveFormat.rawValue)
                        .textSelection(.enabled).font(.caption.monospaced())
                }
                Text("Both project formats contain the same ZIP-based project. Older .jeonstarlab projects can still be opened. CSV datasets remain .csv and metadata remains .json.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Restore Export Defaults") {
                    projectName = ProjectExportPreferences.defaultName
                    archiveFormat = .watchmotion
                    includeTimestamp = true
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
        }
        .padding(12)
        .frame(width: 600, height: 370)
        .editorAppearance()
    }
}
