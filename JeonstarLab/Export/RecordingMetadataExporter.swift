//
//  RecordingMetadataExporter.swift
//  Wrist Motion
//

import Foundation

enum RecordingMetadataExporter {
    static func makeJSONData(
        for session: RecordingSession,
        snapDetectionMode: SnapDetectionMode
    ) throws -> Data {
        let metadata = RecordingMetadataPayload(
            recordingID: session.id,
            startedAt: session.startedAt,
            duration: session.duration,
            sampleCount: session.sampleCount,
            samplingRate: session.samplingRate,
            fileName: session.fileName,
            snapDetectionMode: snapDetectionMode.rawValue
        )

        return try JSONEncoder.exportEncoder.encode(metadata)
    }
}

private struct RecordingMetadataPayload: Encodable {
    let recordingID: UUID
    let startedAt: Date
    let duration: TimeInterval
    let sampleCount: Int
    let samplingRate: Int
    let fileName: String
    let snapDetectionMode: String
}
