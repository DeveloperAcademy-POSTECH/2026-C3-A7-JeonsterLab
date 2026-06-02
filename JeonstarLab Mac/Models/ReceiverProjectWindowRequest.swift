//
//  ReceiverProjectWindowRequest.swift
//  JeonstarLab Mac
//

import Foundation

struct ReceiverProjectWindowRequest: Codable, Hashable {
    let workspaceRootPath: String
    let displayName: String

    init(workspace: ReceiverWorkspace) {
        self.workspaceRootPath = workspace.rootURL.path
        self.displayName = workspace.displayName
    }

    func makeWorkspace() -> ReceiverWorkspace {
        let rootURL = URL(fileURLWithPath: workspaceRootPath)
        let manifestURL = rootURL.appendingPathComponent("project_manifest.json")
        let manifest: ReceiverProjectManifest?
        if let data = try? Data(contentsOf: manifestURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            manifest = try? decoder.decode(ReceiverProjectManifest.self, from: data)
        } else {
            manifest = nil
        }

        return ReceiverWorkspace(
            id: rootURL.path,
            name: displayName,
            rootURL: rootURL,
            recordingsRootURL: rootURL.appendingPathComponent("recordings", isDirectory: true),
            foldersRootURL: rootURL.appendingPathComponent("folders", isDirectory: true),
            kind: .importedProject,
            manifest: manifest
        )
    }
}
