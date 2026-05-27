//
//  MacHomeView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacHomeView: View {
    @Bindable var viewModel: MacHomeViewModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 14) {
                Text("JeonstarLab Receiver")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("MacBook 데이터 수신 준비")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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

                    Section("Received Recordings") {
                        if viewModel.receivedPackages.isEmpty {
                            Text("아직 수신된 녹화 데이터가 없습니다.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.receivedPackages) { package in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(package.displayTitle)
                                        .lineLimit(1)
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
                                .tag(package.id)
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
                    .padding([.top, .horizontal], 28)

                if let folderBinding = viewModel.bindingForSelectedFolder() {
                    SnapFolderDetailView(
                        folder: folderBinding,
                        onRename: viewModel.renameFolder(_:),
                        onDeleteItem: { item in
                            if let folder = viewModel.selectedFolder {
                                viewModel.removeFolderItem(item, from: folder)
                            }
                        },
                        onOpenSource: viewModel.openSource(for:)
                    )
                } else if let packageBinding = viewModel.bindingForSelectedPackage() {
                    MacRecordingDetailView(
                        package: packageBinding,
                        folders: viewModel.snapFolders,
                        folderNamesForEvent: viewModel.folderNames(for:event:),
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
    }

    private var connectionSection: some View {
        sectionCard(title: "Connection Status") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("상태", value: viewModel.statusText)
                LabeledContent("기기", value: viewModel.connectedPeerText)

                Text(viewModel.guidanceText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("자동 전송은 아직 비활성화되어 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("저장 폴더 열기") {
                        viewModel.openReceivedFolder()
                    }

                    Button("목록 새로고침") {
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
                    }
                }
                .padding(.top, 4)
            }
        }
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    MacHomeView(viewModel: MacHomeViewModel())
}
