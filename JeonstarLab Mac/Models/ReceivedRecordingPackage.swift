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
    var label: RecordingPackageLabel
    var notes: String
    var parseMessages: [String]

    var displayTitle: String {
        metadata?.fileName ?? metadata?.recordingID?.uuidString ?? folderURL.lastPathComponent
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
    let label: RecordingPackageLabel
    let notes: String
    let updatedAt: Date
}
