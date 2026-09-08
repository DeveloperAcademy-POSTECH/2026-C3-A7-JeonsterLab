//
//  MacRecordingDetailWindowView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacRecordingDetailWindowView: View {
    let packagePath: String

    @State private var package: ReceivedRecordingPackage?
    @State private var errorMessage: String?
    @State private var labelCatalog = ProjectLabelCatalog.legacy
    @State private var trialWorkspaceID = "00000000-0000-0000-0000-000000000001"

    private let loader = ReceivedRecordingPackageLoader()

    var body: some View {
        Group {
            if let packageBinding {
                MacRecordingDetailView(
                    package: packageBinding,
                    folders: [],
                    folderForEvent: { _, _ in nil },
                    onAddSnapToFolder: { _, _, _ in },
                    onRemoveSnapFromFolder: { _, _, _ in },
                    onSaveLabel: saveLabel(for:)
                )
                .navigationTitle(package?.displayTitle ?? "Recording Detail")
            } else {
                VStack(spacing: 10) {
                    Text("Unable to open this recording.")
                        .font(.title3)
                    Text(errorMessage ?? "The selected recording package could not be found.")
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 520, minHeight: 360)
                .padding()
            }
        }
        .task(id: packagePath) {
            loadPackage()
        }
        .environment(\.projectLabelOptions, labelCatalog.activeLabels)
        .environment(\.trialWorkspaceID, trialWorkspaceID)
        .onReceive(NotificationCenter.default.publisher(for: .projectLabelsDidChange)) { notification in
            guard notification.object as? String == URL(fileURLWithPath: packagePath).deletingLastPathComponent().standardizedFileURL.path else { return }
            loadPackage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingPackageLabelDidChange)) { notification in
            guard let changedPath = notification.object as? String,
                  changedPath == packagePath else {
                return
            }
            loadPackage()
        }
    }

    private var packageBinding: Binding<ReceivedRecordingPackage>? {
        guard package != nil else { return nil }
        return Binding(
            get: { package! },
            set: { package = $0 }
        )
    }

    private func loadPackage() {
        let folderURL = URL(fileURLWithPath: packagePath)
        trialWorkspaceID = EditorPurchaseStore.workspaceID(recordingsRoot: folderURL.deletingLastPathComponent())
        do { labelCatalog = try ProjectLabelCatalog.load(root: folderURL.deletingLastPathComponent()) }
        catch { errorMessage = error.localizedDescription; return }
        guard let loadedPackage = loader.loadPackage(folderURL: folderURL) else {
            package = nil
            errorMessage = "The package folder was removed or required files are missing."
            return
        }
        package = loadedPackage
        errorMessage = nil
    }

    private func saveLabel(for updatedPackage: ReceivedRecordingPackage) {
        do {
            try loader.saveLabel(package: updatedPackage)
            package = updatedPackage
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save labels: \(error.localizedDescription)"
        }
    }
}
