import Foundation

@main struct PhoneInboxSmokeTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("phone-inbox-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("system-temp.bin")
        let inbox = root.appendingPathComponent("inbox")
        let original = Data([1, 2, 3, 4])
        try original.write(to: source)
        let staged = try PendingRecordingInbox.stage(source, metadata: ["sessionID": UUID().uuidString], directory: inbox)
        try FileManager.default.removeItem(at: source)
        let stagedData = try Data(contentsOf: staged)
        precondition(stagedData == original, "Staged file must survive the callback's temporary file")
        precondition(PendingRecordingInbox.pending(directory: inbox).count == 1)
        let store = RecordingFileStore(directory: root.appendingPathComponent("permanent"))
        try store.moveToDocuments(from: staged, fileName: "recording.bin")
        try store.moveToDocuments(from: staged, fileName: "recording.bin")
        let different = root.appendingPathComponent("different.bin")
        try Data([9]).write(to: different)
        do {
            try store.moveToDocuments(from: different, fileName: "recording.bin")
            fatalError("Conflicting duplicate overwrote original")
        } catch {}
        let kept = try Data(contentsOf: store.urlForFile(named: "recording.bin"))
        precondition(kept == original)
        try PendingRecordingInbox.complete(staged, directory: inbox)
        precondition(PendingRecordingInbox.pending(directory: inbox).isEmpty)
        print("PASS: synchronous inbox copy, restart discovery, idempotent import, conflicting duplicate protection")
    }
}
