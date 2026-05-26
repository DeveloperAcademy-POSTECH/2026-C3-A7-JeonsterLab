//
//  RecordingMetadataJSONParser.swift
//  JeonstarLab Mac
//

import Foundation

enum RecordingMetadataJSONParser {
    static func parse(url: URL) throws -> RecordingExportMetadata {
        let data = try Data(contentsOf: url)
        return try JSONDecoder.exportDecoder.decode(RecordingExportMetadata.self, from: data)
    }
}

extension JSONDecoder {
    static var exportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.exportFormatter.date(from: value)
                ?? ISO8601DateFormatter.exportFormatterWithFractionalSeconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "지원하지 않는 날짜 형식입니다."
            )
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    static let exportFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let exportFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
