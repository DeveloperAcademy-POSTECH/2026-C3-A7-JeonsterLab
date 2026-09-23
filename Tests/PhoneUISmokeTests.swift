import Foundation

private enum TestFailure: Error { case requested }

private final class TestRepository: RecordingRepositoryProtocol {
    var recordings: [RecordingSession] = []
    var samples: [MotionSample] = []
    var failLoad = false
    var failMemo = false
    var savedMemo = "Original notes"
    var detectionReads = 0
    var mode: SnapDetectionMode = .jeonFlip
    func save(session: RecordingSession, from tempFileURL: URL) throws {}
    func delete(sessionID: UUID) throws {}
    func loadSamples(for sessionID: UUID) throws -> [MotionSample] {
        if failLoad { throw TestFailure.requested }
        return samples
    }
    func snapDetectionMode(for sessionID: UUID) throws -> SnapDetectionMode {
        detectionReads += 1
        return mode
    }
    func updateSnapDetectionMode(for sessionID: UUID, mode: SnapDetectionMode) throws {
        self.mode = mode
    }
    func updateMemo(for sessionID: UUID, memo: String) throws {
        if failMemo { throw TestFailure.requested }
        savedMemo = memo
    }
}

@main
struct PhoneUISmokeTests {
    static func sample(_ timestamp: Double) -> MotionSample {
        MotionSample(timestamp: timestamp,
                     attitudeRoll: 1, attitudePitch: 2, attitudeYaw: 3,
                     rotationRateX: 4, rotationRateY: 5, rotationRateZ: 6,
                     gravityX: 7, gravityY: 8, gravityZ: 9,
                     userAccX: 10, userAccY: 11, userAccZ: 12)
    }

    @MainActor
    static func main() async throws {
        let samples = [sample(100), sample(100.5), sample(102)]
        precondition(MotionPreviewTimeline.seconds(samples: samples, samplingRate: 50) == [0, 0.5, 2])
        precondition(MotionPreviewTimeline.seconds(samples: [], samplingRate: 50).isEmpty)
        for invalid in [[sample(0), sample(0)], [sample(2), sample(1)], [sample(.nan), sample(1)]] {
            precondition(MotionPreviewTimeline.seconds(samples: invalid, samplingRate: 50) == [0, 0.02])
            precondition(MotionPreviewTimeline.seconds(samples: invalid, samplingRate: 0) == [0, 1])
        }
        precondition(MotionPreviewKind.acceleration.axes.map { samples[0][keyPath: $0.value] } == [10, 11, 12])
        precondition(MotionPreviewKind.gyroscope.axes.map { samples[0][keyPath: $0.value] } == [4, 5, 6])
        precondition(MotionPreviewKind.attitude.axes.map { samples[0][keyPath: $0.value] } == [1, 2, 3])
        precondition(MotionPreviewKind.allCases.map(\.unit) == ["g", "rad/s", "rad"])

        let repository = TestRepository()
        repository.samples = samples
        let session = RecordingSession(id: UUID(), startedAt: Date(), duration: 2,
                                       sampleCount: 3, fileName: "original.bin", samplingRate: 50,
                                       memo: repository.savedMemo)
        let model = RecordingDetailViewModel(session: session, repository: repository)
        for invalidDuration in [Double.nan, .infinity, .greatestFiniteMagnitude, -1] {
            let invalidSession = RecordingSession(id: UUID(), startedAt: Date(), duration: invalidDuration,
                sampleCount: 3, fileName: "invalid.bin", samplingRate: 50)
            precondition(RecordingDetailViewModel(session: invalidSession, repository: repository).durationText == "—")
        }
        precondition(repository.detectionReads == 0, "Preview must not run activity-specific analysis")
        repository.failLoad = true
        await model.loadSamples()
        precondition(model.errorMessage != nil && !model.isLoading)
        repository.failLoad = false
        await model.loadSamples()
        precondition(model.errorMessage == nil && model.samples.count == 3)
        model.recordingMemo = "Cancelled notes"
        model.resetRecordingMemoDraft()
        precondition(model.recordingMemo == "Original notes")
        repository.failMemo = true
        model.updateRecordingMemo("Failed notes")
        precondition(model.savedRecordingMemo == "Original notes" && model.memoErrorMessage != nil)
        repository.failMemo = false
        model.recordingMemo = "확인한 메모 — unchanged user language"
        model.updateRecordingMemo(model.recordingMemo)
        precondition(model.savedRecordingMemo == repository.savedMemo && model.memoErrorMessage == nil)
        precondition(!model.hasRecordingMemoChanges)

        let urls = try model.exportRecording()
        precondition(urls.map(\.lastPathComponent) == ["recording.csv", "metadata.json", "snap_analysis.json"])
        let csv = try String(contentsOf: urls[0], encoding: .utf8)
        precondition(csv == RecordingCSVExporter.makeCSV(from: samples))
        precondition(csv.split(separator: "\n")[0].split(separator: ",").count == 15)
        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: urls[1])) as! [String: Any]
        precondition(metadata["snapDetectionMode"] as? String == "jeonFlip")
        precondition(metadata["recordingMemo"] as? String == model.savedRecordingMemo)
        precondition(repository.mode == .jeonFlip, "Removing UI must not migrate legacy mode")
        print("PASS: phone timeline, sensor axes/units, load retry, memo save/cancel/error, legacy export compatibility")
    }
}
