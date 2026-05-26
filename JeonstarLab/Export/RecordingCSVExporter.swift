//
//  RecordingCSVExporter.swift
//  Wrist Motion
//

import Foundation

enum RecordingCSVExporter {
    private static let header = [
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

    static func makeCSV(from samples: [MotionSample]) -> String {
        let baseTimestamp = samples.first?.timestamp ?? 0
        var rows = [header]
        rows.reserveCapacity(samples.count + 1)

        for (index, sample) in samples.enumerated() {
            let relativeTime = sample.timestamp - baseTimestamp
            rows.append([
                "\(index)",
                format(sample.timestamp),
                format(relativeTime),
                format(sample.attitudeRoll),
                format(sample.attitudePitch),
                format(sample.attitudeYaw),
                format(sample.rotationRateX),
                format(sample.rotationRateY),
                format(sample.rotationRateZ),
                format(sample.gravityX),
                format(sample.gravityY),
                format(sample.gravityZ),
                format(sample.userAccX),
                format(sample.userAccY),
                format(sample.userAccZ)
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
