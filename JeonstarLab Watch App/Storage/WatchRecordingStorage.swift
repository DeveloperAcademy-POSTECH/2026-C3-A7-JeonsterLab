//
//  WatchRecordingStorage.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import os

private let storageLogger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Storage")

struct RetainedWatchRecordingFile: Identifiable, Equatable {
    var id: String { fileName }
    let sessionID: UUID?
    let fileName: String
    let fileURL: URL
    let byteCount: Int
    let sampleCount: Int
    let modifiedAt: Date?
}

@Observable
final class WatchRecordingStorage: RecordingStorageProtocol {

    private(set) var bufferCount: Int = 0
    private(set) var retainedFiles: [RetainedWatchRecordingFile] = []
    private let bufferLock = NSLock()
    nonisolated(unsafe) private var buffer: [MotionSample] = []
    nonisolated(unsafe) private var lastVisibleCountUpdate = Date.distantPast
    nonisolated(unsafe) private var countUpdateGeneration = 0
    private let visibleCountUpdateInterval: TimeInterval = 1.0

    init() {
        refreshRetainedFiles()
    }

    nonisolated func append(_ sample: MotionSample) {
        let countForDisplay: Int?
        let generation: Int
        bufferLock.lock()
        buffer.append(sample)
        generation = countUpdateGeneration

        let now = Date()
        if now.timeIntervalSince(lastVisibleCountUpdate) >= visibleCountUpdateInterval {
            lastVisibleCountUpdate = now
            countForDisplay = buffer.count
        } else {
            countForDisplay = nil
        }
        bufferLock.unlock()

        if let countForDisplay {
            Task { @MainActor [weak self] in
                guard self?.currentCountUpdateGeneration == generation else { return }
                self?.bufferCount = countForDisplay
            }
        }
    }

    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int) {
        let started = Date()
        let samples = drainBuffer()
        let count = samples.count
        let fileName = "WMTF-\(sessionID.uuidString).bin"
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)

        var data = Data(capacity: MotionSampleSerializer.headerSize + count * MemoryLayout<MotionSample>.stride)

        // 헤더: magic(4) + version(4)
        var magic   = MotionSampleSerializer.magic
        var version = MotionSampleSerializer.version
        withUnsafeBytes(of: &magic)   { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &version) { data.append(contentsOf: $0) }

        // 페이로드: raw MotionSample 배열
        samples.withUnsafeBytes { ptr in
            data.append(contentsOf: ptr)
        }

        try data.write(to: url, options: .atomic)
        refreshRetainedFiles()
        let elapsed = Date().timeIntervalSince(started)
        storageLogger.info("flush completed. samples=\(count), bytes=\(data.count), elapsed=\(elapsed, format: .fixed(precision: 3))s")

        bufferCount = 0

        return (url, count)
    }

    func discard() {
        _ = drainBuffer()
        bufferCount = 0
    }

    func refreshRetainedFiles() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        retainedFiles = urls
            .filter { $0.lastPathComponent.hasPrefix("WMTF-") && $0.pathExtension == "bin" }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return RetainedWatchRecordingFile(
                    sessionID: Self.sessionID(from: url.lastPathComponent),
                    fileName: url.lastPathComponent,
                    fileURL: url,
                    byteCount: values?.fileSize ?? 0,
                    sampleCount: Self.sampleCount(byteCount: values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate
                )
            }
            .sorted {
                ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
    }

    func deleteRetainedFile(_ file: RetainedWatchRecordingFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            storageLogger.info("retained recording deleted manually. file=\(file.fileName)")
        } catch {
            storageLogger.error("retained recording delete failed. file=\(file.fileName), error=\(error.localizedDescription)")
        }
        refreshRetainedFiles()
    }

    func deleteRetainedFile(sessionID: UUID, fileName: String?) {
        refreshRetainedFiles()
        guard let file = retainedFiles.first(where: { retainedFile in
            if let fileName, retainedFile.fileName == fileName { return true }
            return retainedFile.sessionID == sessionID
        }) else {
            storageLogger.warning("ACK matched no retained recording. sessionID=\(sessionID.uuidString), fileName=\(fileName ?? "nil")")
            return
        }
        deleteRetainedFile(file)
    }

    private var currentCountUpdateGeneration: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return countUpdateGeneration
    }

    private func drainBuffer() -> [MotionSample] {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let samples = buffer
        buffer.removeAll(keepingCapacity: false)
        lastVisibleCountUpdate = .distantPast
        countUpdateGeneration += 1
        return samples
    }

    private static func sessionID(from fileName: String) -> UUID? {
        guard fileName.hasPrefix("WMTF-"), fileName.hasSuffix(".bin") else { return nil }
        let start = fileName.index(fileName.startIndex, offsetBy: 5)
        let end = fileName.index(fileName.endIndex, offsetBy: -4)
        return UUID(uuidString: String(fileName[start..<end]))
    }

    private static func sampleCount(byteCount: Int) -> Int {
        let payloadSize = max(0, byteCount - MotionSampleSerializer.headerSize)
        return payloadSize / MemoryLayout<MotionSample>.stride
    }
}
