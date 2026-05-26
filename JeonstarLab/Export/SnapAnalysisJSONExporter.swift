//
//  SnapAnalysisJSONExporter.swift
//  Wrist Motion
//

import Foundation

@MainActor
enum SnapAnalysisJSONExporter {
    static func makeJSONData(
        for session: RecordingSession,
        result: SnapAnalysisResult,
        generatedAt: Date = Date()
    ) throws -> Data {
        let payload = SnapAnalysisPayload(
            recordingID: session.id,
            generatedAt: generatedAt,
            eventCount: result.events.count,
            snapEvents: result.events.map(SnapEventPayload.init(event:))
        )

        return try JSONEncoder.exportEncoder.encode(payload)
    }
}

private struct SnapAnalysisPayload: Encodable {
    let recordingID: UUID
    let generatedAt: Date
    let eventCount: Int
    let snapEvents: [SnapEventPayload]
}

private struct SnapEventPayload: Encodable {
    let eventIndex: Int
    let startTime: Double
    let peakTime: Double
    let endTime: Double
    let snapDuration: Double
    let peakAcceleration: Double
    let peakGyro: Double
    let peakDelay: Double
    let dominantAxis: String
    let rollRange: Double
    let pitchRange: Double
    let yawRange: Double
    let confidence: String

    init(event: SnapEventSummary) {
        eventIndex = event.eventIndex
        startTime = event.startTime
        peakTime = event.peakTime
        endTime = event.endTime
        snapDuration = event.snapDuration
        peakAcceleration = event.peakAcceleration
        peakGyro = event.peakGyro
        peakDelay = event.peakDelay
        dominantAxis = event.dominantAxis.exportValue
        rollRange = event.rollRange
        pitchRange = event.pitchRange
        yawRange = event.yawRange
        confidence = event.confidence.exportValue
    }
}

private extension SnapAxis {
    var exportValue: String {
        switch self {
        case .x:
            return "x"
        case .y:
            return "y"
        case .z:
            return "z"
        }
    }
}

private extension SnapConfidence {
    var exportValue: String {
        switch self {
        case .high:
            return "high"
        case .medium:
            return "medium"
        case .low:
            return "low"
        }
    }
}
