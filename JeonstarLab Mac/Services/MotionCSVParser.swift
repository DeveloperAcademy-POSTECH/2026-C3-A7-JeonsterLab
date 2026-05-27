//
//  MotionCSVParser.swift
//  JeonstarLab Mac
//

import Foundation

enum MotionCSVParser {
    static func parse(url: URL) throws -> [MotionCSVSample] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let rows = text
            .split(whereSeparator: \.isNewline)
            .dropFirst()

        let samples = rows.compactMap { row -> MotionCSVSample? in
            let columns = row.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count >= 15,
                  let index = Int(columns[0]),
                  let timestamp = Double(columns[1]),
                  let relativeTime = Double(columns[2]),
                  let attitudeRoll = Double(columns[3]),
                  let attitudePitch = Double(columns[4]),
                  let attitudeYaw = Double(columns[5]),
                  let rotationRateX = Double(columns[6]),
                  let rotationRateY = Double(columns[7]),
                  let rotationRateZ = Double(columns[8]),
                  let gravityX = Double(columns[9]),
                  let gravityY = Double(columns[10]),
                  let gravityZ = Double(columns[11]),
                  let userAccX = Double(columns[12]),
                  let userAccY = Double(columns[13]),
                  let userAccZ = Double(columns[14]) else {
                return nil
            }

            return MotionCSVSample(
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
            )
        }

        guard !samples.isEmpty else {
            throw MotionCSVParserError.noValidRows
        }

        return samples
    }
}

enum MotionCSVParserError: LocalizedError {
    case noValidRows

    var errorDescription: String? {
        switch self {
        case .noValidRows:
            return "유효한 CSV 샘플이 없습니다."
        }
    }
}
