//
//  RecordingEntity.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import SwiftData

@Model
final class RecordingEntity {
    @Attribute(.unique) var id: UUID
    var startedAt:       Date
    var duration:        TimeInterval
    var sampleCount:     Int
    var fileName:        String
    var samplingRate:    Int
    var activityLabelID: UUID?

    init(session: RecordingSession) {
        self.id              = session.id
        self.startedAt       = session.startedAt
        self.duration        = session.duration
        self.sampleCount     = session.sampleCount
        self.fileName        = session.fileName
        self.samplingRate    = session.samplingRate
        self.activityLabelID = session.activityLabelID
    }

    var asRecordingSession: RecordingSession {
        RecordingSession(
            id:              id,
            startedAt:       startedAt,
            duration:        duration,
            sampleCount:     sampleCount,
            fileName:        fileName,
            samplingRate:    samplingRate,
            activityLabelID: activityLabelID
        )
    }
}
