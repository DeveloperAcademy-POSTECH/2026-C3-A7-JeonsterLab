import Foundation
import os

struct RetainedWatchRecordingFile: Identifiable, Equatable {
    var id: String { fileName }
    let sessionID: UUID?
    let fileName: String
    let fileURL: URL
    let byteCount: Int
    let sampleCount: Int
    let modifiedAt: Date?
    var startedAt: Date? = nil
    var duration: TimeInterval? = nil
}

/// One-second journal checkpoints bound memory growth and survive app termination.
/// Only the final partial second may be lost on an abrupt termination.
@Observable
final class WatchRecordingStorage: RecordingStorageProtocol {
    private(set) var bufferCount = 0
    private(set) var retainedFiles: [RetainedWatchRecordingFile] = []
    private(set) var lastError: String?
    var onRecordingError: ((String) -> Void)?
    private let lock = NSLock()
    private let root: URL
    @ObservationIgnored nonisolated(unsafe) private var pending: [MotionSample] = []
    @ObservationIgnored nonisolated(unsafe) private var handle: FileHandle?
    @ObservationIgnored nonisolated(unsafe) private var activeURL: URL?
    @ObservationIgnored nonisolated(unsafe) private var count = 0
    @ObservationIgnored nonisolated(unsafe) private var diskCount = 0
    @ObservationIgnored nonisolated(unsafe) private var failed = false
    @ObservationIgnored nonisolated(unsafe) private var generation = 0

    init(directory: URL? = nil) {
        root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        if directory == nil { migrateLegacyFiles() }
        refreshRetainedFiles()
    }

    func begin(sessionID: UUID, startedAt: Date) throws {
        lock.lock()
        defer { lock.unlock() }
        // Retry a failed final write before accepting another recording.
        try checkpoint()
        try handle?.synchronize()
        try handle?.close()
        handle = nil
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("WMTF-\(sessionID.uuidString).bin")
        var header = Data()
        var magic = MotionSampleSerializer.magic
        var version = MotionSampleSerializer.version
        withUnsafeBytes(of: &magic) { header.append(contentsOf: $0) }
        withUnsafeBytes(of: &version) { header.append(contentsOf: $0) }
        try JSONSerialization.data(withJSONObject: ["startedAt": startedAt.timeIntervalSince1970])
            .write(to: url.appendingPathExtension("json"), options: .atomic)
        try header.write(to: url, options: .atomic)
        handle = try FileHandle(forUpdating: url)
        try handle?.seekToEnd()
        activeURL = url
        pending = []
        count = 0
        diskCount = 0
        failed = false
        generation += 1
        bufferCount = 0
        lastError = nil
    }

    nonisolated func append(_ sample: MotionSample) {
        lock.lock()
        guard handle != nil, !failed else { lock.unlock(); return }
        pending.append(sample)
        count += 1
        let currentGeneration = generation
        var failure: String?
        let update = pending.count >= 50
        if update {
            do { try checkpoint() }
            catch { failed = true; failure = error.localizedDescription }
        }
        let visibleCount = count
        lock.unlock()
        let failureMessage = failure
        if update {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isCurrent = self.isCurrent(currentGeneration)
                guard isCurrent else { return }
                self.bufferCount = visibleCount
                if let failureMessage {
                    self.lastError = failureMessage
                    self.onRecordingError?("Storage unavailable. Saved samples are retained. \(failureMessage)")
                }
            }
        }
    }

    nonisolated private func isCurrent(_ value: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == value
    }

    // Called only while holding lock. Roll back partial writes before a retry.
    nonisolated private func checkpoint() throws {
        guard !pending.isEmpty, let handle else { return }
        let offset = UInt64(MotionSampleSerializer.headerSize + diskCount * MemoryLayout<MotionSample>.stride)
        do {
            try handle.seek(toOffset: offset)
            let bytes = pending.withUnsafeBytes { Data($0) }
            try handle.write(contentsOf: bytes)
            try handle.synchronize()
            diskCount += pending.count
            pending.removeAll(keepingCapacity: true)
        } catch {
            try? handle.truncate(atOffset: offset)
            throw error
        }
    }

    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int) {
        lock.lock()
        do {
            guard let url = activeURL else { throw CocoaError(.fileNoSuchFile) }
            try checkpoint()
            try handle?.synchronize()
            try handle?.close()
            handle = nil
            let savedCount = diskCount
            activeURL = nil
            generation += 1
            lock.unlock()
            bufferCount = 0
            refreshRetainedFiles()
            return (url, savedCount)
        } catch {
            lock.unlock()
            lastError = error.localizedDescription
            refreshRetainedFiles()
            throw error
        }
    }

    func discard() {
        // Existing durable samples are never deleted when starting a new session.
        lock.lock()
        defer { lock.unlock() }
        if handle == nil { pending.removeAll(); count = 0; bufferCount = 0 }
    }

    func refreshRetainedFiles() {
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            retainedFiles = urls.compactMap { url in
                guard url != activeURL, let id = Self.sessionID(from: url.lastPathComponent) else { return nil }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let size = values?.fileSize ?? 0
                guard size >= MotionSampleSerializer.headerSize else { return nil }
                let samples = (size - MotionSampleSerializer.headerSize) / MemoryLayout<MotionSample>.stride
                let completeSize = MotionSampleSerializer.headerSize + samples * MemoryLayout<MotionSample>.stride
                // Recover only complete records if termination interrupted a write.
                if completeSize != size, let repair = try? FileHandle(forWritingTo: url) {
                    try? repair.truncate(atOffset: UInt64(completeSize))
                    try? repair.close()
                }
                let info = (try? Data(contentsOf: url.appendingPathExtension("json")))
                    .flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Double] }
                return RetainedWatchRecordingFile(sessionID: id, fileName: url.lastPathComponent,
                    fileURL: url, byteCount: completeSize, sampleCount: samples,
                    modifiedAt: values?.contentModificationDate,
                    startedAt: info?["startedAt"].map(Date.init(timeIntervalSince1970:)),
                    duration: Double(samples) / 50)
            }.sorted { ($0.startedAt ?? $0.modifiedAt ?? .distantPast) > ($1.startedAt ?? $1.modifiedAt ?? .distantPast) }
        } catch { lastError = error.localizedDescription }
    }

    func deleteRetainedFile(_ file: RetainedWatchRecordingFile) {
        guard file.fileURL.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL,
            file.fileURL != activeURL else { return }
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            try? FileManager.default.removeItem(at: file.fileURL.appendingPathExtension("json"))
        } catch { lastError = error.localizedDescription }
        refreshRetainedFiles()
    }

    func deleteRetainedFile(sessionID: UUID, fileName: String?) {
        refreshRetainedFiles()
        guard let file = retainedFiles.first(where: { $0.sessionID == sessionID &&
            (fileName == nil || fileName == $0.fileName) }) else { return }
        deleteRetainedFile(file)
    }

    private func migrateLegacyFiles() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let temporary = FileManager.default.temporaryDirectory
            for file in try FileManager.default.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)
                where Self.sessionID(from: file.lastPathComponent) != nil {
                let destination = root.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.moveItem(at: file, to: destination)
                }
            }
        } catch { lastError = error.localizedDescription }
    }

    private static func sessionID(from name: String) -> UUID? {
        guard name.hasPrefix("WMTF-"), name.hasSuffix(".bin") else { return nil }
        return UUID(uuidString: String(name.dropFirst(5).dropLast(4)))
    }
}
