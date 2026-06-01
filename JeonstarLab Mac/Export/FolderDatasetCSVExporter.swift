//
//  FolderDatasetCSVExporter.swift
//  JeonstarLab Mac
//

import Foundation

enum FolderDatasetCSVExporter {
    static func csvString(
        for entries: [FolderDatasetSnapEntry],
        options: DatasetExportOptions = .default
    ) -> String {
        let csvRows = entries.flatMap { entry in
            rows(for: entry, options: options)
        }
        return ([header(options: options)] + csvRows).joined(separator: "\n") + "\n"
    }

    private static func header(options: DatasetExportOptions) -> String {
        let headers = [
            DatasetRequiredColumn.snapID.header,
            DatasetRequiredColumn.sampleIndex.header,
            DatasetRequiredColumn.label.header
        ]
        + DatasetUserInfoColumn.allCases
            .filter { options.userInfoColumns.contains($0) }
            .map(\.header)
        + DatasetMotionColumn.allCases
            .filter { options.motionColumns.contains($0) }
            .map(\.header)

        return headers.joined(separator: ",")
    }

    private static func rows(
        for entry: FolderDatasetSnapEntry,
        options: DatasetExportOptions
    ) -> [String] {
        guard let firstTimestamp = entry.samples.first?.timestamp else {
            return []
        }

        return entry.samples.enumerated().map { sampleIndex, sample in
            let requiredValues = [
                escaped(entry.snapID),
                "\(sampleIndex)",
                escaped(entry.label)
            ]
            let userInfoValues = DatasetUserInfoColumn.allCases
                .filter { options.userInfoColumns.contains($0) }
                .map { escaped(userInfoValue($0, from: entry.participantInfo)) }
            let motionValues = DatasetMotionColumn.allCases
                .filter { options.motionColumns.contains($0) }
                .map { motionValue($0, from: sample, firstTimestamp: firstTimestamp) }

            return (requiredValues + userInfoValues + motionValues).joined(separator: ",")
        }
    }

    private static func userInfoValue(
        _ column: DatasetUserInfoColumn,
        from participantInfo: RecordingParticipantInfo
    ) -> String {
        switch column {
        case .userNickname:
            return participantInfo.nameOrNickname
        case .userGender:
            return participantInfo.gender == .unspecified ? "" : participantInfo.gender.displayName
        case .userAgeGroup:
            return participantInfo.ageGroup == .unspecified ? "" : participantInfo.ageGroup.displayName
        case .userHeightCM:
            return participantInfo.heightCM
        case .userDominantHand:
            return participantInfo.dominantHand == .unspecified ? "" : participantInfo.dominantHand.displayName
        case .userSkillLevel:
            return participantInfo.skillLevel == .unspecified ? "" : participantInfo.skillLevel.displayName
        case .userMemo:
            return participantInfo.memo
        }
    }

    private static func motionValue(
        _ column: DatasetMotionColumn,
        from sample: MotionCSVSample,
        firstTimestamp: Double
    ) -> String {
        switch column {
        case .relativeTime:
            return formatted(sample.timestamp - firstTimestamp)
        case .timestamp:
            return formatted(sample.timestamp)
        case .attitudeRoll:
            return formatted(sample.attitudeRoll)
        case .attitudePitch:
            return formatted(sample.attitudePitch)
        case .attitudeYaw:
            return formatted(sample.attitudeYaw)
        case .rotationRateX:
            return formatted(sample.rotationRateX)
        case .rotationRateY:
            return formatted(sample.rotationRateY)
        case .rotationRateZ:
            return formatted(sample.rotationRateZ)
        case .gravityX:
            return formatted(sample.gravityX)
        case .gravityY:
            return formatted(sample.gravityY)
        case .gravityZ:
            return formatted(sample.gravityZ)
        case .userAccX:
            return formatted(sample.userAccX)
        case .userAccY:
            return formatted(sample.userAccY)
        case .userAccZ:
            return formatted(sample.userAccZ)
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
    let participantInfo: RecordingParticipantInfo
    let samples: [MotionCSVSample]
}
