// Created by 이돈혁
import Foundation

@main
struct DatasetExportSmokeTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dataset-regression-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        let recording = root.appendingPathComponent("recording")
        try fm.createDirectory(at: recording, withIntermediateDirectories: true)
        let csv = "index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ\n0,0,0,0,0,0,0,0,0,0,0,0,1,2,3\n"
        let header = csv.components(separatedBy: "\n")[0]
        let rows = (0..<10_000).map { "\($0),\($0),\(Double($0) / 10_000),0,0,0,0,0,0,0,0,0,1,2,3" }
        try (header + "\n" + rows.joined(separator: "\n")).write(to: recording.appendingPathComponent("recording.csv"), atomically: true, encoding: .utf8)
        var package = ReceivedRecordingPackageLoader().loadPackage(folderURL: recording)!
        for id in ["a", "b"] {
            let data = try JSONSerialization.data(withJSONObject: ["snapID": id, "sourceType": "manual", "startTime": 0, "endTime": 1, "label": "success", "notes": ""])
            package.manualSnapEvents.append(try JSONDecoder().decode(WorkingSnapEvent.self, from: data))
        }
        let items = package.manualSnapEvents.map { event in
            SnapFolderItem(snapID: event.snapID, recordingID: nil, packageFolderName: "recording", packageFolderURLString: recording.path, packageDisplayName: nil, recordingStartedAt: nil, sourceType: .manual, label: .success, notes: "", startTime: 0, peakTime: nil, endTime: 1, segmentCSVRelativePath: nil, segmentMetadataRelativePath: nil)
        }
        var folder = SnapFolder(name: "Activity", items: items)
        let destination = root.appendingPathComponent("export")
        let exportPackage = package
        let exportFolder = folder
        var heartbeats = 0
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                heartbeats += 1
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
        let worker = Task.detached {
            try CreateMLActivityExporter.export(folder: exportFolder, packages: [exportPackage], destinationDirectoryURL: destination)
        }
        let first = try await worker.value
        heartbeat.cancel()
        precondition(heartbeats > 2, "Dataset processing must leave MainActor responsive")
        folder.items.removeLast()
        let second = try CreateMLActivityExporter.export(folder: folder, packages: [package], destinationDirectoryURL: destination)
        let firstFiles = try fm.contentsOfDirectory(atPath: first.outputDirectoryURL.appendingPathComponent("Activity").path)
        let secondFiles = try fm.contentsOfDirectory(atPath: second.outputDirectoryURL.appendingPathComponent("Activity").path)
        precondition(first.outputDirectoryURL != second.outputDirectoryURL)
        precondition(firstFiles.count == 2 && secondFiles.count == 1 && second.exportedFileCount == 1)
        let canceled = Task.detached {
            try CreateMLActivityExporter.export(folder: exportFolder, packages: [exportPackage], destinationDirectoryURL: destination)
        }
        try await Task.sleep(for: .milliseconds(20))
        canceled.cancel()
        do { _ = try await canceled.value; fatalError("Canceled dataset export completed") }
        catch is CancellationError {}
        package.labelReadError = "Corrupt label"
        do {
            _ = try CreateMLActivityExporter.export(folder: folder, packages: [package], destinationDirectoryURL: destination)
            fatalError("Unreadable labels were exported")
        } catch is CreateMLActivityExportError {}
        let remaining = try fm.contentsOfDirectory(atPath: destination.path)
        precondition(remaining.count == 2, "Failed exports must clean their staging directory")
        print("PASS: Mac dataset responsiveness (\(heartbeats) UI heartbeats) and cancellation cleanup")
        print("PASS: repeated exports are isolated, old results preserved, corrupt labels blocked, staging cleaned")
    }
}
