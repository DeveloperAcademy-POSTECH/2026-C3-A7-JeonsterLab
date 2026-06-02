//
//  ReceiverWorkspaceManager.swift
//  JeonstarLab Mac
//

import Foundation

final class ReceiverWorkspaceManager {
    private let fileManager: FileManager
    private let defaultRecordingsURL: URL

    private(set) var currentWorkspace: ReceiverWorkspace

    init(
        defaultRecordingsURL: URL,
        initialWorkspace: ReceiverWorkspace? = nil,
        fileManager: FileManager = .default
    ) {
        self.defaultRecordingsURL = defaultRecordingsURL
        self.fileManager = fileManager
        self.currentWorkspace = initialWorkspace
            ?? Self.makeDefaultWorkspace(defaultRecordingsURL: defaultRecordingsURL)
    }

    var projectsRootURL: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents
            .appendingPathComponent("JeonstarLab", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
    }

    func switchToDefaultWorkspace() {
        currentWorkspace = Self.makeDefaultWorkspace(defaultRecordingsURL: defaultRecordingsURL)
    }

    func createProjectWorkspace(packageURL: URL) throws -> ReceiverWorkspace {
        try ReceiverProjectPackageService.openProjectWorkspace(
            packageURL: packageURL,
            projectsRootURL: projectsRootURL
        )
    }

    private static func makeDefaultWorkspace(defaultRecordingsURL: URL) -> ReceiverWorkspace {
        ReceiverWorkspace(
            id: "default-local",
            name: "기본 작업공간",
            rootURL: defaultRecordingsURL,
            recordingsRootURL: defaultRecordingsURL,
            foldersRootURL: defaultRecordingsURL,
            kind: .defaultLocal,
            manifest: nil
        )
    }
}
