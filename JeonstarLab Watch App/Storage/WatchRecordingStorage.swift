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
    private var buffer: [MotionSample] = []

    func append(_ sample: MotionSample) {
        buffer.append(sample)
        bufferCount = buffer.count
    }

    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int) {
        let started = Date()
        let count = buffer.count
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
        buffer.withUnsafeBytes { ptr in
            data.append(contentsOf: ptr)
        }

        try data.write(to: url, options: .atomic)
        let elapsed = Date().timeIntervalSince(started)
        storageLogger.info("flush completed. samples=\(count), bytes=\(data.count), elapsed=\(elapsed, format: .fixed(precision: 3))s")

        buffer.removeAll(keepingCapacity: false)
        bufferCount = 0

        return (url, count)
    }

    func discard() {
        buffer.removeAll(keepingCapacity: false)
        bufferCount = 0
    }
}
