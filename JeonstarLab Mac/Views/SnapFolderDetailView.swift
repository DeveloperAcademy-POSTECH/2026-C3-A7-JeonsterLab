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
    let hasSourcePackage: (SnapFolderItem) -> Bool
    let onGenerateSegments: (SnapFolder) -> String
    let onExportDataset: (SnapFolder, DatasetExportOptions) -> String

    @State private var segmentMessage: String?
    @State private var exportMessage: String?
    @State private var sourceNavigationMessage: String?
    @State private var sortOption: SnapFolderSortOption = .dateDescending
    @State private var exportOptions = DatasetExportOptions.lastSaved()
    @State private var isShowingExportOptions = false

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
                    Picker("정렬", selection: $sortOption) {
                        ForEach(SnapFolderSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)

                    Button("이 폴더 세그먼트 생성") {
                        segmentMessage = onGenerateSegments(folder)
                    }
                    .disabled(folder.items.isEmpty)

                    Button("데이터셋 CSV 내보내기") {
                        exportOptions = .lastSaved()
                        isShowingExportOptions = true
                    }
                    .disabled(folder.items.isEmpty)

                    if let segmentMessage {
                        Text(segmentMessage)
                            .font(.caption)
                            .foregroundStyle(segmentMessage.contains("실패") ? .red : .secondary)
                    }
                }

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(exportMessage.contains("실패") ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if folder.items.isEmpty {
                    Text("아직 이 폴더에 추가된 스냅이 없습니다.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedItems) { item in
                            folderItemRow(item)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(28)
        }
        .alert(
            "원본 데이터를 찾을 수 없습니다.",
            isPresented: Binding(
                get: { sourceNavigationMessage != nil },
                set: { if !$0 { sourceNavigationMessage = nil } }
            )
        ) {
            Button("확인") {
                sourceNavigationMessage = nil
            }
        } message: {
            Text(sourceNavigationMessage ?? "")

        }
    }

    private var sortedItems: [SnapFolderItem] {
        folder.items.sorted { lhs, rhs in
            switch sortOption {
            case .dateAscending:
                return compareOptional(lhs.recordingStartedAt, rhs.recordingStartedAt, ascending: true)
            case .dateDescending:
                return compareOptional(lhs.recordingStartedAt, rhs.recordingStartedAt, ascending: false)
            case .snapDurationAscending:
                return compareOptional(snapDuration(lhs), snapDuration(rhs), ascending: true)
            case .snapDurationDescending:
                return compareOptional(snapDuration(lhs), snapDuration(rhs), ascending: false)
            case .segmentSavedFirst:
                return compareSegmentPresence(lhs, rhs, savedFirst: true)
            case .segmentMissingFirst:
                return compareSegmentPresence(lhs, rhs, savedFirst: false)
            }
        }
    }

    private func folderItemRow(_ item: SnapFolderItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.packageDisplayName ?? item.packageFolderName)
                        .font(.headline)
                    Text("snapID: \(item.snapID)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(item.recordingStartedAt?.formatted(date: .abbreviated, time: .shortened) ?? "녹화 시각 확인 불가")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !hasSourcePackage(item) {
                        Text("원본 녹화 없음")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
                    if hasSourcePackage(item) {
                        onOpenSource(item)
                    } else {
                        sourceNavigationMessage = "이 스냅 이벤트의 원본 녹화가 삭제되었거나 현재 작업공간에 없습니다."
                    }
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

    private func snapDuration(_ item: SnapFolderItem) -> Double? {
        guard let startTime = item.startTime,
              let endTime = item.endTime else {
            return nil
        }
        return max(0, endTime - startTime)
    }

    private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return ascending ? lhs < rhs : lhs > rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return false
        }
    }

    private func compareSegmentPresence(_ lhs: SnapFolderItem, _ rhs: SnapFolderItem, savedFirst: Bool) -> Bool {
        let lhsHasSegment = lhs.segmentCSVRelativePath != nil
        let rhsHasSegment = rhs.segmentCSVRelativePath != nil

        if lhsHasSegment != rhsHasSegment {
            return savedFirst ? lhsHasSegment : !lhsHasSegment
        }

        return compareOptional(lhs.recordingStartedAt, rhs.recordingStartedAt, ascending: false)
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%@", locale: Locale(identifier: "en_US_POSIX"), value, suffix)
    }
}

private enum SnapFolderSortOption: String, CaseIterable, Identifiable {
    case dateAscending
    case dateDescending
    case snapDurationAscending
    case snapDurationDescending
    case segmentSavedFirst
    case segmentMissingFirst

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateAscending:
            return "오래된 녹화"
        case .dateDescending:
            return "최신 녹화"
        case .snapDurationAscending:
            return "짧은 스냅"
        case .snapDurationDescending:
            return "긴 스냅"
        case .segmentSavedFirst:
            return "세그먼트 저장됨"
        case .segmentMissingFirst:
            return "세그먼트 없음"
        }
    }
}
