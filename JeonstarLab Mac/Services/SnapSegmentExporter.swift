//
//  SnapSegmentExporter.swift
//  JeonstarLab Mac
//

import Foundation

enum SnapSegmentExporter {
    static func export(
        package: ReceivedRecordingPackage,
        event: WorkingSnapEvent,
        samples: [MotionCSVSample],
        fileManager: FileManager = .default
    ) throws -> SnapSegmentFile {
        guard let startTime = event.startTime,
              let endTime = event.endTime else {
            throw SnapSegmentExporterError.missingTimeRange
        }

        let lowerBound = min(startTime, endTime)
        let upperBound = max(startTime, endTime)
        let segmentSamples = samples.filter {
            $0.relativeTime >= lowerBound && $0.relativeTime <= upperBound
        }

        guard !segmentSamples.isEmpty else {
            throw SnapSegmentExporterError.noSamplesInRange
        }

        let segmentRootURL = package.folderURL.appendingPathComponent("segments", isDirectory: true)
        let segmentFolderURL = segmentRootURL.appendingPathComponent(
            filesystemSafeName(event.snapID),
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: segmentFolderURL,
            withIntermediateDirectories: true
        )

        let csvURL = segmentFolderURL.appendingPathComponent("segment.csv")
        let metadataURL = segmentFolderURL.appendingPathComponent("segment_metadata.json")

        try csvString(for: segmentSamples).write(to: csvURL, atomically: true, encoding: .utf8)

        let now = Date()
        let metadata = SnapSegmentMetadata(
            snapID: event.snapID,
            recordingID: event.recordingID ?? package.metadata?.recordingID ?? package.snapAnalysis?.recordingID,
            packageFolderName: package.folderURL.lastPathComponent,
            packageDisplayName: package.displayName.isEmpty ? nil : package.displayName,
            sourceType: event.sourceType,
            label: event.label,
            notes: event.notes,
            startTime: lowerBound,
            peakTime: event.peakTime,
            endTime: upperBound,
            snapDuration: event.snapDuration ?? (upperBound - lowerBound),
            sampleCount: segmentSamples.count,
            peakAcceleration: event.peakAcceleration,
            peakGyro: event.peakGyro,
            peakDelay: event.peakDelay,
            dominantAxis: event.dominantAxis,
            rollRange: event.rollRange,
            pitchRange: event.pitchRange,
            yawRange: event.yawRange,
            confidence: event.confidence,
            sourceRecordingCSVFileName: package.csvURL?.lastPathComponent,
            sourceMetadataFileName: package.metadataURL?.lastPathComponent,
            sourceSnapAnalysisFileName: package.snapAnalysisURL?.lastPathComponent,
            segmentCSVFileName: csvURL.lastPathComponent,
            createdAt: event.createdAt ?? now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)

        return SnapSegmentFile(
            snapID: event.snapID,
            folderURL: segmentFolderURL,
            csvURL: csvURL,
            metadataURL: metadataURL,
            sampleCount: segmentSamples.count
        )
    }

    static func segmentExists(
        package: ReceivedRecordingPackage,
        snapID: String,
        fileManager: FileManager = .default
    ) -> Bool {
        let folderURL = segmentFolderURL(package: package, snapID: snapID)
        return fileManager.fileExists(atPath: folderURL.appendingPathComponent("segment.csv").path)
            && fileManager.fileExists(atPath: folderURL.appendingPathComponent("segment_metadata.json").path)
    }

    static func segmentFolderURL(package: ReceivedRecordingPackage, snapID: String) -> URL {
        package.folderURL
            .appendingPathComponent("segments", isDirectory: true)
            .appendingPathComponent(filesystemSafeName(snapID), isDirectory: true)
    }

    private static func csvString(for samples: [MotionCSVSample]) -> String {
        let header = [
            "index",
            "timestamp",
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

        let rows = samples.map { sample in
            [
                "\(sample.index)",
                formatted(sample.timestamp),
                formatted(sample.relativeTime),
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

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func filesystemSafeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
    }
}

enum SnapSegmentExporterError: LocalizedError {
    case missingTimeRange
    case noSamplesInRange

    var errorDescription: String? {
        switch self {
        case .missingTimeRange:
            return "스냅 이벤트의 시작/끝 시간이 없습니다."
        case .noSamplesInRange:
            return "선택된 스냅 구간 안에 샘플이 없습니다."
        }
    }
}
