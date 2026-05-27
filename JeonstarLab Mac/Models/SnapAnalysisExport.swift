//
//  SnapAnalysisExport.swift
//  JeonstarLab Mac
//

import Foundation

struct SnapAnalysisExport: Decodable, Equatable {
    let recordingID: UUID?
    let generatedAt: Date?
    let eventCount: Int?
    let snapEvents: [SnapEventExport]

    enum CodingKeys: String, CodingKey {
        case recordingID
        case generatedAt
        case eventCount
        case snapEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordingID = try container.decodeIfPresent(UUID.self, forKey: .recordingID)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        eventCount = try container.decodeIfPresent(Int.self, forKey: .eventCount)
        snapEvents = try container.decodeIfPresent([SnapEventExport].self, forKey: .snapEvents) ?? []
    }
}

struct SnapEventExport: Decodable, Equatable, Identifiable {
    var id: Int { eventIndex ?? Int(startTime ?? 0) }

    let eventIndex: Int?
    let startTime: Double?
    let peakTime: Double?
    let endTime: Double?
    let snapDuration: Double?
    let peakAcceleration: Double?
    let peakGyro: Double?
    let peakDelay: Double?
    let dominantAxis: String?
    let rollRange: Double?
    let pitchRange: Double?
    let yawRange: Double?
    let confidence: String?
}
