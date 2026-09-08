import SwiftUI

struct EditorSettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("WatchMotionEditor.appearance") private var appearance = EditorAppearance.system
    @AppStorage(ProjectExportPreferences.nameKey) private var projectName = ProjectExportPreferences.defaultName
    @AppStorage(ProjectExportPreferences.formatKey) private var archiveFormat = ProjectArchiveFormat.watchmotion
    @AppStorage(ProjectExportPreferences.timestampKey) private var includeTimestamp = true

    var body: some View {
        TabView {
            Form {
                Section("Full Access") {
                    Text(EditorPurchaseStore.shared.isUnlocked ? "Full Unlock purchased" : "Free trial: one workspace, three recordings, one dataset export.")
                    Button("Manage Purchase") {
                        EditorPurchaseStore.shared.reason = String(localized: "Unlock unlimited editing and dataset exports.")
                        openWindow(id: "full-unlock")
                    }
                }
                Button("Show Tutorial", systemImage: "questionmark.circle") { openWindow(id: "getting-started") }
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
                        .lineLimit(2).truncationMode(.middle)
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

            Form {
                Section("Learn & Support") {
                    Link("Setup Guide", destination: URL(string: "https://watch-motion-editor-site.vercel.app/guide/getting-started")!)
                    Link("User Guide", destination: URL(string: "https://watch-motion-editor-site.vercel.app/guide")!)
                    Link("Contact Support", destination: URL(string: "https://watch-motion-editor-site.vercel.app/support")!)
                }
                Section("Privacy") {
                    Link("Privacy Policy", destination: URL(string: "https://watch-motion-editor-site.vercel.app/privacy")!)
                }
                Section("Official Website") {
                    Link("WatchMotion Editor Website", destination: URL(string: "https://watch-motion-editor-site.vercel.app/")!)
                    Text("Links open in your default browser. An internet connection is required.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Help & Privacy", systemImage: "questionmark.circle") }
        }
        .padding(12)
        .frame(width: 600, height: 420)
        .editorAppearance()
    }
}
