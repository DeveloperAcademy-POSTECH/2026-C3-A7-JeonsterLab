import Foundation
import ZIPFoundation

@main
struct ProjectSettingsSmokeTests {
    static func requireThrows(_ action: () throws -> Void) {
        do { try action(); fatalError("Expected validation failure") } catch {}
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("watchmotion-settings-test-\(UUID())")
        let recordings = root.appendingPathComponent("source")
        let folder = recordings.appendingPathComponent("recording-fixture")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let header = "index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ\n"
        let rows = (0..<1000).map { index -> String in
            let time = Double(index) / 50
            let wave = sin(time * 3)
            let values = [Double(index), 100 + time, time, wave * 0.4, cos(time) * 0.3, wave * 0.2,
                          wave * 1.2, cos(time * 2), sin(time), 0, 0, 1, wave * 0.3, cos(time * 3) * 0.2, sin(time * 5) * 0.1]
            return String(index) + "," + values.dropFirst().map { String($0) }.joined(separator: ",")
        }
        let csv = header + rows.joined(separator: "\n") + "\n"
        try Data(csv.utf8).write(to: folder.appendingPathComponent("recording.csv"))
        let fixtureID = UUID().uuidString
        try JSONSerialization.data(withJSONObject: ["recordingID": fixtureID, "duration": 20, "startedAt": "2026-09-08T12:00:00Z",
            "sampleCount": 1000, "samplingRate": 50, "recordingMemo": "Synthetic UI verification data"])
            .write(to: folder.appendingPathComponent("metadata.json"))
        try JSONSerialization.data(withJSONObject: ["recordingID": fixtureID, "eventCount": 0, "snapEvents": []])
            .write(to: folder.appendingPathComponent("snap_analysis.json"))
        let decoder = JSONDecoder()
        let legacy = try decoder.decode(RecordingPackageLabel.self, from: Data("\"partialSuccess\"".utf8))
        precondition(legacy == .partialFlipped && legacy.datasetValue == "partial_flipped")
        let unknown = try decoder.decode(RecordingPackageLabel.self, from: Data("\"custom-legacy\"".utf8))
        precondition(unknown.id == "custom-legacy", "Unknown IDs must not become Unlabeled")

        var catalog = ProjectLabelCatalog.legacy
        catalog.labels[1].label.displayName = "Walk"
        catalog.labels[1].label.colorHex = "123ABC"
        catalog.labels[3].isArchived = true
        let custom = RecordingPackageLabel(name: "Turn, left", colorHex: "FF5544")
        catalog.labels.append(ProjectLabelDefinition(label: custom))
        try catalog.save(root: recordings)
        let saved = try ProjectLabelCatalog.load(root: recordings)
        precondition(saved.resolve(.success).displayName == "Walk")
        precondition(saved.resolve(.success).id == "success")
        precondition(saved.resolve(.success).datasetValue == "Walk")
        precondition(saved.activeLabels.allSatisfy { $0.id != "flipped" })
        precondition(saved.resolve(.flipped).displayName == "Flip Success", "Archived annotations still resolve")
        var invalid = catalog
        invalid.labels[2].shortcut = 1
        requireThrows { try invalid.validate() }
        invalid = catalog
        invalid.labels[2].label.displayName = "walk"
        requireThrows { try invalid.validate() }
        invalid = catalog
        invalid.labels[0].isArchived = true
        requireThrows { try invalid.validate() }
        invalid = catalog
        invalid.labels[2].label.colorHex = "not-a-color"
        requireThrows { try invalid.validate() }

        let loader = ReceivedRecordingPackageLoader()
        var package = loader.loadPackage(folderURL: folder)!
        package.label = custom
        package.snapEventLabels["fixture"] = SnapEventLabelPayload(label: .success, notes: "Original notes 한글", updatedAt: nil)
        try loader.saveLabel(package: package)
        let loaded = loader.loadPackage(folderURL: folder)!
        precondition(loaded.label.id == custom.id && loaded.label.displayName == "Turn, left")
        precondition(loaded.snapEventLabels["fixture"]?.label.displayName == "Walk")
        precondition(loaded.snapEventLabels["fixture"]?.notes == "Original notes 한글")
        let originalCSV = try Data(contentsOf: folder.appendingPathComponent("recording.csv"))

        for suffix in ["watchmotion", "zip"] {
            let output = root.appendingPathComponent("WatchMotion_Project.\(suffix)")
            let report = try ReceiverProjectPackageService.exportProject(
                recordingsRootURL: recordings, foldersRootURL: recordings,
                workspaceName: "Fixture", folders: [], outputURL: output)
            precondition(report.outputURL?.pathExtension == suffix)
            let opened = try ReceiverProjectPackageService.openProjectWorkspace(
                packageURL: output, projectsRootURL: root.appendingPathComponent("opened-\(suffix)"))
            let restored = try ProjectLabelCatalog.load(root: opened.recordingsRootURL)
            precondition(restored.resolve(custom).displayName == "Turn, left")
            precondition(restored.resolve(.success).colorHex == "123ABC")
            precondition(restored.labels[3].isArchived)
            let restoredCSV = try Data(contentsOf: opened.recordingsRootURL.appendingPathComponent("recording-fixture/recording.csv"))
            precondition(restoredCSV == originalCSV)
            // Emulate a version-1 package with its legacy extension.
            if suffix == "watchmotion" {
                let manifestURL = opened.rootURL.appendingPathComponent("project_manifest.json")
                var manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
                manifest["formatVersion"] = 1
                try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL)
                let legacyURL = root.appendingPathComponent("legacy.jeonstarlab")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", opened.rootURL.path, legacyURL.path]
                try process.run(); process.waitUntilExit()
                precondition(process.terminationStatus == 0)
                let legacyWorkspace = try ReceiverProjectPackageService.openProjectWorkspace(
                    packageURL: legacyURL, projectsRootURL: root.appendingPathComponent("legacy-opened"))
                precondition(legacyWorkspace.manifest?.formatVersion == 1)
            }
        }
        let otherRoot = root.appendingPathComponent("another-project")
        let anotherCatalog = try ProjectLabelCatalog.load(root: otherRoot)
        precondition(anotherCatalog.resolve(.success).displayName == "Successful Motion")
        let suite = "WatchMotionSettingsSmoke.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(ProjectExportPreferences.fileName(defaults: defaults).hasSuffix(".watchmotion"))
        defaults.set("../My/Project", forKey: ProjectExportPreferences.nameKey)
        defaults.set(false, forKey: ProjectExportPreferences.timestampKey)
        defaults.set("zip", forKey: ProjectExportPreferences.formatKey)
        precondition(ProjectExportPreferences.fileName(defaults: defaults) == "_My_Project.zip")
        // Reject hostile paths, symlinks, duplicate names and damaged payloads before committing a workspace.
        for (index, path) in ["../escaped.txt", "/absolute.txt", "nested/../../escaped.txt", "nested\\escape", "link"].enumerated() {
            let malicious = root.appendingPathComponent("unsafe-\(index).zip")
            let archive = try Archive(url: malicious, accessMode: .create)
            let bytes = Data("payload".utf8)
            try archive.addEntry(with: path, type: path == "link" ? .symlink : .file,
                uncompressedSize: Int64(bytes.count)) { offset, length in
                bytes.subdata(in: Int(offset)..<(Int(offset) + length))
            }
            requireThrows { _ = try ReceiverProjectPackageService.openProjectWorkspace(packageURL: malicious,
                projectsRootURL: root.appendingPathComponent("unsafe-opened")) }
        }
        let corrupted = root.appendingPathComponent("corrupt.zip")
        do {
            let archive = try Archive(url: corrupted, accessMode: .create)
            let bytes = Data("unique-corruption-fixture".utf8)
            try archive.addEntry(with: "recordings/data.txt", type: .file,
                uncompressedSize: Int64(bytes.count)) { offset, length in
                bytes.subdata(in: Int(offset)..<(Int(offset) + length))
            }
        }
        var damagedBytes = try Data(contentsOf: corrupted)
        let payloadRange = damagedBytes.range(of: Data("unique-corruption-fixture".utf8))!
        damagedBytes[payloadRange.lowerBound] ^= 1
        try damagedBytes.write(to: corrupted)
        do {
            _ = try ReceiverProjectPackageService.openProjectWorkspace(packageURL: corrupted,
                projectsRootURL: root.appendingPathComponent("corrupt-opened"))
            fatalError("Damaged checksum accepted")
        } catch { precondition(error.localizedDescription.contains("checksum")) }
        precondition(!fm.fileExists(atPath: root.appendingPathComponent("escaped.txt").path))
        precondition(!fm.fileExists(atPath: root.appendingPathComponent("unsafe-opened").path))
        let protectedArchive = root.appendingPathComponent("protected.watchmotion")
        let originalArchive = Data("existing export must survive a failed replacement".utf8)
        try originalArchive.write(to: protectedArchive)
        let link = folder.appendingPathComponent("unsafe-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: folder.appendingPathComponent("recording.csv"))
        requireThrows {
            _ = try ReceiverProjectPackageService.exportProject(recordingsRootURL: recordings,
                foldersRootURL: recordings, workspaceName: "Unsafe", folders: [], outputURL: protectedArchive)
        }
        let preservedArchive = try Data(contentsOf: protectedArchive)
        precondition(preservedArchive == originalArchive)

        print("PASS: label identity, legacy decoding, validation, project isolation, archive round trips, original CSV, export naming")
        print("Isolated UI workspace: \(recordings.path)")
    }
}
