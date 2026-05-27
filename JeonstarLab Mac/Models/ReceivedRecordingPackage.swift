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
    var snapEventLabels: [String: SnapEventLabelPayload]
    var manualSnapEvents: [WorkingSnapEvent]
    var editedSnapEvents: [String: WorkingSnapEvent]
    var deletedSnapEventIDs: Set<String>
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
        "\(workingSnapEvents.count)"
    }

    var resultSummaryText: String {
        let events = workingSnapEvents
        guard !events.isEmpty else {
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
        workingSnapEvents.reduce(into: [:]) { counts, event in
            let label = snapEventLabels[event.snapID]?.label ?? event.label
            counts[label, default: 0] += 1
        }
    }

    var workingSnapEvents: [WorkingSnapEvent] {
        let automaticEvents = (snapAnalysis?.snapEvents ?? [])
            .map { event in
                let baseEvent = WorkingSnapEvent.automatic(
                    from: event,
                    recordingID: snapAnalysis?.recordingID ?? metadata?.recordingID,
                    labelPayload: snapEventLabels[event.workingSnapID]
                )
                var editableEvent = editedSnapEvents[baseEvent.snapID] ?? baseEvent
                if let payload = snapEventLabels[editableEvent.snapID] {
                    editableEvent.label = payload.label
                    editableEvent.notes = payload.notes
                    editableEvent.updatedAt = payload.updatedAt
                }
                return editableEvent
            }

        let manualEvents = manualSnapEvents.map { event in
            var editableEvent = event
            if let payload = snapEventLabels[event.snapID] {
                editableEvent.label = payload.label
                editableEvent.notes = payload.notes
                editableEvent.updatedAt = payload.updatedAt
            }
            return editableEvent
        }

        return (automaticEvents + manualEvents)
            .filter { deletedSnapEventIDs.contains($0.snapID) == false }
            .sorted { lhs, rhs in
                (lhs.startTime ?? lhs.peakTime ?? 0) < (rhs.startTime ?? rhs.peakTime ?? 0)
            }
    }

    mutating func addManualSnapEvent(from draft: ManualSnapDraft) {
        let event = WorkingSnapEvent.manual(
            recordingID: metadata?.recordingID ?? snapAnalysis?.recordingID,
            draft: draft
        )
        manualSnapEvents.append(event)
        snapEventLabels[event.snapID] = SnapEventLabelPayload(
            label: event.label,
            notes: event.notes,
            updatedAt: event.updatedAt
        )
    }

    mutating func deleteSnapEvent(id snapID: String) {
        if manualSnapEvents.contains(where: { $0.snapID == snapID }) {
            manualSnapEvents.removeAll { $0.snapID == snapID }
        } else {
            deletedSnapEventIDs.insert(snapID)
            editedSnapEvents.removeValue(forKey: snapID)
        }
        snapEventLabels.removeValue(forKey: snapID)
    }

    mutating func updateSnapEvent(id snapID: String, from draft: ManualSnapDraft) -> WorkingSnapEvent? {
        guard let existingEvent = workingSnapEvents.first(where: { $0.snapID == snapID }) else {
            return nil
        }

        var updatedEvent = existingEvent
        let normalized = draft.selection.normalized
        updatedEvent.startTime = normalized.startTime
        updatedEvent.peakTime = draft.peakTime
        updatedEvent.endTime = normalized.endTime
        updatedEvent.snapDuration = draft.snapDuration
        updatedEvent.peakAcceleration = draft.peakAcceleration
        updatedEvent.peakGyro = draft.peakGyro
        updatedEvent.peakDelay = draft.peakTime - normalized.startTime
        updatedEvent.dominantAxis = draft.dominantAxis
        updatedEvent.rollRange = draft.rollRange
        updatedEvent.pitchRange = draft.pitchRange
        updatedEvent.yawRange = draft.yawRange
        updatedEvent.updatedAt = Date()

        if let payload = snapEventLabels[snapID] {
            updatedEvent.label = payload.label
            updatedEvent.notes = payload.notes
        }

        if let manualIndex = manualSnapEvents.firstIndex(where: { $0.snapID == snapID }) {
            manualSnapEvents[manualIndex] = updatedEvent
        } else {
            editedSnapEvents[snapID] = updatedEvent
        }

        snapEventLabels[snapID] = SnapEventLabelPayload(
            label: updatedEvent.label,
            notes: updatedEvent.notes,
            updatedAt: updatedEvent.updatedAt
        )
        return updatedEvent
    }

    mutating func replaceSnapEvent(_ updatedEvent: WorkingSnapEvent) {
        if let manualIndex = manualSnapEvents.firstIndex(where: { $0.snapID == updatedEvent.snapID }) {
            manualSnapEvents[manualIndex] = updatedEvent
        } else {
            editedSnapEvents[updatedEvent.snapID] = updatedEvent
        }

        snapEventLabels[updatedEvent.snapID] = SnapEventLabelPayload(
            label: updatedEvent.label,
            notes: updatedEvent.notes,
            updatedAt: updatedEvent.updatedAt
        )
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
    let snapEventLabels: [String: SnapEventLabelPayload]
    let manualSnapEvents: [WorkingSnapEvent]
    let editedSnapEvents: [String: WorkingSnapEvent]
    let deletedSnapEventIDs: Set<String>
    let updatedAt: Date

    init(
        displayName: String?,
        label: RecordingPackageLabel,
        packageLabel: RecordingPackageLabel? = nil,
        notes: String,
        snapLabels: [Int: SnapEventLabelPayload] = [:],
        snapEventLabels: [String: SnapEventLabelPayload] = [:],
        manualSnapEvents: [WorkingSnapEvent] = [],
        editedSnapEvents: [String: WorkingSnapEvent] = [:],
        deletedSnapEventIDs: Set<String> = [],
        updatedAt: Date
    ) {
        self.displayName = displayName
        self.label = label
        self.packageLabel = packageLabel
        self.notes = notes
        self.snapLabels = snapLabels
        self.snapEventLabels = snapEventLabels
        self.manualSnapEvents = manualSnapEvents
        self.editedSnapEvents = editedSnapEvents
        self.deletedSnapEventIDs = deletedSnapEventIDs
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case label
        case packageLabel
        case notes
        case snapLabels
        case snapEventLabels
        case manualSnapEvents
        case editedSnapEvents
        case deletedSnapEventIDs
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
        let decodedSnapEventLabels = try container.decodeIfPresent(
            [String: SnapEventLabelPayload].self,
            forKey: .snapEventLabels
        ) ?? [:]
        snapEventLabels = snapLabels.reduce(into: decodedSnapEventLabels) { labels, legacyEntry in
            let snapID = "automatic-\(legacyEntry.key)"
            if labels[snapID] == nil {
                labels[snapID] = legacyEntry.value
            }
        }
        manualSnapEvents = try container.decodeIfPresent([WorkingSnapEvent].self, forKey: .manualSnapEvents) ?? []
        editedSnapEvents = try container.decodeIfPresent(
            [String: WorkingSnapEvent].self,
            forKey: .editedSnapEvents
        ) ?? [:]
        deletedSnapEventIDs = try container.decodeIfPresent(Set<String>.self, forKey: .deletedSnapEventIDs) ?? []
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
