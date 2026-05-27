//
//  SnapFolderItem.swift
//  JeonstarLab Mac
//

import Foundation

struct SnapFolderItem: Identifiable, Codable, Equatable {
    let itemID: UUID
    var id: UUID { itemID }

    let snapID: String
    let recordingID: UUID?
    let packageFolderName: String
    let packageFolderURLString: String
    let packageDisplayName: String?
    let recordingStartedAt: Date?
    let sourceType: SnapEventSourceType
    var label: RecordingPackageLabel
    var notes: String
    let startTime: Double?
    let peakTime: Double?
    let endTime: Double?
    let segmentCSVRelativePath: String?
    let segmentMetadataRelativePath: String?
    let addedAt: Date

    init(
        itemID: UUID = UUID(),
        snapID: String,
        recordingID: UUID?,
        packageFolderName: String,
        packageFolderURLString: String,
        packageDisplayName: String?,
        recordingStartedAt: Date?,
        sourceType: SnapEventSourceType,
        label: RecordingPackageLabel,
        notes: String,
        startTime: Double?,
        peakTime: Double?,
        endTime: Double?,
        segmentCSVRelativePath: String?,
        segmentMetadataRelativePath: String?,
        addedAt: Date = Date()
    ) {
        self.itemID = itemID
        self.snapID = snapID
        self.recordingID = recordingID
        self.packageFolderName = packageFolderName
        self.packageFolderURLString = packageFolderURLString
        self.packageDisplayName = packageDisplayName
        self.recordingStartedAt = recordingStartedAt
        self.sourceType = sourceType
        self.label = label
        self.notes = notes
        self.startTime = startTime
        self.peakTime = peakTime
        self.endTime = endTime
        self.segmentCSVRelativePath = segmentCSVRelativePath
        self.segmentMetadataRelativePath = segmentMetadataRelativePath
        self.addedAt = addedAt
    }
}
