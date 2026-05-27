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
        var message = "CSV 내보내기 완료: \(exportedSnapCount)개 스냅, \(exportedRowCount)개 행"
        if skippedItemCount > 0 {
            message += " · \(skippedItemCount)개 제외"
        }
        return message
    }
}
