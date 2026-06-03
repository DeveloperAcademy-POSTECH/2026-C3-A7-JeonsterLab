//
//  ReceivedRecordingPackage.swift
//  JeonstarLab Mac
//

import Foundation
import SwiftUI

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
    var isPinned: Bool
    var label: RecordingPackageLabel
    var notes: String
    var participantInfo: RecordingParticipantInfo
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

    var snapDetectionMode: MacSnapDetectionMode {
        metadata?.snapDetectionMode ?? .none
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
            .filter { event in
                snapDetectionMode == .jeonFlip || hasUserPreservedAutomaticEvent(event)
            }
            .map { event in
                let legacyIDs = legacySnapIDs(for: event)
                let baseEvent = WorkingSnapEvent.automatic(
                    from: event,
                    recordingID: snapAnalysis?.recordingID ?? metadata?.recordingID,
                    packageFolderName: folderURL.lastPathComponent,
                    labelPayload: payload(for: event)
                )
                var editableEvent = editedSnapEvents[baseEvent.snapID]
                    ?? legacyIDs.compactMap { editedSnapEvents[$0] }.first
                    ?? baseEvent
                editableEvent.snapID = baseEvent.snapID
                editableEvent.recordingID = baseEvent.recordingID
                editableEvent.eventIndex = baseEvent.eventIndex
                editableEvent.sourceType = .automatic
                if let payload = snapEventLabels[editableEvent.snapID] ?? legacyIDs.compactMap({ snapEventLabels[$0] }).first {
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

        let allEvents = automaticEvents + manualEvents

        let filteredEvents = allEvents.filter { event in
            deletedSnapEventIDs.contains(event.snapID) == false &&
                legacySnapIDs(for: event).allSatisfy { deletedSnapEventIDs.contains($0) == false }
        }

        let sortedEvents = filteredEvents.sorted { lhs, rhs in
            (lhs.startTime ?? lhs.peakTime ?? 0) < (rhs.startTime ?? rhs.peakTime ?? 0)
        }

        return sortedEvents
    }

    mutating func addManualSnapEvent(from draft: ManualSnapDraft) {
        let event = WorkingSnapEvent.manual(
            recordingID: metadata?.recordingID ?? snapAnalysis?.recordingID,
            draft: draft,
            packageFolderName: folderURL.lastPathComponent
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

    func isSnapID(_ snapID: String, matching event: WorkingSnapEvent) -> Bool {
        snapID == event.snapID || legacySnapIDs(for: event).contains(snapID)
    }

    func legacySnapIDs(for event: WorkingSnapEvent) -> [String] {
        guard event.sourceType == .automatic else { return [] }
        let eventKey = event.eventIndex ?? Int((event.peakTime ?? event.startTime ?? 0) * 1000)
        return SnapIDGenerator.legacyAutomaticIDs(for: eventKey)
    }

    private func legacySnapIDs(for event: SnapEventExport) -> [String] {
        SnapIDGenerator.legacyAutomaticIDs(for: event.labelKey)
    }

    private func payload(for event: SnapEventExport) -> SnapEventLabelPayload? {
        let globalID = SnapIDGenerator.automatic(
            recordingID: snapAnalysis?.recordingID ?? metadata?.recordingID,
            packageFolderName: folderURL.lastPathComponent,
            eventKey: event.labelKey
        )
        return snapEventLabels[globalID]
            ?? legacySnapIDs(for: event).compactMap { snapEventLabels[$0] }.first
    }

    private func hasUserPreservedAutomaticEvent(_ event: SnapEventExport) -> Bool {
        let globalID = SnapIDGenerator.automatic(
            recordingID: snapAnalysis?.recordingID ?? metadata?.recordingID,
            packageFolderName: folderURL.lastPathComponent,
            eventKey: event.labelKey
        )
        let candidateIDs = [globalID] + legacySnapIDs(for: event)

        if candidateIDs.contains(where: { editedSnapEvents[$0] != nil }) {
            return true
        }

        if candidateIDs.contains(where: { snapID in
            guard let payload = snapEventLabels[snapID] else { return false }
            return payload.label != .unlabeled || payload.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }) {
            return true
        }

        return candidateIDs.contains(where: segmentExists(for:))
    }

    private func segmentExists(for snapID: String) -> Bool {
        let segmentFolderURL = folderURL
            .appendingPathComponent("segments", isDirectory: true)
            .appendingPathComponent(filesystemSafeName(snapID), isDirectory: true)
        return FileManager.default.fileExists(atPath: segmentFolderURL.appendingPathComponent("segment.csv").path)
            && FileManager.default.fileExists(atPath: segmentFolderURL.appendingPathComponent("segment_metadata.json").path)
    }

    private func filesystemSafeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
    }
}

enum RecordingPackageLabel: String, CaseIterable, Codable, Identifiable {
    case unlabeled
    case success
    case failure
    case flipped
    case partialFlipped
    case unflipped
    case loosen
    case idle
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlabeled:
            return "미분류"
        case .success:
            return "성공 모션"
        case .failure:
            return "실패 모션"
        case .flipped:
            return "뒤집기 성공"
        case .partialFlipped:
            return "부분 뒤집기 성공"
        case .unflipped:
            return "뒤집기 실패"
        case .loosen:
            return "분리"
        case .idle:
            return "대기"
        case .other:
            return "기타"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .unlabeled:      return .gray.opacity(0.5)
        case .success:        return .green.opacity(0.5)
        case .failure:        return .red.opacity(0.5)
        case .flipped:        return .blue.opacity(0.5)
        case .partialFlipped: return .cyan.opacity(0.5)
        case .unflipped:      return .orange.opacity(0.5)
        case .loosen:         return .purple.opacity(0.5)
        case .idle:           return .mint.opacity(0.5)
        case .other:          return .gray.opacity(0.5)
        }
    }
}

struct RecordingPackageLabelPayload: Codable {
    let displayName: String?
    let isPinned: Bool
    let label: RecordingPackageLabel
    let packageLabel: RecordingPackageLabel?
    let notes: String
    let participantInfo: RecordingParticipantInfo
    let snapLabels: [Int: SnapEventLabelPayload]
    let snapEventLabels: [String: SnapEventLabelPayload]
    let manualSnapEvents: [WorkingSnapEvent]
    let editedSnapEvents: [String: WorkingSnapEvent]
    let deletedSnapEventIDs: Set<String>
    let updatedAt: Date

    init(
        displayName: String?,
        isPinned: Bool = false,
        label: RecordingPackageLabel,
        packageLabel: RecordingPackageLabel? = nil,
        notes: String,
        participantInfo: RecordingParticipantInfo = .empty,
        snapLabels: [Int: SnapEventLabelPayload] = [:],
        snapEventLabels: [String: SnapEventLabelPayload] = [:],
        manualSnapEvents: [WorkingSnapEvent] = [],
        editedSnapEvents: [String: WorkingSnapEvent] = [:],
        deletedSnapEventIDs: Set<String> = [],
        updatedAt: Date
    ) {
        self.displayName = displayName
        self.isPinned = isPinned
        self.label = label
        self.packageLabel = packageLabel
        self.notes = notes
        self.participantInfo = participantInfo
        self.snapLabels = snapLabels
        self.snapEventLabels = snapEventLabels
        self.manualSnapEvents = manualSnapEvents
        self.editedSnapEvents = editedSnapEvents
        self.deletedSnapEventIDs = deletedSnapEventIDs
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case isPinned
        case label
        case packageLabel
        case notes
        case participantInfo
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
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        label = try container.decodeIfPresent(RecordingPackageLabel.self, forKey: .label)
            ?? container.decodeIfPresent(RecordingPackageLabel.self, forKey: .packageLabel)
            ?? .unlabeled
        packageLabel = try container.decodeIfPresent(RecordingPackageLabel.self, forKey: .packageLabel)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        participantInfo = try container.decodeIfPresent(
            RecordingParticipantInfo.self,
            forKey: .participantInfo
        ) ?? .empty
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
