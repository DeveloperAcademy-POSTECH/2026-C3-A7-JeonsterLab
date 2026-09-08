import Foundation

// Test-only replacements for hardware feedback. Production uses WatchKit.
final class WatchHapticManager {
    var starts = 0
    func playRecordingStarted() { starts += 1 }
    func playRecordingStopped() {}
    func playTransferCompleted() {}
    func playError() {}
}

private final class TestRecorder: MotionRecorderProtocol {
    var isRecording = false
    var failStart = false
    func startRecording(onSample: @escaping (MotionSample) -> Void) throws {
        if failStart { throw CocoaError(.fileReadUnknown) }
        isRecording = true
    }
    func stopRecording() { isRecording = false }
}

private final class TestStorage: RecordingStorageProtocol {
    var bufferCount = 100
    var discards = 0
    var flushes = 0
    func append(_ sample: MotionSample) {}
    func discard() { discards += 1 }
    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int) {
        flushes += 1
        return (URL(fileURLWithPath: "/private/tmp/watchmotion-test-nonexistent.bin"), bufferCount)
    }
}

private final class TestTransfer: RecordingTransferProtocol {
    var sessions: [RecordingSession] = []
    func transfer(fileURL: URL, session: RecordingSession) { sessions.append(session) }
}

@main
struct WatchUISmokeTests {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("watch-journal-test-\(UUID())")
        let journal = WatchRecordingStorage(directory: root)
        let journalID = UUID()
        let start = Date(timeIntervalSince1970: 1000)
        try journal.begin(sessionID: journalID, startedAt: start)
        for index in 0..<107 {
            journal.append(MotionSample(timestamp: Double(index) / 50,
                attitudeRoll: 0, attitudePitch: 0, attitudeYaw: 0,
                rotationRateX: 0, rotationRateY: 0, rotationRateZ: 0,
                gravityX: 0, gravityY: 0, gravityZ: 1, userAccX: 0, userAccY: 0, userAccZ: 0))
        }
        let recovered = WatchRecordingStorage(directory: root)
        precondition(recovered.retainedFiles.first?.sampleCount == 100, "Checkpoint survives a new storage instance")
        precondition(recovered.retainedFiles.first?.startedAt == start)
        let saved = try journal.flush(sessionID: journalID, startedAt: start)
        precondition(saved.sampleCount == 107)
        let samples = try MotionSampleSerializer.read(from: saved.url)
        precondition(samples.count == 107 && samples.last?.timestamp == 106.0 / 50)
        try journal.begin(sessionID: UUID(), startedAt: Date())
        precondition(FileManager.default.fileExists(atPath: saved.url.path), "New session must preserve old recording")

        let recorder = TestRecorder()
        let storage = TestStorage()
        let transfer = TestTransfer()
        let haptics = WatchHapticManager()
        let model = RecordingViewModel(
            startUseCase: StartRecordingUseCase(recorder: recorder, storage: storage),
            stopUseCase: StopRecordingUseCase(recorder: recorder, storage: storage, transfer: transfer),
            transferService: transfer, hapticManager: haptics
        )
        precondition(model.canStartRecording && model.canResendRetainedFile)
        model.startRecording()
        guard case .recording(_, let sessionID) = model.state else { fatalError("Recording state missing") }
        precondition(!model.canResendRetainedFile && !model.canStartRecording)
        model.startRecording()
        precondition(storage.discards == 1 && haptics.starts == 1, "Duplicate start must preserve the buffer")
        model.transferDidComplete(error: CocoaError(.fileReadUnknown))
        guard case .recording(_, let sameID) = model.state else { fatalError("Stale callback replaced recording") }
        precondition(sameID == sessionID)
        model.stopRecording()
        model.stopRecording()
        precondition(storage.flushes == 1 && transfer.sessions.count == 1)
        guard case .transferring = model.state else { fatalError("Transfer state missing") }
        model.startRecording()
        precondition(storage.discards == 1)
        model.transferDidComplete()
        precondition(model.canStartRecording && model.canResendRetainedFile)
        let file = RetainedWatchRecordingFile(sessionID: UUID(), fileName: "sample.bin",
            fileURL: URL(fileURLWithPath: "/private/tmp/watchmotion-test-nonexistent.bin"),
            byteCount: 10408, sampleCount: 100, modifiedAt: Date())
        model.resendRetainedFile(file)
        model.resendRetainedFile(file)
        precondition(transfer.sessions.count == 2, "Repeated resend must not enqueue twice")
        precondition(transfer.sessions.last?.sampleCount == 100)
        model.transferDidComplete(error: CocoaError(.fileReadUnknown))
        guard case .error = model.state else { fatalError("Transfer error missing") }
        precondition(model.canResendRetainedFile)
        recorder.failStart = true
        model.startRecording()
        guard case .error = model.state else { fatalError("Start error missing") }
        print("PASS: Watch start/stop, duplicate commands, stale callback, resend guards, and failure states")
    }
}
