//
//  WatchRecordingStorage.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import os

private let storageLogger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Storage")

@Observable
final class WatchRecordingStorage: RecordingStorageProtocol {

    private(set) var bufferCount: Int = 0
    private let bufferLock = NSLock()
    nonisolated(unsafe) private var buffer: [MotionSample] = []
    nonisolated(unsafe) private var lastVisibleCountUpdate = Date.distantPast
    nonisolated(unsafe) private var countUpdateGeneration = 0
    private let visibleCountUpdateInterval: TimeInterval = 1.0

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
        let elapsed = Date().timeIntervalSince(started)
        storageLogger.info("flush completed. samples=\(count), bytes=\(data.count), elapsed=\(elapsed, format: .fixed(precision: 3))s")

        bufferCount = 0

        return (url, count)
    }

    func discard() {
        _ = drainBuffer()
        bufferCount = 0
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
}
