import Foundation

/// Device-local trial usage, independent of project files and purchase entitlements.
nonisolated struct EditorTrial: Codable {
    static let localWorkspaceID = "00000000-0000-0000-0000-000000000001"
    var workspaceID: String?
    var recordingIDs: Set<String> = []
    var completedExports = 0
    var canExport: Bool { completedExports == 0 }

    mutating func finishExport(succeeded: Bool) {
        if succeeded { completedExports += 1 }
    }

    func permits(workspace: String, recordings: Set<String>) -> Bool {
        (workspaceID == nil || workspaceID == workspace)
            && recordingIDs.union(recordings).count <= 3
    }

    mutating func admit(workspace: String, recordings: Set<String>) {
        workspaceID = workspace
        recordingIDs.formUnion(recordings)
    }
}
