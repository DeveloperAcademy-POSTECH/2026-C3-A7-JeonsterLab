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
                    Text("WatchMotion Editor")
                        .font(.title2)
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
                        .foregroundStyle(.secondary)

                    Text(viewModel.workspaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                List(selection: viewModel.packageSelectionBinding()) {
                    Section("Folders") {
                        Button {
                            viewModel.addFolder()
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }

                        if viewModel.snapFolders.isEmpty {
                            Text("No folders yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.snapFolders) { folder in
                                Button {
                                    viewModel.selectFolder(folder)
                                } label: {
                                    HStack {
                                        Image(systemName: "folder")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.name)
                                                .lineLimit(1)
                                            Text("\(folder.items.count) snaps")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteFolder(folder)
                                    }
                                }
                            }
                        }
                    }

                    Section("Pinned Recordings") {
                        if viewModel.filteredPinnedPackages.isEmpty {
                            Text("No pinned recordings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.filteredPinnedPackages) { package in
                                receivedPackageRow(package)
                                    .tag(package.id)
                                    .contextMenu {
                                        receivedPackageContextMenu(for: package)
                                    }
                            }
                        }
                    }

                    Section("Received Recordings") {
                        if viewModel.filteredReceivedPackages.isEmpty {
                            Text("No recordings yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.filteredReceivedPackages) { package in
                                receivedPackageRow(package)
                                    .tag(package.id)
                                    .contextMenu {
                                        receivedPackageContextMenu(for: package)
                                    }
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            VStack(spacing: 0) {
                connectionSection
                    .padding(.top, 22)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 0)

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
            .background(Color(nsColor: .windowBackgroundColor))
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
                    .lineLimit(1)
                if package.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                Text(package.recordingDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(package.resultSummaryText) · Received \(package.receivedAtText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(package.sampleCountText) samples · \(package.snapEventCountText) snaps · \(package.completenessText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 18) {
                Text("Connection Status")
                    .font(.headline)
                    .lineLimit(1)

                Divider()
                    .frame(height: 30)

                connectionStatusItem(
                    title: "Status",
                    value: viewModel.statusText,
                    systemImage: viewModel.isAdvertising
                        ? "antenna.radiowaves.left.and.right"
                        : "pause.circle"
                )

                connectionStatusItem(
                    title: "Device",
                    value: viewModel.connectedPeerText,
                    systemImage: "iphone"
                )

                connectionStatusItem(
                    title: "Automatic Transfer",
                    value: "Disabled",
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button("Show in Finder") {
                        viewModel.openReceivedFolder()
                    }

                    Button("Refresh") {
                        viewModel.reloadPackages()
                    }

                    if viewModel.isAdvertising {
                        Button("Stop Receiving") {
                            viewModel.stopReceiver()
                        }
                    } else {
                        Button("Start Receiving") {
                            viewModel.startReceiver()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Group {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    Text(viewModel.guidanceText)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.56))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func connectionStatusItem(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 96, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No recordings yet.")
                .font(.title3)
            Text("Start receiving on this Mac, then open a recording on your iPhone to find this Mac and send the files.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    MacHomeView(viewModel: MacHomeViewModel())
}
