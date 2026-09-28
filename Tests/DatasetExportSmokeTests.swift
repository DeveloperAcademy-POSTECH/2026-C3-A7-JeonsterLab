// Created by 이돈혁
import Foundation

@main
struct DatasetExportSmokeTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dataset-regression-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        let recording = root.appendingPathComponent("recording")
        try fm.createDirectory(at: recording, withIntermediateDirectories: true)
        let csv = "index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ\n0,0,0,0,0,0,0,0,0,0,0,0,1,2,3\n"
        try csv.write(to: recording.appendingPathComponent("recording.csv"), atomically: true, encoding: .utf8)
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
        let first = try CreateMLActivityExporter.export(folder: folder, packages: [package], destinationDirectoryURL: destination)
        folder.items.removeLast()
        let second = try CreateMLActivityExporter.export(folder: folder, packages: [package], destinationDirectoryURL: destination)
        let firstFiles = try fm.contentsOfDirectory(atPath: first.outputDirectoryURL.appendingPathComponent("Activity").path)
        let secondFiles = try fm.contentsOfDirectory(atPath: second.outputDirectoryURL.appendingPathComponent("Activity").path)
        precondition(first.outputDirectoryURL != second.outputDirectoryURL)
        precondition(firstFiles.count == 2 && secondFiles.count == 1 && second.exportedFileCount == 1)
        package.labelReadError = "Corrupt label"
        do {
            _ = try CreateMLActivityExporter.export(folder: folder, packages: [package], destinationDirectoryURL: destination)
            fatalError("Unreadable labels were exported")
        } catch is CreateMLActivityExportError {}
        let remaining = try fm.contentsOfDirectory(atPath: destination.path)
        precondition(remaining.count == 2, "Failed exports must clean their staging directory")
        print("PASS: repeated exports are isolated, old results preserved, corrupt labels blocked, staging cleaned")
    }
}
