import Foundation

@main struct TransferStorageSmokeTests {
    static func requireThrows(_ action: () throws -> Void) {
        do { try action(); fatalError("Invalid transfer accepted") } catch {}
    }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("transfer-storage-test-\(UUID())")
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let store = MacReceivedFileStore(directory: root.appendingPathComponent("received"))
        let recordingID = UUID().uuidString
        let metadata = try JSONSerialization.data(withJSONObject: ["recordingID": recordingID, "sampleCount": 1])
        try metadata.write(to: source.appendingPathComponent("metadata.json"))
        try metadata.write(to: source.appendingPathComponent("snap_analysis.json"))
        try Data("timestamp,userAccX\n1,0".utf8).write(to: source.appendingPathComponent("recording.csv"))
        var destinations: [URL] = []
        for _ in 0..<2 {
            let id = UUID()
            for name in ["metadata.json", "snap_analysis.json", "recording.csv"] {
                let receipt = try store.saveReceivedFile(temporaryURL: source.appendingPathComponent(name), resourceName: id.uuidString + "__" + name)
                if name != "recording.csv" { precondition(receipt.completedFiles == nil) }
                else {
                    precondition(receipt.completedFiles?.count == 3)
                    destinations.append(receipt.completedFiles![0].deletingLastPathComponent())
                }
            }
        }
        precondition(destinations[0] != destinations[1], "Rapid receipts must not overwrite each other")
        do {
            _ = try store.saveReceivedFile(temporaryURL: source.appendingPathComponent("metadata.json"), resourceName: UUID().uuidString + "__../../outside.json")
            fatalError("Unsafe name accepted")
        } catch {}
        let empty = source.appendingPathComponent("empty")
        try Data().write(to: empty)
        let symlink = source.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: source.appendingPathComponent("metadata.json"))
        let oversized = source.appendingPathComponent("oversized")
        try Data().write(to: oversized)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 17 * 1024 * 1024)
        try handle.close()
        for file in [empty, symlink, oversized, source] {
            requireThrows { _ = try store.saveReceivedFile(temporaryURL: file,
                resourceName: UUID().uuidString + "__metadata.json") }
        }
        print("PASS: transfer isolation, out-of-order files, atomic completion, empty/oversized/symlink/directory rejection, unsafe names")
    }
}
