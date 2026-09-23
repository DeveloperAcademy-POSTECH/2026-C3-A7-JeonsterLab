//
//  CreateMLActivityExportReport.swift
//  JeonstarLab Mac
//

import Foundation

struct CreateMLActivityExportReport {
    let exportedFileCount: Int
    let skippedItemCount: Int
    let skippedReasons: [String]
    let outputDirectoryURL: URL
    let generatedAt: Date

    var summaryText: String {
        if skippedItemCount > 0 {
            return "Create ML exported: \(exportedFileCount) files; \(skippedItemCount) skipped"
        }
        return "Create ML exported: \(exportedFileCount) files"
    }
}

enum CreateMLActivityExportError: LocalizedError {
    case emptyFolder
    case noExportableSnaps([String])
    case missingSourceCSV

    var errorDescription: String? {
        switch self {
        case .emptyFolder:
            return "No snaps to export."
        case .noExportableSnaps(let reasons):
            let detail = reasons.prefix(3).joined(separator: "\n")
            return detail.isEmpty ? "No exportable snaps found." : "No exportable snaps found.\n\(detail)"
        case .missingSourceCSV:
            return "The source recording.csv could not be found."
        }
    }
}
