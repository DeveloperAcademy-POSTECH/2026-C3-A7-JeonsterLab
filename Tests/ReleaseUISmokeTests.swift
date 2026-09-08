import Foundation

/// Standalone regression checks for the data contracts consumed by the redesigned UI.
@main
struct ReleaseUISmokeTests {
    static func main() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchMotionSmoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let csv = temporary.appendingPathComponent("recording.csv")
        try """
        index,timestamp,relativeTime,attitudeRoll,attitudePitch,attitudeYaw,rotationRateX,rotationRateY,rotationRateZ,gravityX,gravityY,gravityZ,userAccX,userAccY,userAccZ
        0,100,0,0,0,0,1,2,3,0,0,1,1,0,0
        1,101,1,1,2,3,2,3,6,0,0,1,3,4,0
        2,102,2,2,4,6,1,2,3,0,0,1,0,0,1
        """.write(to: csv, atomically: true, encoding: .utf8)
        let samples = try MotionCSVParser.parse(url: csv)
        precondition(samples.count == 3, "All CSV samples must survive parsing")
        precondition(samples[1].userAccX == 3 && samples[1].userAccY == 4 && samples[1].rotationRateZ == 6)
        precondition(samples[2].attitudeRoll == 2 && samples[2].attitudePitch == 4 && samples[2].attitudeYaw == 6)

        let draft = SnapSelectionAnalyzer.analyze(
            selection: ChartTimeSelection(startTime: 2, endTime: 0), samples: samples
        )!
        precondition(draft.canSave && draft.sampleCount == 3)
        precondition(draft.selection.startTime == 0 && draft.selection.endTime == 2)
        precondition(draft.peakAcceleration == 5 && draft.peakGyro == 7)
        precondition(draft.peakTime == 1 && draft.dominantAxis == "Z")
        precondition(SnapSelectionAnalyzer.analyze(
            selection: ChartTimeSelection(startTime: 3, endTime: 4), samples: samples
        ) == nil, "An empty range must not be savable")

        precondition(DatasetRequiredColumn.allCases.map(\.header) == ["snapID", "sampleIndex", "label"])
        precondition(DatasetExportOptions.default.motionColumns.count == 14)
        precondition(DatasetExportOptions.default.userInfoColumns.count == 7)
        let suite = "WatchMotionSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let selected = DatasetExportOptions(userInfoColumns: [.userNickname], motionColumns: [.relativeTime, .userAccX])
        selected.saveAsLastUsed(defaults: defaults)
        precondition(DatasetExportOptions.lastSaved(defaults: defaults) == selected)
        precondition(defaults.data(forKey: "JeonstarLab.lastDatasetExportOptions") != nil,
                     "Existing export preferences must retain their storage key")
        precondition(SnapDetectionMode.jeonFlip.rawValue == "jeonFlip")
        precondition(SnapDetectionMode.jeonFlip.displayName == "Jeon Flipping")
        print("PASS: CSV axes, selection metrics, empty ranges, export columns, preference round-trip, and detection IDs")
    }
}
