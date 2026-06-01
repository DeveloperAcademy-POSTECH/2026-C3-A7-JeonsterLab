//
//  RecordingExportMetadata.swift
//  JeonstarLab Mac
//

import Foundation

struct RecordingExportMetadata: Decodable, Equatable {
    let recordingID: UUID?
    let startedAt: Date?
    let duration: TimeInterval?
    let sampleCount: Int?
    let samplingRate: Int?
    let fileName: String?
    let snapDetectionMode: MacSnapDetectionMode

    enum CodingKeys: String, CodingKey {
        case recordingID
        case startedAt
        case duration
        case sampleCount
        case samplingRate
        case fileName
        case snapDetectionMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordingID = try container.decodeIfPresent(UUID.self, forKey: .recordingID)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        sampleCount = try container.decodeIfPresent(Int.self, forKey: .sampleCount)
        samplingRate = try container.decodeIfPresent(Int.self, forKey: .samplingRate)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        snapDetectionMode = try container.decodeIfPresent(
            MacSnapDetectionMode.self,
            forKey: .snapDetectionMode
        ) ?? .none
    }
}
