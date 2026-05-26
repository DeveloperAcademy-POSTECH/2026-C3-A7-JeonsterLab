//
//  MacReceivedFileStore.swift
//  JeonstarLab Mac
//

import Foundation

final class MacReceivedFileStore {
    private let fileManager: FileManager
    private var batchDirectory: URL?
    private var receivedFileNames: Set<String> = []

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func saveReceivedFile(
        temporaryURL: URL,
        resourceName: String
    ) throws -> URL {
        let cleanName = URL(fileURLWithPath: resourceName).lastPathComponent
        let directory = currentBatchDirectory(for: cleanName)

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let destination = directory.appendingPathComponent(cleanName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
        receivedFileNames.insert(cleanName)
        return destination
    }

    var rootDirectory: URL {
        documentsRootDirectory()
    }

    private func currentBatchDirectory(for resourceName: String) -> URL {
        if resourceName == "recording.csv" || batchDirectory == nil || isCurrentBatchComplete {
            batchDirectory = makeBatchDirectoryURL()
            receivedFileNames.removeAll()
        }

        return batchDirectory ?? makeBatchDirectoryURL()
    }

    private var isCurrentBatchComplete: Bool {
        ["recording.csv", "metadata.json", "snap_analysis.json"]
            .allSatisfy { receivedFileNames.contains($0) }
    }

    private func makeBatchDirectoryURL() -> URL {
        documentsRootDirectory()
            .appendingPathComponent(Self.timestampFormatter.string(from: Date()), isDirectory: true)
    }

    private func documentsRootDirectory() -> URL {
        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documents
            .appendingPathComponent("JeonstarLab", isDirectory: true)
            .appendingPathComponent("ReceivedRecordings", isDirectory: true)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
}
