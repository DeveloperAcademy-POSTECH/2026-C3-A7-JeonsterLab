//
//  SnapFolderDetailView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct SnapFolderDetailView: View {
    @Binding var folder: SnapFolder
    let onRename: (SnapFolder) -> Void
    let onDeleteItem: (SnapFolderItem) -> Void
    let onOpenSource: (SnapFolderItem) -> Void
    let onGenerateSegments: (SnapFolder) -> String

    @State private var segmentMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("폴더 이름", text: $folder.name)
                    .font(.largeTitle)
                    .textFieldStyle(.plain)
                    .onChange(of: folder.name) {
                        folder.updatedAt = Date()
                        onRename(folder)
                    }

                Text("\(folder.items.count)개 스냅")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("이 폴더 세그먼트 생성") {
                        segmentMessage = onGenerateSegments(folder)
                    }
                    .disabled(folder.items.isEmpty)

                    if let segmentMessage {
                        Text(segmentMessage)
                            .font(.caption)
                            .foregroundStyle(segmentMessage.contains("실패") ? .red : .secondary)
                    }
                }

                if folder.items.isEmpty {
                    Text("아직 이 폴더에 추가된 스냅이 없습니다.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(folder.items) { item in
                            folderItemRow(item)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(28)
        }
    }

    private func folderItemRow(_ item: SnapFolderItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.packageDisplayName ?? item.packageFolderName)
                        .font(.headline)
                    Text(item.recordingStartedAt?.formatted(date: .abbreviated, time: .shortened) ?? "녹화 시각 확인 불가")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.sourceType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(item.sourceType == .manual ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(item.sourceType == .manual ? .green : .blue)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                metric("라벨", item.label.displayName)
                metric("시작", formatted(item.startTime, suffix: "s"))
                metric("피크", formatted(item.peakTime, suffix: "s"))
                metric("끝", formatted(item.endTime, suffix: "s"))
                segmentStatusDot(hasSegment: item.segmentCSVRelativePath != nil)
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("원본으로 이동") {
                    onOpenSource(item)
                }

                Button("폴더에서 제거", role: .destructive) {
                    onDeleteItem(item)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 6)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }

    private func segmentStatusDot(hasSegment: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("세그먼트")
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle()
                .fill(hasSegment ? Color.green : Color.red)
                .frame(width: 9, height: 9)
                .help(hasSegment ? "세그먼트 생성됨" : "세그먼트 없음")
        }
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%@", locale: Locale(identifier: "en_US_POSIX"), value, suffix)
    }
}
