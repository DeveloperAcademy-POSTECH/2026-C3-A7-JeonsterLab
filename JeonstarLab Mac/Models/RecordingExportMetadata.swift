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
}
