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
    static func main() {
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
