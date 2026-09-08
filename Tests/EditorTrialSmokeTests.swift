import Foundation

@main struct EditorTrialSmokeTests {
    static func main() throws {
        var trial = EditorTrial()
        precondition(trial.permits(workspace: "project-a", recordings: ["one", "two", "three"]))
        precondition(!trial.permits(workspace: "project-a", recordings: ["one", "two", "three", "four"]))
        trial.admit(workspace: "project-a", recordings: ["one"])
        precondition(trial.permits(workspace: "project-a", recordings: ["one"]))
        precondition(!trial.permits(workspace: "project-b", recordings: ["one"]))
        trial.admit(workspace: "project-a", recordings: ["two", "three"])
        precondition(!trial.permits(workspace: "project-a", recordings: ["four"]))
        precondition(trial.canExport)
        trial.finishExport(succeeded: false)
        precondition(trial.canExport, "Canceled/failed exports must not consume the trial")
        trial.finishExport(succeeded: true)
        precondition(!trial.canExport)
        let restored = try JSONDecoder().decode(EditorTrial.self, from: JSONEncoder().encode(trial))
        precondition(restored.workspaceID == "project-a")
        precondition(restored.recordingIDs.count == 3 && !restored.canExport)
        precondition(restored.permits(workspace: "project-a", recordings: ["one"]), "Existing trial edits remain available after export")
        precondition(!restored.permits(workspace: "project-b", recordings: []))
        print("PASS: trial admission, recording limits, repeat edits, export outcomes and persistence")
    }
}
