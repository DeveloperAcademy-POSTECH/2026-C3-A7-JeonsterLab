//
//  ReceivedRecordingPackage.swift
//  JeonstarLab Mac
//

import Foundation

struct ReceivedRecordingPackage: Identifiable, Equatable {
    let id: URL
    let folderURL: URL
    let receivedAt: Date
    let csvURL: URL?
    let metadataURL: URL?
    let snapAnalysisURL: URL?
    let metadata: RecordingExportMetadata?
    let snapAnalysis: SnapAnalysisExport?
    var displayName: String
    var label: RecordingPackageLabel
    var notes: String
    var snapLabels: [Int: SnapEventLabelPayload]
    var parseMessages: [String]

    var displayTitle: String {
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return recordingDateTitle
    }

    var recordingDateTitle: String {
        guard let startedAt = metadata?.startedAt else {
            return "녹화 시각 확인 불가"
        }
        return "\(startedAt.formatted(date: .numeric, time: .shortened)) 녹화"
    }

    var recordingDateText: String {
        metadata?.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "메타데이터 없음"
    }

    var receivedAtText: String {
        receivedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var completenessText: String {
        let count = [csvURL, metadataURL, snapAnalysisURL].compactMap(\.self).count
        return count == 3 ? "파일 3/3" : "파일 \(count)/3"
    }

    var isComplete: Bool {
        csvURL != nil && metadataURL != nil && snapAnalysisURL != nil
    }

    var durationText: String {
        guard let duration = metadata?.duration else { return "-" }
        return String(format: "%.2fs", locale: Locale(identifier: "en_US_POSIX"), duration)
    }

    var sampleCountText: String {
        guard let sampleCount = metadata?.sampleCount else { return "-" }
        return "\(sampleCount)"
    }

    var snapEventCountText: String {
        if let eventCount = snapAnalysis?.eventCount {
            return "\(eventCount)"
        }
        return "\(snapAnalysis?.snapEvents.count ?? 0)"
    }

    var resultSummaryText: String {
        guard let events = snapAnalysis?.snapEvents, !events.isEmpty else {
            return "스냅 이벤트 없음"
        }

        let counts = snapLabelCounts
        if counts.isEmpty || (counts.count == 1 && counts[.unlabeled] != nil) {
            return "스냅 라벨 미분류"
        }

        return RecordingPackageLabel.allCases
            .compactMap { label in
                guard let count = counts[label], count > 0 else { return nil }
                return "\(label.displayName) \(count)"
            }
            .joined(separator: " · ")
    }

    var snapLabelCounts: [RecordingPackageLabel: Int] {
        guard let events = snapAnalysis?.snapEvents else { return [:] }

        return events.reduce(into: [:]) { counts, event in
            let label = snapLabels[event.labelKey]?.label ?? .unlabeled
            counts[label, default: 0] += 1
        }
    }
}

enum RecordingPackageLabel: String, CaseIterable, Codable, Identifiable {
    case unlabeled
    case success
    case partialSuccess
    case failure
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlabeled:
            return "미분류"
        case .success:
            return "성공"
        case .partialSuccess:
            return "부분 성공"
        case .failure:
            return "실패"
        case .other:
            return "기타"
        }
    }
}

struct RecordingPackageLabelPayload: Codable {
    let displayName: String?
    let label: RecordingPackageLabel
    let packageLabel: RecordingPackageLabel?
    let notes: String
    let snapLabels: [Int: SnapEventLabelPayload]
    let updatedAt: Date

    init(
        displayName: String?,
        label: RecordingPackageLabel,
        packageLabel: RecordingPackageLabel? = nil,
        notes: String,
        snapLabels: [Int: SnapEventLabelPayload] = [:],
        updatedAt: Date
    ) {
        self.displayName = displayName
        self.label = label
        self.packageLabel = packageLabel
        self.notes = notes
        self.snapLabels = snapLabels
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case label
        case packageLabel
        case notes
        case snapLabels
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        label = try container.decodeIfPresent(RecordingPackageLabel.self, forKey: .label)
            ?? container.decodeIfPresent(RecordingPackageLabel.self, forKey: .packageLabel)
            ?? .unlabeled
        packageLabel = try container.decodeIfPresent(RecordingPackageLabel.self, forKey: .packageLabel)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        snapLabels = try container.decodeIfPresent([Int: SnapEventLabelPayload].self, forKey: .snapLabels) ?? [:]
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

struct SnapEventLabelPayload: Codable, Equatable {
    var label: RecordingPackageLabel
    var notes: String
    var updatedAt: Date?

    static let empty = SnapEventLabelPayload(label: .unlabeled, notes: "", updatedAt: nil)
}

extension SnapEventExport {
    var labelKey: Int {
        eventIndex ?? Int((peakTime ?? startTime ?? 0) * 1000)
    }
}
