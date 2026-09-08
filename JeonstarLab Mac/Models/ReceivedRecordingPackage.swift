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
    var autoSegmentReview: AutoSegmentReview? = nil

    var displayTitle: String {
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return recordingDateTitle
    }

    var recordingDateTitle: String {
        guard let startedAt = metadata?.startedAt else {
            return "Recording date unavailable"
        }
        return "Recording · \(startedAt.formatted(date: .numeric, time: .shortened))"
    }

    var recordingDateText: String {
        metadata?.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "No metadata"
    }

    var receivedAtText: String {
        receivedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var completenessText: String {
        let count = [csvURL, metadataURL, snapAnalysisURL].compactMap(\.self).count
        return count == 3 ? "3/3 files" : "\(count)/3 files"
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
            return "No snap events"
        }

        let counts = snapLabelCounts
        if counts.isEmpty || (counts.count == 1 && counts[.unlabeled] != nil) {
            return "Unlabeled snaps"
        }

        return counts.keys.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
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

    mutating func resolveLabels(using catalog: ProjectLabelCatalog) {
        label = catalog.resolve(label)
        snapLabels = snapLabels.mapValues { var p = $0; p.label = catalog.resolve(p.label); return p }
        snapEventLabels = snapEventLabels.mapValues { var p = $0; p.label = catalog.resolve(p.label); return p }
        manualSnapEvents = manualSnapEvents.map { var e = $0; e.label = catalog.resolve(e.label); return e }
        editedSnapEvents = editedSnapEvents.mapValues { var e = $0; e.label = catalog.resolve(e.label); return e }
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

    mutating func mergeAutoSegments(_ result: AutoSegmentReview) {
        var filtered = result
        let saved = workingSnapEvents
        filtered.candidates.removeAll { candidate in
            saved.contains { event in
                guard let start = event.startTime, let end = event.endTime else { return false }
                return candidate.overlaps(start: start, end: end)
            }
        }
        var review = autoSegmentReview ?? AutoSegmentReview()
        review.merge(filtered)
        autoSegmentReview = review
    }

    /// Save the reviewed range and its decision together in label.json. Raw files are untouched.
    mutating func confirmAutoSegment(id: String, draft: ManualSnapDraft) -> WorkingSnapEvent? {
        guard draft.canSave,
              let index = autoSegmentReview?.candidates.firstIndex(where: { $0.id == id && $0.status == .pending }),
              !workingSnapEvents.contains(where: { event in
                  guard let start = event.startTime, let end = event.endTime else { return false }
                  return draft.selection.normalized.startTime < end && draft.selection.normalized.endTime > start
              }) else { return nil }
        var event = WorkingSnapEvent.manual(recordingID: metadata?.recordingID ?? snapAnalysis?.recordingID,
                                           draft: draft, packageFolderName: folderURL.lastPathComponent)
        event.sourceType = .autoSegment
        manualSnapEvents.append(event)
        snapEventLabels[event.snapID] = .empty
        autoSegmentReview?.candidates[index].status = .confirmed
        autoSegmentReview?.candidates[index].confirmedSnapID = event.snapID
        return event
    }

    mutating func dismissAutoSegment(id: String) {
        guard let index = autoSegmentReview?.candidates.firstIndex(where: { $0.id == id && $0.status == .pending }) else { return }
        autoSegmentReview?.candidates[index].status = .dismissed
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
    let autoSegmentReview: AutoSegmentReview?

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
        updatedAt: Date,
        autoSegmentReview: AutoSegmentReview? = nil
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
        self.autoSegmentReview = autoSegmentReview
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
        case autoSegmentReview
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
        autoSegmentReview = try container.decodeIfPresent(AutoSegmentReview.self, forKey: .autoSegmentReview)
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
