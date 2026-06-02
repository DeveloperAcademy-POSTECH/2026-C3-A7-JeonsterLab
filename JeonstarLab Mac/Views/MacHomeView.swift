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
                    Text("JeonstarLab Receiver")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        viewModel.importReceiverProjectPackage()
                    } label: {
                        Label("프로젝트 가져오기", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .help("Receiver 프로젝트 가져오기")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.workspaceTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(viewModel.workspaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if viewModel.canReturnToDefaultWorkspace {
                        Button {
                            viewModel.switchToDefaultWorkspace()
                        } label: {
                            Label("기본 작업공간으로 돌아가기", systemImage: "arrow.uturn.backward")
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                    }
                }

                List(selection: viewModel.packageSelectionBinding()) {
                    Section("Folders") {
                        Button {
                            viewModel.addFolder()
                        } label: {
                            Label("폴더 추가", systemImage: "folder.badge.plus")
                        }

                        if viewModel.snapFolders.isEmpty {
                            Text("아직 분류 폴더가 없습니다.")
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
                                            Text("\(folder.items.count)개 스냅")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("삭제", role: .destructive) {
                                        viewModel.deleteFolder(folder)
                                    }
                                }
                            }
                        }
                    }

                    Section("Pinned Recordings") {
                        if viewModel.filteredPinnedPackages.isEmpty {
                            Text("고정된 녹화가 없습니다.")
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
                            Text("아직 수신된 녹화 데이터가 없습니다.")
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
                        onExportDataset: viewModel.exportDataset(for:options:)
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
            "이 녹화 기록을 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeletePackage != nil },
                set: { if !$0 { pendingDeletePackage = nil } }
            ),
            presenting: pendingDeletePackage
        ) { package in
            Button("취소", role: .cancel) {
                pendingDeletePackage = nil
            }
            Button("삭제", role: .destructive) {
                viewModel.deleteReceivedRecording(package)
                pendingDeletePackage = nil
            }
        } message: { _ in
            Text("삭제하면 Mac에 저장된 이 녹화 패키지가 사라집니다.\n이 작업은 되돌릴 수 없습니다.")
        }
        .alert(
            "Receiver 프로젝트",
            isPresented: Binding(
                get: { viewModel.projectPackageMessage != nil },
                set: { if !$0 { viewModel.projectPackageMessage = nil } }
            )
        ) {
            Button("확인") {
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
                    Label("프로젝트 내보내기", systemImage: "square.and.arrow.up")
                }
                .help("Receiver 프로젝트 내보내기")
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            placement: .toolbar,
            prompt: "수신 기록 검색"
        )
    }

    private func receivedPackageRow(_ package: ReceivedRecordingPackage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.displayTitle)
                    .lineLimit(1)
                if package.isPinned {
                    Label("고정됨", systemImage: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                Text(package.recordingDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(package.resultSummaryText) · 수신 \(package.receivedAtText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(package.sampleCountText)샘플 · 스냅 \(package.snapEventCountText) · \(package.completenessText)")
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
            Label("새로운 윈도우에서 열기", systemImage: "rectangle.on.rectangle")
        }

        if package.isPinned {
            Button {
                viewModel.unpinPackage(package)
            } label: {
                Label("고정 해제", systemImage: "pin.slash")
            }
        } else {
            Button {
                viewModel.pinPackage(package)
            } label: {
                Label("기록 고정", systemImage: "pin")
            }
        }

        Divider()

        Button(role: .destructive) {
            pendingDeletePackage = package
        } label: {
            Label("삭제하기", systemImage: "trash")
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
                    title: "상태",
                    value: viewModel.statusText,
                    systemImage: viewModel.isAdvertising
                        ? "antenna.radiowaves.left.and.right"
                        : "pause.circle"
                )

                connectionStatusItem(
                    title: "기기",
                    value: viewModel.connectedPeerText,
                    systemImage: "iphone"
                )

                connectionStatusItem(
                    title: "자동 전송",
                    value: "비활성화",
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button("저장 폴더") {
                        viewModel.openReceivedFolder()
                    }

                    Button("새로고침") {
                        viewModel.reloadPackages()
                    }

                    if viewModel.isAdvertising {
                        Button("수신 중지") {
                            viewModel.stopReceiver()
                        }
                    } else {
                        Button("수신 시작") {
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
            Text("아직 수신된 녹화 데이터가 없습니다.")
                .font(.title3)
            Text("Mac에서 [수신 시작]을 누른 뒤 iPhone 녹화 상세 화면에서 [Mac 찾기]와 [Mac으로 전송]을 순서대로 눌러주세요.")
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
