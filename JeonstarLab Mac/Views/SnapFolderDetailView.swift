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
    let onExportCreateML: (SnapFolder) -> String

    @State private var segmentMessage: String?
    @State private var exportMessage: String?
    @State private var sourceNavigationMessage: String?
    @State private var sortOption: SnapFolderSortOption = .dateDescending
    @State private var exportOptions = DatasetExportOptions.lastSaved()
    @State private var isShowingExportOptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Folder Name", text: $folder.name)
                    .font(.largeTitle)
                    .textFieldStyle(.plain)
                    .onChange(of: folder.name) {
                        folder.updatedAt = Date()
                        onRename(folder)
                    }

                Text("\(folder.items.count) snaps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SnapFolderSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)

                    Button("Generate Segments") {
                        segmentMessage = onGenerateSegments(folder)
                    }
                    .disabled(folder.items.isEmpty)

                    Button("Export CSV Dataset") {
                        exportOptions = .lastSaved()
                        isShowingExportOptions = true
                    }
                    .disabled(folder.items.isEmpty)

                    Button("Export Create ML") {
                        exportMessage = onExportCreateML(folder)
                    }
                    .disabled(folder.items.isEmpty)

                    if let segmentMessage {
                        Text(segmentMessage)
                            .font(.caption)
                            .foregroundStyle(segmentMessage.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
                    }
                }

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(exportMessage.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if folder.items.isEmpty {
                    Text("No snaps in this folder yet.")
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
            "Source recording unavailable.",
            isPresented: Binding(
                get: { sourceNavigationMessage != nil },
                set: { if !$0 { sourceNavigationMessage = nil } }
            )
        ) {
            Button("OK") {
                sourceNavigationMessage = nil
            }
        } message: {
            Text(sourceNavigationMessage ?? "")

        }
        .sheet(isPresented: $isShowingExportOptions) {
            DatasetExportOptionsView(
                options: $exportOptions,
                onCancel: {
                    isShowingExportOptions = false
                },
                onExport: {
                    exportOptions.saveAsLastUsed()
                    exportMessage = onExportDataset(folder, exportOptions)
                    isShowingExportOptions = false
                }
            )
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
                    Text(item.recordingStartedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Recording date unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !hasSourcePackage(item) {
                        Text("Source Missing")
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
                metric("Label", item.label.displayName)
                metric("Start", formatted(item.startTime, suffix: "s"))
                metric("Peak", formatted(item.peakTime, suffix: "s"))
                metric("End", formatted(item.endTime, suffix: "s"))
                segmentStatusDot(hasSegment: item.segmentCSVRelativePath != nil)
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Recording") {
                    if hasSourcePackage(item) {
                        onOpenSource(item)
                    } else {
                        sourceNavigationMessage = "The original recording was removed or is not in this workspace."
                    }
                }

                Button("Remove from Folder", role: .destructive) {
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
            Text("Segment")
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle()
                .fill(hasSegment ? Color.green : Color.red)
                .frame(width: 9, height: 9)
                .help(hasSegment ? "Segment saved" : "Missing Segments")
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
            return "Oldest Recordings"
        case .dateDescending:
            return "Newest Recordings"
        case .snapDurationAscending:
            return "Shortest Snaps"
        case .snapDurationDescending:
            return "Longest Snaps"
        case .segmentSavedFirst:
            return "Saved Segments First"
        case .segmentMissingFirst:
            return "Missing Segments"
        }
    }
}
