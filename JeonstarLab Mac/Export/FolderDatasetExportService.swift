//
//  FolderDatasetExportService.swift
//  JeonstarLab Mac
//

import Foundation

enum FolderDatasetExportService {
    static func export(
        folder: SnapFolder,
        packages: [ReceivedRecordingPackage],
        outputURL: URL,
        options: DatasetExportOptions = .default,
        fileManager: FileManager = .default
    ) throws -> FolderDatasetExportReport {
        var entries: [FolderDatasetSnapEntry] = []
        var skippedReasons: [String] = []
        var originalSamplesByPackageName: [String: [MotionCSVSample]] = [:]

        for item in folder.items {
            guard !item.snapID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skippedReasons.append("snapID 없음: \(item.packageFolderName)")
                continue
            }

            guard let package = packages.first(where: { $0.folderURL.lastPathComponent == item.packageFolderName }) else {
                skippedReasons.append("패키지 없음: \(item.packageFolderName) / \(item.snapID)")
                continue
            }

            guard let event = package.workingSnapEvents.first(where: { package.isSnapID(item.snapID, matching: $0) }) else {
                skippedReasons.append("스냅 없음 또는 삭제됨: \(item.packageFolderName) / \(item.snapID)")
                continue
            }

            guard let datasetLabel = datasetLabel(
                folderName: folder.name,
                item: item,
                package: package,
                event: event
            ) else {
                skippedReasons.append("라벨 없음: \(item.packageFolderName) / \(item.snapID)")
                continue
            }

            do {
                let segmentURL = try segmentCSVURL(
                    package: package,
                    event: event,
                    originalSamplesByPackageName: &originalSamplesByPackageName,
                    fileManager: fileManager
                )
                let segmentSamples = try MotionCSVParser.parse(url: segmentURL)
                guard !segmentSamples.isEmpty else {
                    skippedReasons.append("세그먼트 샘플 없음: \(item.packageFolderName) / \(item.snapID)")
                    continue
                }

                entries.append(
                    FolderDatasetSnapEntry(
                        snapID: event.snapID,
                        label: datasetLabel,
                        participantInfo: package.participantInfo,
                        samples: segmentSamples
                    )
                )
            } catch {
                skippedReasons.append("\(item.packageFolderName) / \(item.snapID): \(error.localizedDescription)")
            }
        }

        guard !entries.isEmpty else {
            throw FolderDatasetExportError.noExportableSnaps(skippedReasons)
        }

        let csv = FolderDatasetCSVExporter.csvString(for: entries, options: options)
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try csv.write(to: outputURL, atomically: true, encoding: .utf8)

        return FolderDatasetExportReport(
            exportedSnapCount: entries.count,
            exportedRowCount: entries.reduce(0) { $0 + $1.samples.count },
            skippedItemCount: skippedReasons.count,
            skippedReasons: skippedReasons,
            outputURL: outputURL,
            generatedAt: Date()
        )
    }

    static func defaultFileName(folderName: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "dataset_\(filesystemSafeName(folderName))_\(formatter.string(from: date)).csv"
    }

    private static func segmentCSVURL(
        package: ReceivedRecordingPackage,
        event: WorkingSnapEvent,
        originalSamplesByPackageName: inout [String: [MotionCSVSample]],
        fileManager: FileManager
    ) throws -> URL {
        let segmentFolderURL = SnapSegmentExporter.segmentFolderURL(
            package: package,
            snapID: event.snapID
        )
        let segmentCSVURL = segmentFolderURL.appendingPathComponent("segment.csv")
        let segmentMetadataURL = segmentFolderURL.appendingPathComponent("segment_metadata.json")

        if fileManager.fileExists(atPath: segmentCSVURL.path),
           fileManager.fileExists(atPath: segmentMetadataURL.path) {
            return segmentCSVURL
        }

        let packageFolderName = package.folderURL.lastPathComponent
        let samples: [MotionCSVSample]
        if let cachedSamples = originalSamplesByPackageName[packageFolderName] {
            samples = cachedSamples
        } else if let csvURL = package.csvURL {
            let parsedSamples = try MotionCSVParser.parse(url: csvURL)
            originalSamplesByPackageName[packageFolderName] = parsedSamples
            samples = parsedSamples
        } else {
            throw FolderDatasetExportError.missingSourceCSV
        }

        _ = try SnapSegmentExporter.export(
            package: package,
            event: event,
            samples: samples,
            fileManager: fileManager
        )
        return segmentCSVURL
    }

    private static func datasetLabel(
        folderName: String,
        item: SnapFolderItem,
        package: ReceivedRecordingPackage,
        event: WorkingSnapEvent
    ) -> String? {
        let explicitLabel = package.snapEventLabels[event.snapID]?.label ?? event.label
        if let mapped = datasetLabel(from: explicitLabel) {
            return mapped
        }

        if let mapped = datasetLabel(from: item.label) {
            return mapped
        }

        return datasetLabel(fromFolderName: folderName)
    }

    private static func datasetLabel(from label: RecordingPackageLabel) -> String? {
        switch label {
        case .success:
            return "success"
        case .partialSuccess:
            return "partial"
        case .failure:
            return "failure"
        case .unlabeled, .other:
            return nil
        }
    }

    private static func datasetLabel(fromFolderName folderName: String) -> String? {
        let normalized = folderName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "success", "성공":
            return "success"
        case "partial", "partialsuccess", "부분 성공", "부분성공":
            return "partial"
        case "failure", "fail", "실패":
            return "failure"
        default:
            return nil
        }
    }

    private static func filesystemSafeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safeName = String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        return safeName.isEmpty ? "folder" : safeName
    }
}

enum FolderDatasetExportError: LocalizedError {
    case missingSourceCSV
    case noExportableSnaps([String])

    var errorDescription: String? {
        switch self {
        case .missingSourceCSV:
            return "원본 recording.csv를 찾을 수 없습니다."
        case .noExportableSnaps(let reasons):
            let detail = reasons.prefix(3).joined(separator: "\n")
            return detail.isEmpty ? "내보낼 수 있는 스냅이 없습니다." : "내보낼 수 있는 스냅이 없습니다.\n\(detail)"
        }
    }
}
