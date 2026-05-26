//
//  MacReceivedFileStore.swift
//  JeonstarLab Mac
//

import Foundation

final class MacReceivedFileStore {
    private let fileManager: FileManager
    private lazy var batchDirectory: URL = makeBatchDirectoryURL()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func saveReceivedFile(
        temporaryURL: URL,
        resourceName: String
    ) throws -> URL {
        try fileManager.createDirectory(
            at: batchDirectory,
            withIntermediateDirectories: true
        )

        let destination = uniqueDestinationURL(for: resourceName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
        return destination
    }

    private func uniqueDestinationURL(for resourceName: String) -> URL {
        let cleanName = URL(fileURLWithPath: resourceName).lastPathComponent
        return batchDirectory.appendingPathComponent(cleanName)
    }

    private func makeBatchDirectoryURL() -> URL {
        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documents
            .appendingPathComponent("JeonstarLab", isDirectory: true)
            .appendingPathComponent("ReceivedRecordings", isDirectory: true)
            .appendingPathComponent(Self.timestampFormatter.string(from: Date()), isDirectory: true)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
}
