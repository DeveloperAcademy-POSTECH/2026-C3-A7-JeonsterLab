//
//  SnapSegmentMetadata.swift
//  JeonstarLab Mac
//

import Foundation

struct SnapSegmentMetadata: Codable, Equatable {
    let snapID: String
    let recordingID: UUID?
    let packageFolderName: String
    let packageDisplayName: String?
    let sourceType: SnapEventSourceType
    let label: RecordingPackageLabel
    let notes: String
    let startTime: Double?
    let peakTime: Double?
    let endTime: Double?
    let snapDuration: Double?
    let sampleCount: Int
    let peakAcceleration: Double?
    let peakGyro: Double?
    let peakDelay: Double?
    let dominantAxis: String?
    let rollRange: Double?
    let pitchRange: Double?
    let yawRange: Double?
    let confidence: String?
    let sourceRecordingCSVFileName: String?
    let sourceMetadataFileName: String?
    let sourceSnapAnalysisFileName: String?
    let segmentCSVFileName: String
    let createdAt: Date
    let updatedAt: Date
}
