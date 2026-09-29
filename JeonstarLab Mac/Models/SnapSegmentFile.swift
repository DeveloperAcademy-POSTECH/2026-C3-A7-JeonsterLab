//
//  SnapSegmentFile.swift
//  JeonstarLab Mac
//

import Foundation

nonisolated struct SnapSegmentFile: Equatable {
    let snapID: String
    let folderURL: URL
    let csvURL: URL
    let metadataURL: URL
    let sampleCount: Int
}
