//
//  ReceiverProjectPackageService.swift
//  JeonstarLab Mac
//

import Foundation

enum ReceiverProjectPackageError: LocalizedError {
    case missingManifest
    case unsupportedVersion(Int)
    case missingRecordingsDirectory
    case unsafeDestination(URL)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "프로젝트 매니페스트를 찾을 수 없습니다."
        case .unsupportedVersion(let version):
            return "지원하지 않는 프로젝트 패키지 버전입니다: \(version)"
        case .missingRecordingsDirectory:
            return "recordings 폴더를 찾을 수 없습니다."
        case .unsafeDestination(let url):
            return "안전하지 않은 복사 경로입니다: \(url.lastPathComponent)"
        case .processFailed(let message):
            return message
        }
    }
}

enum ReceiverProjectPackageService {
    private static let manifestFileName = "project_manifest.json"
    private static let recordingsDirectoryName = "recordings"
    private static let foldersDirectoryName = "folders"
    private static let projectDirectoryName = "project"
    private static let foldersFileName = "folders.json"

    static func defaultFileName() -> String {
        "jeonstarlab_receiver_\(fileNameFormatter.string(from: Date())).jeonstarlab"
    }

    static func exportProject(
        recordingsRootURL: URL,
        foldersRootURL: URL,
        workspaceName: String,
        folders: [SnapFolder],
        outputURL: URL
    ) throws -> ReceiverProjectPackageReport {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: recordingsRootURL, withIntermediateDirectories: true)

        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("jeonstarlab-project-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = fileManager.temporaryDirectory
            .appendingPathComponent("jeonstarlab-project-\(UUID().uuidString).zip")

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
            try copyDirectory(
                from: recordingURL,
                to: recordingsURL.appendingPathComponent(recordingURL.lastPathComponent, isDirectory: true)
            )
        }

        let globalFoldersURL = foldersRootURL.appendingPathComponent(foldersFileName)
        if fileManager.fileExists(atPath: globalFoldersURL.path) {
            try fileManager.copyItem(
                at: globalFoldersURL,
                to: foldersURL.appendingPathComponent(foldersFileName)
            )
        }

        let manifest = ReceiverProjectManifest(
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

        try runDitto(arguments: ["-c", "-k", "--sequesterRsrc", stagingURL.path, archiveURL.path])

        let finalOutputURL = normalizedProjectPackageURL(outputURL)
        if fileManager.fileExists(atPath: finalOutputURL.path) {
            try fileManager.removeItem(at: finalOutputURL)
        }
        try fileManager.moveItem(at: archiveURL, to: finalOutputURL)

        return ReceiverProjectPackageReport(
            recordingCount: recordingURLs.count,
            folderCount: folders.count,
            outputURL: finalOutputURL,
            message: "프로젝트 패키지 내보내기 완료"
        )
    }

    static func openProjectWorkspace(
        packageURL: URL,
        projectsRootURL: URL
    ) throws -> ReceiverWorkspace {
        let fileManager = FileManager.default
        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("jeonstarlab-open-\(UUID().uuidString)", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: extractionURL)
        }

        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try runDitto(arguments: ["-x", "-k", packageURL.path, extractionURL.path])

        let manifestURL = extractionURL.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ReceiverProjectPackageError.missingManifest
        }

        let manifest = try readJSON(ReceiverProjectManifest.self, from: manifestURL)
        guard manifest.formatVersion == ReceiverProjectManifest.currentFormatVersion else {
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
            .appendingPathComponent("jeonstarlab-import-\(UUID().uuidString)", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: extractionURL)
        }

        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try runDitto(arguments: ["-x", "-k", packageURL.path, extractionURL.path])

        let manifestURL = extractionURL.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ReceiverProjectPackageError.missingManifest
        }

        let manifest = try readJSON(ReceiverProjectManifest.self, from: manifestURL)
        guard manifest.formatVersion == ReceiverProjectManifest.currentFormatVersion else {
            throw ReceiverProjectPackageError.unsupportedVersion(manifest.formatVersion)
        }

        let recordingsURL = extractionURL.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: recordingsURL.path) else {
            throw ReceiverProjectPackageError.missingRecordingsDirectory
        }

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

        return (
            ReceiverProjectPackageReport(
                recordingCount: importedRecordingCount,
                folderCount: importedFolders.count,
                outputURL: nil,
                message: "프로젝트 패키지 가져오기 완료"
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
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        let children = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        for child in children where !shouldExclude(child) {
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
        if name.hasSuffix(".jeonstarlab") || name.hasSuffix(".zip") { return true }
        return false
    }

    private static func normalizedProjectPackageURL(_ url: URL) -> URL {
        url.pathExtension == "jeonstarlab"
            ? url
            : url.deletingPathExtension().appendingPathExtension("jeonstarlab")
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
            candidate = "\(baseName) 가져옴 \(index)"
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
        return cleaned.isEmpty ? "JeonstarLab Project" : cleaned
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private static func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "ditto 실행에 실패했습니다."
            throw ReceiverProjectPackageError.processFailed(message)
        }
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
