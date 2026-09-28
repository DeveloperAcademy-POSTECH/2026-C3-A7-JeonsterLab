//
//  MotionCSVParser.swift
//  JeonstarLab Mac
//

import Foundation

nonisolated enum MotionCSVParser {
    static func parse(url: URL) throws -> [MotionCSVSample] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        let expectedHeader = "index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ"
        guard lines.first?.replacingOccurrences(of: "\u{FEFF}", with: "") == expectedHeader else {
            throw MotionCSVParserError.invalidHeader
        }
        var samples: [MotionCSVSample] = []
        for (offset, row) in lines.dropFirst().enumerated() {
            try Task.checkCancellation()
            if row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let columns = row.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count == 15, let index = Int(columns[0]) else {
                throw MotionCSVParserError.invalidRow(offset + 2)
            }
            let values = columns.dropFirst().compactMap { Double($0) }
            guard values.count == 14, values.allSatisfy({ $0.isFinite }) else {
                throw MotionCSVParserError.invalidRow(offset + 2)
            }
            let timestamp = values[0], relativeTime = values[1]
            let attitudeRoll = values[2], attitudePitch = values[3], attitudeYaw = values[4]
            let rotationRateX = values[5], rotationRateY = values[6], rotationRateZ = values[7]
            let gravityX = values[8], gravityY = values[9], gravityZ = values[10]
            let userAccX = values[11], userAccY = values[12], userAccZ = values[13]
            samples.append(MotionCSVSample(
                index: index,
                timestamp: timestamp,
                relativeTime: relativeTime,
                attitudeRoll: attitudeRoll,
                attitudePitch: attitudePitch,
                attitudeYaw: attitudeYaw,
                rotationRateX: rotationRateX,
                rotationRateY: rotationRateY,
                rotationRateZ: rotationRateZ,
                gravityX: gravityX,
                gravityY: gravityY,
                gravityZ: gravityZ,
                userAccX: userAccX,
                userAccY: userAccY,
                userAccZ: userAccZ
            ))
        }

        guard !samples.isEmpty else {
            throw MotionCSVParserError.noValidRows
        }

        return samples
    }
}

nonisolated enum MotionCSVParserError: LocalizedError {
    case noValidRows
    case invalidHeader
    case invalidRow(Int)

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "The CSV header does not match the supported recording format."
        case .invalidRow(let line):
            return "Invalid CSV data at line \(line). No samples were imported."
        case .noValidRows:
            return "No valid CSV samples found."
        }
    }
}
