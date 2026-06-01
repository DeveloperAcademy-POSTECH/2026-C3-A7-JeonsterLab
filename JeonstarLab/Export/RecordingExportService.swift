//
//  RecordingExportService.swift
//  Wrist Motion
//

import Foundation

@MainActor
final class RecordingExportService {
    private let repository: RecordingRepositoryProtocol
    private let fileManager: FileManager

    init(
        repository: RecordingRepositoryProtocol,
        fileManager: FileManager = .default
    ) {
        self.repository = repository
        self.fileManager = fileManager
    }

    func export(session: RecordingSession) throws -> [URL] {
        let samples = try repository.loadSamples(for: session.id)
        let snapDetectionMode = try repository.snapDetectionMode(for: session.id)
        let snapAnalysisResult: SnapAnalysisResult
        switch snapDetectionMode {
        case .none:
            snapAnalysisResult = SnapAnalysisResult(events: [])
        case .jeonFlip:
            snapAnalysisResult = AnalyzeSnapUseCase.execute(samples: samples)
        }
        let exportDirectory = try makeExportDirectory(for: session)

        let csvURL = exportDirectory.appendingPathComponent("recording.csv")
        let metadataURL = exportDirectory.appendingPathComponent("metadata.json")
        let snapAnalysisURL = exportDirectory.appendingPathComponent("snap_analysis.json")

        try RecordingCSVExporter
            .makeCSV(from: samples)
            .write(to: csvURL, atomically: true, encoding: .utf8)
        try RecordingMetadataExporter
            .makeJSONData(for: session, snapDetectionMode: snapDetectionMode)
            .write(to: metadataURL, options: .atomic)
        try SnapAnalysisJSONExporter
            .makeJSONData(for: session, result: snapAnalysisResult)
            .write(to: snapAnalysisURL, options: .atomic)

        return [csvURL, metadataURL, snapAnalysisURL]
    }

    private func makeExportDirectory(for session: RecordingSession) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("WristMotionExport", isDirectory: true)
            .appendingPathComponent(session.id.uuidString, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }
}

extension JSONEncoder {
    static var exportEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
