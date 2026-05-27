//
//  SnapFolderStore.swift
//  JeonstarLab Mac
//

import Foundation

final class SnapFolderStore {
    private let fileManager: FileManager
    private let foldersURL: URL

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.foldersURL = rootURL.appendingPathComponent("folders.json")
    }

    var storageURL: URL {
        foldersURL
    }

    func loadFolders() -> [SnapFolder] {
        guard let data = try? Data(contentsOf: foldersURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SnapFolder].self, from: data)) ?? []
    }

    func saveFolders(_ folders: [SnapFolder]) throws {
        try fileManager.createDirectory(
            at: foldersURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(folders)
        try data.write(to: foldersURL, options: .atomic)
    }
}
