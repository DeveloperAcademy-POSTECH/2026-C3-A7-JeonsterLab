import Foundation

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
        let csv = "index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ\n0,100,0,0,0,0,0,0,0,0,0,1,0,0,0\n"
        try Data(csv.utf8).write(to: folder.appendingPathComponent("recording.csv"))
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
        print("PASS: label identity, legacy decoding, validation, project isolation, archive round trips, original CSV, export naming")
        print("Isolated UI workspace: \(recordings.path)")
    }
}
