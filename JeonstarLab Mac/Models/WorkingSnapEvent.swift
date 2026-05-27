//
//  WorkingSnapEvent.swift
//  JeonstarLab Mac
//

import Foundation

enum SnapEventSourceType: String, Codable, Equatable {
    case automatic
    case manual

    var displayName: String {
        switch self {
        case .automatic:
            return "자동 제안"
        case .manual:
            return "수동 추가"
        }
    }
}

struct WorkingSnapEvent: Identifiable, Codable, Equatable {
    var id: String { snapID }

    var snapID: String
    var recordingID: UUID?
    var eventIndex: Int?
    var sourceType: SnapEventSourceType
    var startTime: Double?
    var peakTime: Double?
    var endTime: Double?
    var snapDuration: Double?
    var peakAcceleration: Double?
    var peakGyro: Double?
    var peakDelay: Double?
    var dominantAxis: String?
    var rollRange: Double?
    var pitchRange: Double?
    var yawRange: Double?
    var confidence: String?
    var label: RecordingPackageLabel
    var notes: String
    var createdAt: Date?
    var updatedAt: Date?

    static func automatic(
        from event: SnapEventExport,
        recordingID: UUID?,
        labelPayload: SnapEventLabelPayload?
    ) -> WorkingSnapEvent {
        WorkingSnapEvent(
            snapID: event.workingSnapID,
            recordingID: recordingID,
            eventIndex: event.eventIndex,
            sourceType: .automatic,
            startTime: event.startTime,
            peakTime: event.peakTime,
            endTime: event.endTime,
            snapDuration: event.snapDuration,
            peakAcceleration: event.peakAcceleration,
            peakGyro: event.peakGyro,
            peakDelay: event.peakDelay,
            dominantAxis: event.dominantAxis,
            rollRange: event.rollRange,
            pitchRange: event.pitchRange,
            yawRange: event.yawRange,
            confidence: event.confidence,
            label: labelPayload?.label ?? .unlabeled,
            notes: labelPayload?.notes ?? "",
            createdAt: nil,
            updatedAt: labelPayload?.updatedAt
        )
    }

    static func manual(
        recordingID: UUID?,
        draft: ManualSnapDraft,
        createdAt: Date = Date()
    ) -> WorkingSnapEvent {
        WorkingSnapEvent(
            snapID: UUID().uuidString,
            recordingID: recordingID,
            eventIndex: nil,
            sourceType: .manual,
            startTime: draft.selection.normalized.startTime,
            peakTime: draft.peakTime,
            endTime: draft.selection.normalized.endTime,
            snapDuration: draft.snapDuration,
            peakAcceleration: draft.peakAcceleration,
            peakGyro: draft.peakGyro,
            peakDelay: draft.peakTime - draft.selection.normalized.startTime,
            dominantAxis: draft.dominantAxis,
            rollRange: draft.rollRange,
            pitchRange: draft.pitchRange,
            yawRange: draft.yawRange,
            confidence: nil,
            label: .unlabeled,
            notes: "",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

extension SnapEventExport {
    var workingSnapID: String {
        "automatic-\(labelKey)"
    }
}
