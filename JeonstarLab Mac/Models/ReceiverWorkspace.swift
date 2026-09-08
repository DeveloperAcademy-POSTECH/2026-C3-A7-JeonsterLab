//
//  ReceiverWorkspace.swift
//  JeonstarLab Mac
//

import Foundation

struct ReceiverWorkspace: Identifiable {
    enum Kind {
        case defaultLocal
        case importedProject
    }

    let id: String
    var name: String
    let rootURL: URL
    let recordingsRootURL: URL
    let foldersRootURL: URL
    let kind: Kind
    let manifest: ReceiverProjectManifest?

    var isDefaultLocal: Bool {
        kind == .defaultLocal
    }

    var displayName: String {
        isDefaultLocal ? "Local Workspace" : name
    }
}
