//
//  ReceiverProjectPackageService.swift
//  JeonstarLab Mac
//

import Foundation
import ZIPFoundation

nonisolated enum ReceiverProjectPackageError: LocalizedError {
    case missingManifest
    case unsupportedVersion(Int)
    case missingRecordingsDirectory
    case unsafeDestination(URL)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "The project manifest could not be found."
        case .unsupportedVersion(let version):
            return "Unsupported project package version: \(version)"
        case .missingRecordingsDirectory:
            return "The recordings folder could not be found."
        case .unsafeDestination(let url):
            return "Unsafe copy path: \(url.lastPathComponent)"
        case .processFailed(let message):
            return message
        }
    }
}

nonisolated enum ReceiverProjectPackageService {
    private static let manifestFileName = "project_manifest.json"
    private static let recordingsDirectoryName = "recordings"
    private static let foldersDirectoryName = "folders"
    private static let projectDirectoryName = "project"
    private static let foldersFileName = "folders.json"

    static func defaultFileName() -> String {
        ProjectExportPreferences.fileName()
    }

    static func exportProject(
        recordingsRootURL: URL,
        foldersRootURL: URL,
        workspaceName: String,
        folders: [SnapFolder],
        outputURL: URL,
        packageID: UUID = UUID()
    ) throws -> ReceiverProjectPackageReport {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: recordingsRootURL, withIntermediateDirectories: true)

        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("watchmotion-project-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = fileManager.temporaryDirectory
            .appendingPathComponent("watchmotion-project-\(UUID().uuidString).zip")

        defer {
            try? fileManager.removeItem(at: stagingURL)
            try? fileManager.removeItem(at: archiveURL)
        }

        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        let recordingsURL = stagingURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        let foldersURL = stagingURL.appendingPathComponent(foldersDirectoryName, isDirectory: true)
        let projectURL = stagingURL.appendingPathComponent(projectDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: foldersURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let recordingURLs = try receivedRecordingDirectories(in: recordingsRootURL)
        for recordingURL in recordingURLs {
            try Task.checkCancellation()
            try copyDirectory(
                from: recordingURL,
                to: recordingsURL.appendingPathComponent(recordingURL.lastPathComponent, isDirectory: true)
            )
        }

        try writeJSON(folders, to: foldersURL.appendingPathComponent(foldersFileName))
        let labels = try ProjectLabelCatalog.load(root: recordingsRootURL)
        try writeJSON(labels, to: recordingsURL.appendingPathComponent(ProjectLabelCatalog.fileName))

        let manifest = ReceiverProjectManifest(
            packageID: packageID,
            recordingCount: recordingURLs.count,
            folderCount: folders.count
        )
        try writeJSON(manifest, to: stagingURL.appendingPathComponent(manifestFileName))
        try writeJSON(
            [
                "name": workspaceName,
                "createdAt": ISO8601DateFormatter().string(from: manifest.exportedAt)
            ],
            to: projectURL.appendingPathComponent("project_info.json")
        )

        try createArchive(from: stagingURL, at: archiveURL)

        let finalOutputURL = normalizedProjectPackageURL(outputURL)
        try Task.checkCancellation()
        try Data(contentsOf: archiveURL, options: .mappedIfSafe).write(to: finalOutputURL, options: .atomic)

        return ReceiverProjectPackageReport(
            recordingCount: recordingURLs.count,
            folderCount: folders.count,
            outputURL: finalOutputURL,
            message: "Project package exported"
        )
    }

    static func openProjectWorkspace(
        packageURL: URL,
        projectsRootURL: URL
    ) throws -> ReceiverWorkspace {
        let fileManager = FileManager.default
        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("watchmotion-open-\(UUID().uuidString)", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: extractionURL)
        }

        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try extractSafely(packageURL, to: extractionURL)

        let manifestURL = extractionURL.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ReceiverProjectPackageError.missingManifest
        }

        let manifest = try readJSON(ReceiverProjectManifest.self, from: manifestURL)
        guard (1...ReceiverProjectManifest.currentFormatVersion).contains(manifest.formatVersion) else {
            throw ReceiverProjectPackageError.unsupportedVersion(manifest.formatVersion)
        }

        let extractedRecordingsURL = extractionURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: extractedRecordingsURL.path) else {
            throw ReceiverProjectPackageError.missingRecordingsDirectory
        }

        try fileManager.createDirectory(at: projectsRootURL, withIntermediateDirectories: true)

        let projectName = packageURL.deletingPathExtension().lastPathComponent
        let workspaceDirectoryName = uniqueDirectoryName(
            baseName: safeFileName("\(projectName)-\(manifest.packageID.uuidString.prefix(8))"),
            in: projectsRootURL
        )
        let workspaceRootURL = projectsRootURL.appendingPathComponent(workspaceDirectoryName, isDirectory: true)
        guard isChild(workspaceRootURL, of: projectsRootURL) else {
            throw ReceiverProjectPackageError.unsafeDestination(workspaceRootURL)
        }

        try fileManager.createDirectory(at: workspaceRootURL, withIntermediateDirectories: true)
        var committed = false
        defer { if !committed { try? fileManager.removeItem(at: workspaceRootURL) } }
        try fileManager.copyItem(
            at: manifestURL,
            to: workspaceRootURL.appendingPathComponent(manifestFileName)
        )
        try copyDirectory(
            from: extractedRecordingsURL,
            to: workspaceRootURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        )

        let extractedFoldersURL = extractionURL.appendingPathComponent(foldersDirectoryName, isDirectory: true)
        let workspaceFoldersURL = workspaceRootURL.appendingPathComponent(foldersDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: extractedFoldersURL.path) {
            try copyDirectory(from: extractedFoldersURL, to: workspaceFoldersURL)
        } else {
            try fileManager.createDirectory(at: workspaceFoldersURL, withIntermediateDirectories: true)
        }

        let extractedProjectURL = extractionURL.appendingPathComponent(projectDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: extractedProjectURL.path) {
            try copyDirectory(
                from: extractedProjectURL,
                to: workspaceRootURL.appendingPathComponent(projectDirectoryName, isDirectory: true)
            )
        }

        let savedFoldersURL = workspaceFoldersURL.appendingPathComponent(foldersFileName)
        if fileManager.fileExists(atPath: savedFoldersURL.path) {
            var folders = try readJSON([SnapFolder].self, from: savedFoldersURL)
            for index in folders.indices {
                for item in folders[index].items {
                    guard !item.packageFolderName.isEmpty, item.packageFolderName != ".",
                        item.packageFolderName != "..", !item.packageFolderName.contains("/"),
                        !item.packageFolderName.contains("\\") else {
                        throw ReceiverProjectPackageError.processFailed("Unsafe recording reference in project.")
                    }
                    for path in [item.segmentCSVRelativePath, item.segmentMetadataRelativePath].compactMap({ $0 }) {
                        guard !path.hasPrefix("/"), !path.contains("\\"), !path.split(separator: "/").contains("..") else {
                            throw ReceiverProjectPackageError.processFailed("Unsafe segment reference in project.")
                        }
                    }
                }
                folders[index].items = folders[index].items.map {
                    remappedFolderItem($0, destinationRootURL: workspaceRootURL.appendingPathComponent(recordingsDirectoryName), packageNameMap: [:])
                }
            }
            try writeJSON(folders, to: savedFoldersURL)
        }
        try Task.checkCancellation()
        committed = true
        return ReceiverWorkspace(
            id: workspaceRootURL.path,
            name: projectName,
            rootURL: workspaceRootURL,
            recordingsRootURL: workspaceRootURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true),
            foldersRootURL: workspaceFoldersURL,
            kind: .importedProject,
            manifest: manifest
        )
    }

    static func importProject(
        packageURL: URL,
        destinationRootURL: URL,
        existingFolders: [SnapFolder]
    ) throws -> (report: ReceiverProjectPackageReport, folders: [SnapFolder]) {
        let fileManager = FileManager.default
        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("watchmotion-import-\(UUID().uuidString)", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: extractionURL)
        }

        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try extractSafely(packageURL, to: extractionURL)

        let manifestURL = extractionURL.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ReceiverProjectPackageError.missingManifest
        }

        let manifest = try readJSON(ReceiverProjectManifest.self, from: manifestURL)
        guard (1...ReceiverProjectManifest.currentFormatVersion).contains(manifest.formatVersion) else {
            throw ReceiverProjectPackageError.unsupportedVersion(manifest.formatVersion)
        }

        let recordingsURL = extractionURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: recordingsURL.path) else {
            throw ReceiverProjectPackageError.missingRecordingsDirectory
        }

        // Do not silently reinterpret annotations when merging projects with conflicting label IDs.
        var mergedLabels = try ProjectLabelCatalog.load(root: destinationRootURL)
        let incomingLabels = try ProjectLabelCatalog.load(root: recordingsURL)
        for item in incomingLabels.labels {
            if let current = mergedLabels.labels.first(where: { $0.id == item.id }) {
                guard current.label.displayName == item.label.displayName,
                      current.label.colorHex == item.label.colorHex else {
                    throw ProjectLabelCatalog.CatalogError.invalid("Label definitions conflict. Open this project in a separate workspace instead.")
                }
            } else {
                var imported = item
                imported.shortcut = nil
                mergedLabels.labels.append(imported)
            }
        }
        try mergedLabels.validate()

        try fileManager.createDirectory(at: destinationRootURL, withIntermediateDirectories: true)

        var packageNameMap: [String: String] = [:]
        var importedRecordingCount = 0
        for sourceURL in try receivedRecordingDirectories(in: recordingsURL) {
            let destinationName = uniqueDirectoryName(
                baseName: sourceURL.lastPathComponent,
                in: destinationRootURL
            )
            let destinationURL = destinationRootURL.appendingPathComponent(destinationName, isDirectory: true)
            guard isChild(destinationURL, of: destinationRootURL) else {
                throw ReceiverProjectPackageError.unsafeDestination(destinationURL)
            }

            try copyDirectory(from: sourceURL, to: destinationURL)
            packageNameMap[sourceURL.lastPathComponent] = destinationName
            importedRecordingCount += 1
        }

        let importedFolders = try loadImportedFolders(
            extractionURL: extractionURL,
            destinationRootURL: destinationRootURL,
            packageNameMap: packageNameMap,
            existingFolders: existingFolders
        )
        let mergedFolders = existingFolders + importedFolders
        try mergedLabels.save(root: destinationRootURL)

        return (
            ReceiverProjectPackageReport(
                recordingCount: importedRecordingCount,
                folderCount: importedFolders.count,
                outputURL: nil,
                message: "Project package imported"
            ),
            mergedFolders
        )
    }

    private static func loadImportedFolders(
        extractionURL: URL,
        destinationRootURL: URL,
        packageNameMap: [String: String],
        existingFolders: [SnapFolder]
    ) throws -> [SnapFolder] {
        let importedFoldersURL = extractionURL
            .appendingPathComponent(foldersDirectoryName, isDirectory: true)
            .appendingPathComponent(foldersFileName)
        guard FileManager.default.fileExists(atPath: importedFoldersURL.path) else { return [] }

        let decodedFolders = try readJSON([SnapFolder].self, from: importedFoldersURL)
        var usedNames = Set(existingFolders.map(\.name))
        return decodedFolders.map { folder in
            let importedName = uniqueFolderName(baseName: folder.name, usedNames: &usedNames)
            let remappedItems = folder.items.map { item in
                remappedFolderItem(
                    item,
                    destinationRootURL: destinationRootURL,
                    packageNameMap: packageNameMap
                )
            }
            return SnapFolder(
                name: importedName,
                createdAt: folder.createdAt,
                updatedAt: Date(),
                items: remappedItems
            )
        }
    }

    private static func remappedFolderItem(
        _ item: SnapFolderItem,
        destinationRootURL: URL,
        packageNameMap: [String: String]
    ) -> SnapFolderItem {
        let packageFolderName = packageNameMap[item.packageFolderName] ?? item.packageFolderName
        let packageFolderURL = destinationRootURL.appendingPathComponent(packageFolderName, isDirectory: true)
        return SnapFolderItem(
            itemID: item.itemID,
            snapID: item.snapID,
            recordingID: item.recordingID,
            packageFolderName: packageFolderName,
            packageFolderURLString: packageFolderURL.path,
            packageDisplayName: item.packageDisplayName,
            recordingStartedAt: item.recordingStartedAt,
            sourceType: item.sourceType,
            label: item.label,
            notes: item.notes,
            startTime: item.startTime,
            peakTime: item.peakTime,
            endTime: item.endTime,
            segmentCSVRelativePath: item.segmentCSVRelativePath,
            segmentMetadataRelativePath: item.segmentMetadataRelativePath,
            addedAt: item.addedAt
        )
    }

    private static func receivedRecordingDirectories(in rootURL: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        return try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            guard !shouldExclude(url),
                  (try? url.resourceValues(forKeys: keys).isDirectory) == true else {
                return false
            }
            return true
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func copyDirectory(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        guard try sourceURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw ReceiverProjectPackageError.unsafeDestination(sourceURL)
        }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        let children = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        for child in children where !shouldExclude(child) {
            try Task.checkCancellation()
            guard try child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                throw ReceiverProjectPackageError.unsafeDestination(child)
            }
            let destinationChild = destinationURL.appendingPathComponent(child.lastPathComponent)
            if (try? child.resourceValues(forKeys: keys).isDirectory) == true {
                try copyDirectory(from: child, to: destinationChild)
            } else {
                try fileManager.copyItem(at: child, to: destinationChild)
            }
        }
    }

    private static func shouldExclude(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || name == "__MACOSX" { return true }
        if name == "DerivedData" || name == "Caches" { return true }
        if ["watchmotion", "jeonstarlab", "zip"].contains(url.pathExtension.lowercased()) { return true }
        return false
    }

    private static func normalizedProjectPackageURL(_ url: URL) -> URL {
        ["watchmotion", "zip"].contains(url.pathExtension.lowercased())
            ? url
            : url.deletingPathExtension().appendingPathExtension(ProjectExportPreferences.format.rawValue)
    }

    private static func uniqueDirectoryName(baseName: String, in rootURL: URL) -> String {
        let fileManager = FileManager.default
        var candidate = baseName
        var index = 1
        while fileManager.fileExists(atPath: rootURL.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(baseName) imported \(index)"
            index += 1
        }
        return candidate
    }

    private static func uniqueFolderName(baseName: String, usedNames: inout Set<String>) -> String {
        var candidate = baseName
        var index = 1
        while usedNames.contains(candidate) {
            candidate = "\(baseName) Imported \(index)"
            index += 1
        }
        usedNames.insert(candidate)
        return candidate
    }

    private static func safeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = name.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let cleaned = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "WatchMotion Editor Project" : cleaned
    }

    private static func isChild(_ url: URL, of parentURL: URL) -> Bool {
        let parentPath = parentURL.standardizedFileURL.path
        let childPath = url.standardizedFileURL.path
        return childPath.hasPrefix(parentPath + "/")
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 16 * 1024 * 1024 else {
            throw ReceiverProjectPackageError.processFailed("Project metadata exceeds the safety limit.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private static func extractSafely(_ source: URL, to destination: URL) throws {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 512 * 1024 * 1024 else {
            throw ReceiverProjectPackageError.processFailed("Project archive exceeds the 512 MB limit.")
        }
        let archive = try Archive(url: source, accessMode: .read)
        var paths = Set<String>()
        var entries: [(Entry, URL)] = []
        var declaredSize: UInt64 = 0
        for entry in archive {
            try Task.checkCancellation()
            let parts = entry.path.split(separator: "/").filter { $0 != "." }
            guard !entry.path.hasPrefix("/"), !entry.path.contains("\\"),
                !entry.path.contains("\0"), !parts.contains(".."), entry.type != .symlink,
                entry.uncompressedSize <= 2_000_000_000, entries.count < 20_000 else {
                throw ReceiverProjectPackageError.processFailed("Unsafe entry in project archive.")
            }
            if parts.isEmpty, entry.type == .directory { continue } // Legacy ditto root entry.
            let relative = parts.joined(separator: "/")
            guard !relative.isEmpty,
                paths.insert(relative.precomposedStringWithCanonicalMapping.lowercased()).inserted else {
                throw ReceiverProjectPackageError.processFailed("Duplicate or empty archive path.")
            }
            declaredSize += entry.uncompressedSize
            guard declaredSize <= 2_000_000_000 else {
                throw ReceiverProjectPackageError.processFailed("Project expands beyond the 2 GB safety limit.")
            }
            let target = destination.appendingPathComponent(relative)
            guard isChild(target, of: destination) else { throw ReceiverProjectPackageError.unsafeDestination(target) }
            entries.append((entry, target))
        }
        guard !entries.isEmpty else { throw ReceiverProjectPackageError.missingManifest }
        var totalWritten: UInt64 = 0
        for (entry, target) in entries {
            try Task.checkCancellation()
            if entry.type == .directory {
                guard entry.uncompressedSize == 0 else { throw CocoaError(.fileReadCorruptFile) }
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard FileManager.default.createFile(atPath: target.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let handle = try FileHandle(forWritingTo: target)
            defer { try? handle.close() }
            var written: UInt64 = 0
            let checksum = try archive.extract(entry, bufferSize: 64 * 1024) { chunk in
                try Task.checkCancellation()
                written += UInt64(chunk.count)
                totalWritten += UInt64(chunk.count)
                guard written <= entry.uncompressedSize, totalWritten <= 2_000_000_000 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try handle.write(contentsOf: chunk)
            }
            guard checksum == entry.checksum, written == entry.uncompressedSize else {
                throw ReceiverProjectPackageError.processFailed("Project archive is damaged (checksum mismatch).")
            }
        }
    }

    private static func createArchive(from root: URL, at output: URL) throws {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let archive = try Archive(url: output, accessMode: .create)
        guard let enumerator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else {
            throw CocoaError(.fileReadUnknown)
        }
        var total: Int64 = 0
        var count = 0
        for case let file as URL in enumerator {
            try Task.checkCancellation()
            let info = try file.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            count += 1
            guard info.isSymbolicLink != true, count <= 20_000 else { throw ReceiverProjectPackageError.unsafeDestination(file) }
            let file = file.resolvingSymlinksInPath().standardizedFileURL
            guard file.pathComponents.starts(with: root.pathComponents) else {
                throw ReceiverProjectPackageError.unsafeDestination(file)
            }
            let relative = file.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
            if info.isDirectory == true {
                try archive.addEntry(with: relative, relativeTo: root)
            } else {
                guard info.isRegularFile == true else { throw ReceiverProjectPackageError.unsafeDestination(file) }
                let size = Int64(info.fileSize ?? 0)
                total += size
                guard total <= 2_000_000_000 else {
                    throw ReceiverProjectPackageError.processFailed("Split this project before exporting: the limit is 2 GB.")
                }
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                try archive.addEntry(with: relative, type: .file, uncompressedSize: size,
                    compressionMethod: .deflate, bufferSize: 64 * 1024) { position, length in
                    try Task.checkCancellation()
                    try handle.seek(toOffset: UInt64(position))
                    let data = try handle.read(upToCount: length) ?? Data()
                    guard data.count == length else { throw CocoaError(.fileReadCorruptFile) }
                    return data
                }
            }
        }
        guard (try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 512 * 1024 * 1024 else {
            throw ReceiverProjectPackageError.processFailed("Split this project before exporting: the archive limit is 512 MB.")
        }
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
