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
            return "Create ML 내보내기 완료: \(exportedFileCount)개 파일, \(skippedItemCount)개 건너뜀"
        }
        return "Create ML 내보내기 완료: \(exportedFileCount)개 파일"
    }
}

enum CreateMLActivityExportError: LocalizedError {
    case emptyFolder
    case noExportableSnaps([String])
    case missingSourceCSV

    var errorDescription: String? {
        switch self {
        case .emptyFolder:
            return "내보낼 스냅이 없습니다."
        case .noExportableSnaps(let reasons):
            let detail = reasons.prefix(3).joined(separator: "\n")
            return detail.isEmpty ? "내보낼 수 있는 스냅이 없습니다." : "내보낼 수 있는 스냅이 없습니다.\n\(detail)"
        case .missingSourceCSV:
            return "원본 recording.csv를 찾을 수 없습니다."
        }
    }
}
