import SwiftUI
import AppKit

struct ProjectLabelSettingsView: View {
    let request: ProjectSettingsRequest
    @State private var catalog = ProjectLabelCatalog.legacy
    @State private var errorMessage: String?
    @State private var loadFailed = false
    @State private var saved = false
    @State private var loadedData: Data?
    private var root: URL { URL(fileURLWithPath: request.recordingsPath) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project Labels").font(.title2.weight(.semibold))
            Text(request.title).foregroundStyle(.secondary)
            DisclosureGroup("Label Settings Help") {
                Text("Changes apply to this project. Archived labels stay on saved annotations. Number shortcuts work while the label menu is open; custom names appear in future CSV exports.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(catalog.labels.enumerated()), id: \.element.id) { index, definition in
                        row(index: index, definition: definition)
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.callout) }
            if saved { Text("Project labels saved.").foregroundStyle(.secondary) }
            HStack {
                Button("Add Label", systemImage: "plus") { addLabel() }
                    .disabled(loadFailed)
                Spacer()
                Button("Reload") { load() }
                    .help("Discard unsaved changes and reload labels from this project")
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(loadFailed)
            }
        }
        .padding(22)
        .frame(minWidth: 700, idealWidth: 760, minHeight: 450, idealHeight: 540)
        .editorAppearance()
        .task(id: request.recordingsPath) { load() }
    }

    private func row(index: Int, definition: ProjectLabelDefinition) -> some View {
        HStack(spacing: 10) {
            ColorPicker("Color", selection: Binding(
                get: { catalog.labels[index].label.color },
                set: { color in
                    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                    catalog.labels[index].label.colorHex = String(format: "%02X%02X%02X",
                        Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()),
                        Int((rgb.blueComponent * 255).rounded()))
                    saved = false
                }), supportsOpacity: false)
                .labelsHidden()
                .accessibilityLabel("Color for \(definition.label.displayName)")
                .disabled(definition.id == "unlabeled")
            TextField("Label name", text: Binding(
                get: { catalog.labels[index].label.displayName },
                set: { catalog.labels[index].label.displayName = $0; saved = false }))
                .textFieldStyle(.roundedBorder)
                .disabled(definition.id == "unlabeled")
            Picker("Shortcut", selection: Binding(
                get: { catalog.labels[index].shortcut ?? 0 },
                set: { catalog.labels[index].shortcut = $0 == 0 ? nil : $0; saved = false })) {
                Text("None").tag(0)
                ForEach(1...9, id: \.self) { Text(String($0)).tag($0) }
            }
            .frame(width: 125)
            Toggle("Archived", isOn: Binding(
                get: { catalog.labels[index].isArchived },
                set: { catalog.labels[index].isArchived = $0; saved = false }))
                .disabled(definition.id == "unlabeled")
            Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                .disabled(index == 0).help("Move label up")
            Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                .disabled(index == catalog.labels.count - 1).help("Move label down")
        }
        .padding(10)
        .background(EditorPalette.surface, in: RoundedRectangle(cornerRadius: 8))
        .disabled(loadFailed)
    }

    private func addLabel() {
        var n = 1
        while catalog.labels.contains(where: { $0.label.displayName.lowercased() == "label \(n)" }) { n += 1 }
        catalog.labels.append(ProjectLabelDefinition(label: RecordingPackageLabel(name: "Label \(n)", colorHex: "0A84FF")))
        saved = false
    }
    private func move(_ index: Int, by offset: Int) {
        catalog.labels.swapAt(index, index + offset)
        saved = false
    }
    private func load() {
        do {
            catalog = try ProjectLabelCatalog.load(root: root)
            loadedData = try? Data(contentsOf: root.appendingPathComponent(ProjectLabelCatalog.fileName))
            loadFailed = false; errorMessage = nil; saved = false
        }
        catch { errorMessage = error.localizedDescription; loadFailed = true }
    }
    private func save() {
        do {
            let currentData = try? Data(contentsOf: root.appendingPathComponent(ProjectLabelCatalog.fileName))
            guard currentData == loadedData else {
                throw ProjectLabelCatalog.CatalogError.invalid("Labels changed in another window. Reload before saving.")
            }
            for index in catalog.labels.indices {
                catalog.labels[index].label.displayName = catalog.labels[index].label.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            try catalog.save(root: root)
            loadedData = try Data(contentsOf: root.appendingPathComponent(ProjectLabelCatalog.fileName))
            errorMessage = nil
            saved = true
        } catch { errorMessage = error.localizedDescription; saved = false }
    }
}
