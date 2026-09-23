#if DEBUG && targetEnvironment(simulator)
import Foundation

/// Opt-in simulator-only fixture. Never opens or modifies the user's recording database.
enum PhoneUIPreviewData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--ui-preview") }

    @MainActor
    static func seed(_ repository: RecordingRepository) throws {
        for (index, duration) in [20, 32, 18].enumerated() {
            let id = UUID()
            let samples = (0..<(duration * 50)).map { index in
                let t = Double(index) / 50
                return MotionSample(
                    timestamp: 1000 + t,
                    attitudeRoll: sin(t * 0.6), attitudePitch: cos(t * 0.4), attitudeYaw: sin(t * 0.3),
                    rotationRateX: sin(t * 3), rotationRateY: cos(t * 2.4), rotationRateZ: sin(t * 2.1),
                    gravityX: 0, gravityY: 0, gravityZ: 1,
                    userAccX: sin(t * 8) * 0.7, userAccY: cos(t * 6) * 0.4, userAccZ: sin(t * 5) * 0.6
                )
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-preview-\(id).bin")
            var magic = MotionSampleSerializer.magic
            var version = MotionSampleSerializer.version
            var data = Data(bytes: &magic, count: 4)
            data.append(Data(bytes: &version, count: 4))
            samples.withUnsafeBytes { data.append(contentsOf: $0) }
            try data.write(to: url)
            let session = RecordingSession(
                id: id, startedAt: Date(timeIntervalSince1970: 1_788_834_060 - Double(index * 3600)),
                duration: Double(duration), sampleCount: samples.count, fileName: url.lastPathComponent,
                samplingRate: 50, memo: index == 0 ? "Right wrist. Sample recording for UI verification." : ""
            )
            try repository.save(session: session, from: url)
        }
    }
}

final class PhoneUIPreviewFileStore: RecordingFileStoreProtocol {
    private var files: [String: URL] = [:]
    func moveToDocuments(from tempURL: URL, fileName: String) throws { files[fileName] = tempURL }
    func delete(fileName: String) throws { files.removeValue(forKey: fileName) }
    func urlForFile(named fileName: String) throws -> URL {
        guard let url = files[fileName] else { throw RecordingRepositoryError.fileNotFound }
        return url
    }
}
#endif
