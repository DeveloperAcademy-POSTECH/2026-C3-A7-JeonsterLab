//
//  FolderDatasetExportReport.swift
//  JeonstarLab Mac
//

import Foundation

struct FolderDatasetExportReport: Equatable {
    let exportedSnapCount: Int
    let exportedRowCount: Int
    let skippedItemCount: Int
    let skippedReasons: [String]
    let outputURL: URL
    let generatedAt: Date

    var summaryText: String {
        var message = "CSV exported: \(exportedSnapCount) snaps, \(exportedRowCount) rows"
        if skippedItemCount > 0 {
            message += " · \(skippedItemCount) skipped"
        }
        return message
    }
}
