//
//  ReceiverProjectManifest.swift
//  JeonstarLab Mac
//

import Foundation

struct ReceiverProjectManifest: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let appName: String
    let packageID: UUID
    let exportedAt: Date
    let recordingCount: Int
    let folderCount: Int
    let notes: String

    init(
        packageID: UUID = UUID(),
        exportedAt: Date = Date(),
        recordingCount: Int,
        folderCount: Int
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.appName = "JeonstarLab Receiver"
        self.packageID = packageID
        self.exportedAt = exportedAt
        self.recordingCount = recordingCount
        self.folderCount = folderCount
        self.notes = "ZIP-based JeonstarLab Receiver project package."
    }
}

struct ReceiverProjectPackageReport {
    let recordingCount: Int
    let folderCount: Int
    let outputURL: URL?
    let message: String
}
