//
//  CreateMLActivityExporter.swift
//  JeonstarLab Mac
//

import Foundation

enum CreateMLActivityExporter {
    static let csvHeader = [
        "relativeTime",
        "attitudeRoll",
        "attitudePitch",
        "attitudeYaw",
        "rotationRateX",
        "rotationRateY",
        "rotationRateZ",
        "gravityX",
        "gravityY",
        "gravityZ",
        "userAccX",
        "userAccY",
        "userAccZ"
    ].joined(separator: ",")

    static func export(
        folder: SnapFolder,
        packages: [ReceivedRecordingPackage],
        destinationDirectoryURL: URL,
        fileManager: FileManager = .default
    ) throws -> CreateMLActivityExportReport {
        guard !folder.items.isEmpty else {
            throw CreateMLActivityExportError.emptyFolder
        }

        let classFolderName = sanitizedFileName(folder.name)
        let classDirectoryURL = destinationDirectoryURL.appendingPathComponent(classFolderName, isDirectory: true)
        try fileManager.createDirectory(at: classDirectoryURL, withIntermediateDirectories: true)

        var skippedReasons: [String] = []
        var originalSamplesByPackageName: [String: [MotionCSVSample]] = [:]
        var exportedCount = 0
        var usedFileNames = Set<String>()

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

                let fileName = uniqueFileName(
                    classFolderName: classFolderName,
                    index: exportedCount + 1,
                    snapID: event.snapID,
                    usedFileNames: &usedFileNames
                )
                let csvURL = classDirectoryURL.appendingPathComponent(fileName)
                try csvString(for: segmentSamples).write(to: csvURL, atomically: true, encoding: .utf8)
                exportedCount += 1
            } catch {
                skippedReasons.append("\(item.packageFolderName) / \(item.snapID): \(error.localizedDescription)")
            }
        }

        guard exportedCount > 0 else {
            throw CreateMLActivityExportError.noExportableSnaps(skippedReasons)
        }

        return CreateMLActivityExportReport(
            exportedFileCount: exportedCount,
            skippedItemCount: skippedReasons.count,
            skippedReasons: skippedReasons,
            outputDirectoryURL: classDirectoryURL,
            generatedAt: Date()
        )
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
            throw CreateMLActivityExportError.missingSourceCSV
        }

        _ = try SnapSegmentExporter.export(
            package: package,
            event: event,
            samples: samples,
            fileManager: fileManager
        )
        return segmentCSVURL
    }

    private static func csvString(for samples: [MotionCSVSample]) -> String {
        guard let firstRelativeTime = samples.first?.relativeTime else {
            return csvHeader + "\n"
        }

        let rows = samples.map { sample in
            [
                formatted(sample.relativeTime - firstRelativeTime),
                formatted(sample.attitudeRoll),
                formatted(sample.attitudePitch),
                formatted(sample.attitudeYaw),
                formatted(sample.rotationRateX),
                formatted(sample.rotationRateY),
                formatted(sample.rotationRateZ),
                formatted(sample.gravityX),
                formatted(sample.gravityY),
                formatted(sample.gravityZ),
                formatted(sample.userAccX),
                formatted(sample.userAccY),
                formatted(sample.userAccZ)
            ].joined(separator: ",")
        }

        return ([csvHeader] + rows).joined(separator: "\n") + "\n"
    }

    private static func uniqueFileName(
        classFolderName: String,
        index: Int,
        snapID: String,
        usedFileNames: inout Set<String>
    ) -> String {
        let baseName = "\(classFolderName)_\(String(format: "%03d", index))_\(sanitizedFileName(snapID))"
        var candidate = "\(baseName).csv"
        var suffix = 1
        while usedFileNames.contains(candidate) {
            candidate = "\(baseName)_\(suffix).csv"
            suffix += 1
        }
        usedFileNames.insert(candidate)
        return candidate
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:*?\"<>|")
            .union(.newlines)
            .union(.controlCharacters)
        let sanitized = value.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? "_" : Character(scalar)
        }
        .reduce(into: "") { result, character in
            result.append(character)
        }
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "class" : sanitized
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
