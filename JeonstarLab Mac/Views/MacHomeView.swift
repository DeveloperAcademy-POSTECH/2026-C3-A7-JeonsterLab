//
//  MacHomeView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacHomeView: View {
    @Bindable var viewModel: MacHomeViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var pendingDeletePackage: ReceivedRecordingPackage?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                    Text("WatchMotion\nEditor")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if viewModel.canOpenProjectPackage {
                        Button {
                            if let request = viewModel.makeProjectWindowRequest() {
                                openWindow(value: request)
                            }
                        } label: {
                            Label("Open Project", systemImage: "plus")
                                .labelStyle(.iconOnly)
                        }
                        .help("Open WatchMotion Editor Project")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.workspaceTitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text(viewModel.workspaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.65))
                }

                List(selection: viewModel.packageSelectionBinding()) {
                    Section {
                        Button {
                            viewModel.addFolder()
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }

                        if viewModel.snapFolders.isEmpty {
                            Text("No folders yet.")
                                .foregroundStyle(Color.white.opacity(0.65))
                        } else {
                            ForEach(viewModel.snapFolders) { folder in
                                Button {
                                    viewModel.selectFolder(folder)
                                } label: {
                                    HStack {
                                        Image(systemName: "folder")
                                            .foregroundStyle(Color.white.opacity(0.7))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.name)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text("\(folder.items.count) snaps")
                                                .font(.caption)
                                                .foregroundStyle(Color.white.opacity(0.65))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(viewModel.selectedFolder?.id == folder.id ? EditorPalette.accent.opacity(0.24) : Color.clear)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteFolder(folder)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Folders")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Section {
                        if viewModel.filteredPinnedPackages.isEmpty {
                            Text("No pinned recordings.")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.65))
                        } else {
                            ForEach(viewModel.filteredPinnedPackages) { package in
                                receivedPackageRow(package)
                                    .tag(package.id)
                                    .contextMenu {
                                        receivedPackageContextMenu(for: package)
                                    }
                            }
                        }
                    } header: {
                        Text("Pinned Recordings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Section {
                        if viewModel.filteredReceivedPackages.isEmpty {
                            Text("No recordings yet.")
                                .foregroundStyle(Color.white.opacity(0.65))
                        } else {
                            ForEach(viewModel.filteredReceivedPackages) { package in
                                receivedPackageRow(package)
                                    .tag(package.id)
                                    .contextMenu {
                                        receivedPackageContextMenu(for: package)
                                    }
                            }
                        }
                    } header: {
                        Text("Received Recordings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.sidebar)
                Divider().overlay(Color.white.opacity(0.12))
                Label(viewModel.connectedPeerText, systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.bottom, 4)
            }
            .padding(14)
            .background(EditorPalette.sidebar)
            .environment(\.colorScheme, .dark)
            .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 340)
        } detail: {
            VStack(spacing: 0) {
                connectionSection
                Divider()

                if let folderBinding = viewModel.bindingForSelectedFolder() {
                    SnapFolderDetailView(
                        folder: folderBinding,
                        onRename: viewModel.renameFolder(_:),
                        onDeleteItem: { item in
                            if let folder = viewModel.selectedFolder {
                                viewModel.removeFolderItem(item, from: folder)
                            }
                        },
                        onOpenSource: viewModel.openSource(for:),
                        hasSourcePackage: viewModel.hasSourcePackage(for:),
                        onGenerateSegments: viewModel.generateSegments(for:),
                        onExportDataset: viewModel.exportDataset(for:options:),
                        onExportCreateML: viewModel.exportCreateMLActivityDataset(for:)
                    )
                } else if let packageBinding = viewModel.bindingForSelectedPackage() {
                    MacRecordingDetailView(
                        package: packageBinding,
                        folders: viewModel.snapFolders,
                        folderForEvent: viewModel.folderContainingSnap(package:event:),
                        onAddSnapToFolder: viewModel.addSnap(_:from:to:),
                        onRemoveSnapFromFolder: viewModel.removeSnap(_:from:folder:),
                        onSaveLabel: viewModel.saveLabel(for:)
                    )
                } else {
                    emptyState
                }
            }
            .background(EditorPalette.background)
        }
        .alert(
            "Delete this recording?",
            isPresented: Binding(
                get: { pendingDeletePackage != nil },
                set: { if !$0 { pendingDeletePackage = nil } }
            ),
            presenting: pendingDeletePackage
        ) { package in
            Button("Cancel", role: .cancel) {
                pendingDeletePackage = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteReceivedRecording(package)
                pendingDeletePackage = nil
            }
        } message: { _ in
            Text("This recording package will be removed from this Mac.\nThis action cannot be undone.")
        }
        .alert(
            "WatchMotion Editor Project",
            isPresented: Binding(
                get: { viewModel.projectPackageMessage != nil },
                set: { if !$0 { viewModel.projectPackageMessage = nil } }
            )
        ) {
            Button("OK") {
                viewModel.projectPackageMessage = nil
            }
        } message: {
            Text(viewModel.projectPackageMessage ?? "")
        }
        .toolbar {
            ToolbarItem { EditorAppearanceMenu() }
            ToolbarItem {
                Button {
                    viewModel.exportReceiverProjectPackage()
                } label: {
                    Label("Export Project", systemImage: "square.and.arrow.up")
                }
                .help("Export WatchMotion Editor Project")
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            placement: .toolbar,
            prompt: "Search recordings"
        )
    }

    private func receivedPackageRow(_ package: ReceivedRecordingPackage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.displayTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if package.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .labelStyle(.titleAndIcon)
                }
                Text(package.recordingDateText)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
                Text("\(package.resultSummaryText) · Received \(package.receivedAtText)")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
                Text("\(package.sampleCountText) samples · \(package.snapEventCountText) snaps · \(package.completenessText)")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func receivedPackageContextMenu(for package: ReceivedRecordingPackage) -> some View {
        Button {
            openWindow(value: package.folderURL.path)
        } label: {
            Label("Open in New Window", systemImage: "rectangle.on.rectangle")
        }

        if package.isPinned {
            Button {
                viewModel.unpinPackage(package)
            } label: {
                Label("Unpin Recording", systemImage: "pin.slash")
            }
        } else {
            Button {
                viewModel.pinPackage(package)
            } label: {
                Label("Pin Recording", systemImage: "pin")
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingDeletePackage = package
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.isAdvertising ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(viewModel.statusText).fontWeight(.medium)
                Text(viewModel.connectedPeerText).foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button { viewModel.openReceivedFolder() } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .labelStyle(.iconOnly)
                .help("Show received recordings in Finder")
                Button { viewModel.reloadPackages() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help("Refresh recordings")
                Button(viewModel.isAdvertising ? "Stop Receiving" : "Start Receiving") {
                    if viewModel.isAdvertising { viewModel.stopReceiver() }
                    else { viewModel.startReceiver() }
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
            Text(viewModel.errorMessage ?? viewModel.guidanceText)
                .font(.caption)
                .foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : Color.red)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(EditorPalette.surface)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 22) {
                    Image(systemName: "applewatch")
                    Image(systemName: "arrow.right").font(.title3).foregroundStyle(.secondary)
                    Image(systemName: "iphone")
                    Image(systemName: "arrow.right").font(.title3).foregroundStyle(.secondary)
                    Image(systemName: "laptopcomputer")
                }
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(EditorPalette.accent)
                .accessibilityLabel("Apple Watch to iPhone to Mac")
                VStack(spacing: 10) {
                    Text("Your motion. Ready to explore.")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Receive recordings from your iPhone, select motion segments,\nand turn them into labeled datasets.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    Button(viewModel.isAdvertising ? "Receiving…" : "Start Receiving") {
                        viewModel.startReceiver()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAdvertising)
                    if viewModel.canOpenProjectPackage {
                        Button("Open Project…") {
                            if let request = viewModel.makeProjectWindowRequest() { openWindow(value: request) }
                        }
                    }
                }
                .controlSize(.large)
                VStack(alignment: .leading, spacing: 16) {
                    receiveStep("1", title: "Record on Apple Watch", detail: "Save a motion recording and transfer it to your paired iPhone.")
                    receiveStep("2", title: "Send from iPhone", detail: "Open the recording, find this Mac, and send the files.")
                    receiveStep("3", title: "Edit and export", detail: "Review all three motion axes, label snaps, and export a dataset.")
                }
                .padding(24)
                .editorSurface()
                .frame(maxWidth: 550)
                Text("Keep Wi-Fi and Bluetooth enabled. Allow local network access on both devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 64)
        }
    }

    private func receiveStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.caption.bold())
                .frame(width: 26, height: 26)
                .background(EditorPalette.accent.opacity(0.12), in: Circle())
                .foregroundStyle(EditorPalette.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

}

#Preview {
    MacHomeView(viewModel: MacHomeViewModel())
}
