//
//  FolderDatasetCSVExporter.swift
//  JeonstarLab Mac
//

import Foundation

enum FolderDatasetCSVExporter {
    static let header = [
        "snapID",
        "sampleIndex",
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
        "userAccZ",
        "label"
    ].joined(separator: ",")

    static func csvString(for entries: [FolderDatasetSnapEntry]) -> String {
        let csvRows = entries.flatMap { entry in
            rows(for: entry)
        }
        return ([header] + csvRows).joined(separator: "\n") + "\n"
    }

    private static func rows(for entry: FolderDatasetSnapEntry) -> [String] {
        guard let firstTimestamp = entry.samples.first?.timestamp else {
            return []
        }

        return entry.samples.enumerated().map { sampleIndex, sample in
            [
                escaped(entry.snapID),
                "\(sampleIndex)",
                formatted(sample.timestamp - firstTimestamp),
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
                formatted(sample.userAccZ),
                escaped(entry.label)
            ].joined(separator: ",")
        }
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

struct FolderDatasetSnapEntry {
    let snapID: String
    let label: String
    let samples: [MotionCSVSample]
}
